import Foundation

/// Provisional search policy, not proof of optimality or player enjoyment.
/// Work counts are actual training battles; cached duplicate DNA adds no effort.
public struct GeneticStoppingPolicy: Codable, Equatable {
    public var minimumTrainingBattles = 1_000_000 // Per requested stars-used group.
    public var stabilityBattles = 250_000
    public var stabilityGenerations = 1_000
    public var solutions = 3
    public init() {}

    func validate() throws {
        guard minimumTrainingBattles > 0, stabilityBattles > 0,
              stabilityGenerations > 0, (1...8).contains(solutions) else {
            throw DbError.Db(message: "genetic stopping: positive effort/stability thresholds and 1–8 solutions required")
        }
    }

    /// The publication policy's existing reliability and all-pairs diversity
    /// gates. Uses observations only; callers freeze the pool before validation.
    public func qualifyingSet(_ candidates: [GeneticCandidate], samples: Int,
                              history: [Int: GeneticCandidate] = [:]) throws -> [GeneticCandidate] {
        let eligible = GeneticCandidate.ranked(candidates.filter {
            $0.evaluations.count == samples && $0.fitness.winRate >= 0.9
                && (history[$0.id] ?? $0).fitness.winRate >= 0.9 && $0.placementPlan?.playstyle != nil
        })
        let selector = GeneticSolutionDiversitySelector()
        return try selector.selectCompleteSet(ranked: eligible, count: solutions,
            plan: { try $0.requirePlacementPlan() },
            pairEligible: { a, b in
                guard try selector.consistentlyDifferent(a, b) else { return false }
                let allA = history[a.id] ?? a, allB = history[b.id] ?? b
                let common = Set(allA.evaluations.map(\.seed)).intersection(allB.evaluations.map(\.seed))
                let left = GeneticCandidate(id:a.id,generation:a.generation,strategy:a.strategy,
                    evaluations:allA.evaluations.filter { common.contains($0.seed) })
                let right = GeneticCandidate(id:b.id,generation:b.generation,strategy:b.strategy,
                    evaluations:allB.evaluations.filter { common.contains($0.seed) })
                return try selector.consistentlyDifferent(left,right)
            }).map(\.item)
    }

    /// Fresh, non-overlapping held-out panels for repeated frozen assessments.
    /// Every attempt's seeds and evidence are retained separately by the DAO.
    public func validationSeeds(base: UInt64, trainingCount: Int, count: Int, attempt: Int) -> [UInt64] {
        precondition(count > 0 && attempt >= 0)
        let offset = UInt64(max(1_000_000, trainingCount)) + UInt64(attempt) * UInt64(count)
        return (0..<count).map { base &+ offset &+ UInt64($0) }
    }
}

/// Assessment evidence is kept separate from training. Previously rejected
/// evidence remains part of reliability and pairwise diversity checks, so a
/// repeated candidate cannot erase failures by drawing a luckier fresh panel.
public struct GeneticQualificationHistory {
    public private(set) var candidates: [Int: GeneticCandidate] = [:]
    public init() {}
    public mutating func append(_ panel: [GeneticCandidate]) throws {
        var updated = candidates
        for candidate in panel {
            let previous = updated[candidate.id]
            guard previous == nil || previous!.strategy == candidate.strategy else {
                throw DbError.Db(message: "qualification history: candidate DNA changed")
            }
            let evaluations = (previous?.evaluations ?? []) + candidate.evaluations
            guard Set(evaluations.map(\.seed)).count == evaluations.count else {
                throw DbError.Db(message: "qualification history: repeated held-out seed")
            }
            updated[candidate.id] = GeneticCandidate(id:candidate.id,generation:candidate.generation,
                strategy:candidate.strategy,evaluations:evaluations)
        }
        candidates = updated
    }
}

/// Training-only progress toward an assessable portfolio. Held-out scores never
/// enter this tracker or breeding. New winning niches are conservative coverage
/// signals; the strict diversity gate separately decides whether a set qualifies.
public struct GeneticSearchConvergence {
    public struct State {
        public fileprivate(set) var battles = 0
        public fileprivate(set) var lastImprovementBattle = 0
        public fileprivate(set) var lastImprovementGeneration = 0
        public fileprivate(set) var lastExplorationBattle = 0
        public fileprivate(set) var lastExplorationGeneration = 0
        public fileprivate(set) var best: GeneticFitness?
        public fileprivate(set) var winningNiches: [String: GeneticFitness] = [:]
    }
    public let policy: GeneticStoppingPolicy
    public private(set) var groups: [Int: State]
    public init(policy: GeneticStoppingPolicy, stars: [Int]) {
        self.policy = policy
        groups = Dictionary(uniqueKeysWithValues: stars.map { ($0, State()) })
    }
    public mutating func observe(_ candidate: GeneticCandidate) {
        observe(stars: candidate.starsUsed, generation: candidate.generation, battles: candidate.evaluations.count,
                fitness: candidate.fitness, winningNiche: candidate.fitness.winRate >= 0.9 ? candidate.behaviorDescriptor?.niche : nil)
    }
    // Also allows deterministic boundary tests without calculating fake battles.
    mutating func observe(stars: Int, generation: Int, battles: Int, fitness: GeneticFitness, winningNiche: String?) {
        precondition(battles > 0 && groups[stars] != nil)
        var state = groups[stars]!
        state.battles += battles
        var improved = state.best == nil || fitness > state.best!
        if improved { state.best = fitness }
        if let niche = winningNiche {
            if state.winningNiches[niche] == nil || fitness > state.winningNiches[niche]! {
                state.winningNiches[niche] = fitness
                improved = true
            }
        }
        if improved {
            state.lastImprovementBattle = state.battles
            state.lastImprovementGeneration = generation
        }
        groups[stars] = state
    }
    public func ready(generation: Int) -> Bool {
        !groups.isEmpty && groups.values.allSatisfy { state in
            state.battles >= policy.minimumTrainingBattles
                && state.battles - max(state.lastImprovementBattle, state.lastExplorationBattle) >= policy.stabilityBattles
                && generation - max(state.lastImprovementGeneration, state.lastExplorationGeneration) >= policy.stabilityGenerations
        }
    }
    /// Missing variety or rejected qualification earns another full exploration
    /// window. Existing evidence and champions stay intact; this is not progress.
    public mutating func restartExploration(generation: Int) {
        for stars in groups.keys {
            groups[stars]!.lastExplorationBattle = groups[stars]!.battles
            groups[stars]!.lastExplorationGeneration = generation
        }
    }
    public func description(generation: Int) -> String {
        groups.keys.sorted().map { stars in
            let s = groups[stars]!
            let battles = s.battles - max(s.lastImprovementBattle, s.lastExplorationBattle)
            let generations = generation - max(s.lastImprovementGeneration, s.lastExplorationGeneration)
            return "\(stars) stars: \(s.battles)/\(policy.minimumTrainingBattles) minimum training battles; stability \(battles)/\(policy.stabilityBattles) battles, \(generations)/\(policy.stabilityGenerations) generations; \(s.winningNiches.count) winning behavior niches"
        }.joined(separator: " | ")
    }
}
