import Foundation

/// Search records contain player DNA and shared-engine observations only.
public struct GeneticCandidate: Codable, Sendable {
    public let id: Int
    public let generation: Int
    public var metaUpgrades: MetaUpgradeProgression { strategy.metaProgression }
    public var starsUsed: Int { metaUpgrades.spentStars }
    public let strategy: GeneticStrategy
    public let evaluations: [GeneticEvaluation]
    public var fitness: GeneticFitness { GeneticFitness(evaluations) }

    public init(id: Int, generation: Int, strategy: GeneticStrategy, evaluations: [GeneticEvaluation]) {
        self.id = id; self.generation = generation
        self.strategy = strategy; self.evaluations = evaluations
    }

    private enum CodingKeys: String, CodingKey { case id, generation, starsUsed, strategy, evaluations }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try values.decode(Int.self, forKey: .id), generation: try values.decode(Int.self, forKey: .generation),
            strategy: try values.decode(GeneticStrategy.self, forKey: .strategy),
            evaluations: try values.decode([GeneticEvaluation].self, forKey: .evaluations))
        guard try values.decode(Int.self, forKey: .starsUsed) == starsUsed else {
            throw DbError.Db(message: "genetic candidate: starsUsed differs from its explicit meta upgrades")
        }
    }
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id); try values.encode(generation, forKey: .generation)
        try values.encode(starsUsed, forKey: .starsUsed)
        try values.encode(strategy, forKey: .strategy); try values.encode(evaluations, forKey: .evaluations)
    }

    public static func ranked(_ candidates: [Self]) -> [Self] {
        candidates.sorted { $0.fitness == $1.fitness ? $0.id < $1.id : $0.fitness > $1.fitness }
    }
}

/// Each active selection owns an equally-sized subpopulation. A losing plan
/// cannot evict a different selection before it has had its adaptation budget.
/// Retired selections retain their own best plans and can still reach validation.
public struct GeneticMetaPopulation {
    public struct Selection {
        public let upgrades: MetaUpgradeProgression
        public let introducedGeneration: Int
        public fileprivate(set) var active: Bool
        public fileprivate(set) var candidateIDs: Set<Int> = []
        public fileprivate(set) var archive: [GeneticCandidate] = []
        public var key: String { GeneticMetaSearch.key(upgrades) }
    }

    public let plansPerSelection: Int
    public let minimumCandidates: Int
    public private(set) var selections: [Selection]
    public var activeSelections: [Selection] { selections.filter(\.active) }
    public var visitedKeys: Set<String> { Set(selections.map(\.key)) }

    public init(selections: [MetaUpgradeProgression], population: Int, minimumCandidates: Int) throws {
        guard !selections.isEmpty, Set(selections.map(GeneticMetaSearch.key)).count == selections.count,
              Set(selections.map(\.spentStars)).count == 1,
              minimumCandidates >= 2, population / selections.count >= minimumCandidates else {
            throw DbError.Db(message: "genetic meta population: each distinct selection needs at least \(minimumCandidates) battle plans")
        }
        plansPerSelection = population / selections.count
        self.minimumCandidates = minimumCandidates
        self.selections = selections.map { Selection(upgrades: $0, introducedGeneration: 0, active: true) }
    }

    public mutating func record(_ candidate: GeneticCandidate) throws {
        let key = candidate.metaUpgrades.key
        guard let index = selections.firstIndex(where: { $0.key == key && $0.active && $0.upgrades == candidate.metaUpgrades }) else {
            throw DbError.Db(message: "genetic meta population: candidate has no active selection")
        }
        guard selections[index].candidateIDs.insert(candidate.id).inserted else { return }
        selections[index].archive = Array(GeneticCandidate.ranked(selections[index].archive + [candidate]).prefix(plansPerSelection))
    }

    public func weakestReplaceable(generation: Int, adaptationGenerations: Int) -> Selection? {
        let mature = activeSelections.filter {
            $0.candidateIDs.count >= max(minimumCandidates, plansPerSelection) &&
            generation - $0.introducedGeneration >= adaptationGenerations && !$0.archive.isEmpty
        }
        // Protect the best active selection even when every fitness is tied.
        let ranked = mature.sorted { a, b in
            let x = a.archive[0], y = b.archive[0]
            return x.fitness == y.fitness ? x.id < y.id : x.fitness > y.fitness
        }
        guard ranked.count > 1 else { return nil }
        return ranked.last
    }

    public mutating func replace(_ key: String, with selection: MetaUpgradeProgression, generation: Int, adaptationGenerations: Int) throws {
        guard let previous = weakestReplaceable(generation: generation, adaptationGenerations: adaptationGenerations),
              previous.upgrades.spentStars == selection.spentStars,
              previous.key == key, !visitedKeys.contains(GeneticMetaSearch.key(selection)),
              let index = selections.firstIndex(where: { $0.key == key }) else {
            throw DbError.Db(message: "genetic meta population: selection replacement lacks adaptation evidence or repeats a selection")
        }
        selections[index].active = false
        selections.append(Selection(upgrades: selection, introducedGeneration: generation, active: true))
    }

    /// One champion per distinct selection. Equal fitness never consumes all
    /// finalist seats with clones of one meta selection. Underexplored selections
    /// stay visible in reporting but cannot claim a qualified validation result.
    public func finalists(limit: Int, distinctSelections: Bool = true) -> [GeneticCandidate] {
        let qualified = selections.filter { $0.candidateIDs.count >= minimumCandidates }
        // Explicit fixed-meta controls compare several battle plans with one
        // selection. Ordinary meta searches always use distinct champions.
        let candidates = distinctSelections ? qualified.compactMap { $0.archive.first } : qualified.flatMap(\.archive)
        return Array(GeneticCandidate.ranked(candidates).prefix(limit))
    }

    public var best: GeneticCandidate? { GeneticCandidate.ranked(selections.compactMap { $0.archive.first }).first }
}

/// Statistical result comparison, never a gameplay score or combat rule.
/// Shared seeds pair the complete outcomes of two independently adapted plans.
public struct GeneticPairedComparison: Codable, Equatable {
    public let games: Int
    public let baselineWins: Int
    public let alternativeWins: Int
    public let baselineOnlyWins: Int
    public let alternativeOnlyWins: Int
    public let meanLivesDifference: Double

    public init(baseline: [GeneticEvaluation], alternative: [GeneticEvaluation]) throws {
        let a = Dictionary(baseline.map { ($0.seed, $0) }, uniquingKeysWith: { a, _ in a })
        let b = Dictionary(alternative.map { ($0.seed, $0) }, uniquingKeysWith: { a, _ in a })
        guard !a.isEmpty, a.count == baseline.count, b.count == alternative.count, Set(a.keys) == Set(b.keys) else {
            throw DbError.Db(message: "genetic comparison: distinct, identical seed panels are required")
        }
        games = a.count
        baselineWins = baseline.filter { $0.result.outcome == .victory }.count
        alternativeWins = alternative.filter { $0.result.outcome == .victory }.count
        baselineOnlyWins = a.keys.filter { a[$0]!.result.outcome == .victory && b[$0]!.result.outcome != .victory }.count
        alternativeOnlyWins = a.keys.filter { b[$0]!.result.outcome == .victory && a[$0]!.result.outcome != .victory }.count
        meanLivesDifference = a.keys.reduce(0.0) { $0 + Double(b[$1]!.result.livesRemaining - a[$1]!.result.livesRemaining) } / Double(games)
    }
}
