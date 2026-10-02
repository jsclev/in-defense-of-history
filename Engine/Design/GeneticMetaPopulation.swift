import Foundation

/// Search records contain player DNA and shared-engine observations only.
public struct GeneticCandidate: Codable, Sendable {
    public let id: Int
    public let generation: Int
    public var metaUpgrades: MetaUpgradeProgression { strategy.metaProgression }
    public var starsUsed: Int { metaUpgrades.spentStars }
    public let strategy: GeneticStrategy
    /// The same representative seed used for a demonstration; fitness ranking
    /// still uses every evaluation. Legacy candidates explicitly report nil.
    public var representativeEvaluation: GeneticEvaluation? {
        evaluations.sorted {
            let a = GeneticFitness([$0]), b = GeneticFitness([$1])
            return a == b ? $0.seed < $1.seed : a > b
        }.first
    }
    public var placementPlan: GeneticPlacementPlan? { representativeEvaluation?.placementPlan }
    public func requirePlacementPlan() throws -> GeneticPlacementPlan {
        guard let plan = placementPlan else {
            throw DbError.Db(message: "candidate \(id): original opening/placement data is missing; time-zero orders are not an opening layout")
        }
        return plan
    }
    public let evaluations: [GeneticEvaluation]
    private let cachedFitness: GeneticFitness?
    public var fitness: GeneticFitness {
        // Invalid/empty incoming records must reach the DAO's throwing
        // validation; constructing one must not terminate the process.
        guard let cachedFitness else { preconditionFailure("Cannot rank an empty evaluation panel") }
        return cachedFitness
    }
    /// Immutable derived cache, never serialized as a second source of evidence.
    public let behaviorDescriptor: GeneticPlaystyle.Descriptor?

    public init(id: Int, generation: Int, strategy: GeneticStrategy, evaluations: [GeneticEvaluation]) {
        self.id = id; self.generation = generation
        self.strategy = strategy; self.evaluations = evaluations
        cachedFitness = evaluations.isEmpty ? nil : GeneticFitness(evaluations)
        behaviorDescriptor = evaluations.sorted {
            let a = GeneticFitness([$0]), b = GeneticFitness([$1])
            return a == b ? $0.seed < $1.seed : a > b
        }.first?.placementPlan?.playstyle?.descriptor
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
        /// Complete training pool. The small working parent pool is never the
        /// source of validation eligibility.
        public fileprivate(set) var candidates: [GeneticCandidate] = []
        public fileprivate(set) var behaviorChampions: [String: GeneticCandidate] = [:]
        public fileprivate(set) var breedingVisits: [String: Int] = [:]
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
        selections[index].candidates.append(candidate)
        if let niche = candidate.behaviorDescriptor?.niche {
            let previous = selections[index].behaviorChampions[niche]
            if previous == nil || candidate.fitness > previous!.fitness {
                selections[index].behaviorChampions[niche] = candidate
            }
        }
        selections[index].archive = GeneticBreedingDiversity.select(selections[index].archive + [candidate], limit: plansPerSelection)
    }

    /// Allocate actual offspring, not just seats on a list. Two of every three
    /// births go to the least-bred observed niches, each using its own best plan.
    /// Visits survive improvements to a niche champion and generation changes.
    public mutating func breedingParents(key: String, count: Int) -> [GeneticCandidate] {
        guard let index = selections.firstIndex(where: { $0.key == key }), count > 0,
              let best = selections[index].archive.first else { return [] }
        guard !selections[index].behaviorChampions.isEmpty else { return selections[index].archive }
        var result: [GeneticCandidate] = []
        for birth in 0..<count {
            if birth % 3 == 0 { result.append(best); continue }
            let niche = selections[index].behaviorChampions.keys.min { a, b in
                let x = selections[index].breedingVisits[a, default: 0]
                let y = selections[index].breedingVisits[b, default: 0]
                return x == y ? a < b : x < y
            }!
            result.append(selections[index].behaviorChampions[niche]!)
            selections[index].breedingVisits[niche, default: 0] += 1
        }
        return result
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

    /// Creative profiles preserve upgrade coverage while allowing different plans
    /// with the same upgrades. Legacy profiles retain distinct selections. Underexplored selections
    /// stay visible in reporting but cannot claim a qualified validation result.
    public func finalists(limit: Int, distinctSelections: Bool = true,
                          controlledMetaExchange: Bool = false) -> [GeneticCandidate] {
        let qualified = selections.filter { $0.candidateIDs.count >= minimumCandidates }
        if controlledMetaExchange {
            // A controlled exchange must test each qualified upgrade selection,
            // including losers, rather than selecting only winning playstyles.
            return Array(GeneticCandidate.ranked(qualified.compactMap { $0.archive.first }).prefix(max(0, limit)))
        }
        // Explicit fixed-meta controls compare several battle plans with one
        // selection. Modern profiles also protect opening-role coverage.
        return GeneticBreedingDiversity.select(qualified.flatMap(\.candidates), limit: limit,
            distinctMetaSelections: distinctSelections, creativeFinalists: true)
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
