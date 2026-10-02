import Foundation

public struct GeneticStudyOptions: Codable {
    public var money: Int?
    public var workers = 1
    public var population = 64 // Per exact star-spend group.
    /// Zero means no generation ceiling; positive values are explicit work limits.
    public var generations = 0
    public var trainingSeeds = 3
    public var validationSeeds = 64
    public var finalists = 8 // Per exact star-spend group.
    /// Zero means no battle ceiling.
    public var maxEvaluations = 0
    /// Wall time is an optional resource guardrail, never a quality criterion.
    public var hours = 0.0
    /// Nil identifies historical options that predate goal-based stopping.
    public var stopping: GeneticStoppingPolicy? = GeneticStoppingPolicy()
    public var maxGameSeconds = 1800.0
    public var seed: UInt64 = 1776
    public var starMinimum: Int?
    public var starMaximum: Int?
    public var starStep = 1
    public var bountyFraction = 1.0
    public var fixedMeta = false
    public var earlyWaveCalls = true
    public var seedStrategies: [GeneticStrategy] = []
    public var metaSelections = 8
    public var minimumMetaCandidates = 4
    public var metaAdaptationGenerations = 12
    public var metaExchangeFrom: GeneticStrategy?
    public var selectedHeroIDs: [UUID]?
    public var heroAIEnabled: Bool?
    public var towerLimits = GeneticTowerLimits()

    public init() {}

    func starValues(earned: Int) throws -> [Int] {
        let maximum = starMaximum ?? earned
        let minimum = starMinimum ?? maximum
        guard minimum >= 0, maximum >= minimum, maximum <= earned, starStep > 0,
              (maximum - minimum) % starStep == 0 else {
            throw DbError.Db(message: "genetic study: star range must be exact nonnegative steps within the database's \(earned) earned stars")
        }
        return Array(stride(from: minimum, through: maximum, by: starStep))
    }

    func validate(groups: Int) throws {
        guard (money == nil || money! > 0), (1...32).contains(workers), (4...1024).contains(population), generations >= 0,
              (1...1000).contains(trainingSeeds), (1...10_000).contains(validationSeeds),
              (1...population).contains(finalists),
              (1...1024).contains(metaSelections), (2...population).contains(minimumMetaCandidates),
              metaAdaptationGenerations >= 2,
              (maxEvaluations == 0 || maxEvaluations >= groups * (population * trainingSeeds + finalists * validationSeeds)),
              bountyFraction.isFinite, (0...1).contains(bountyFraction), seedStrategies.count <= population,
              hours.isFinite, hours >= 0, maxGameSeconds.isFinite, maxGameSeconds > 0 else {
            throw DbError.Db(message: "genetic study: invalid budget; evaluation ceiling must cover initial populations and validation for all \(groups) reachable star groups")
        }
        try stopping?.validate()
    }
}

/// Search resource limits only. No combat rules, fitness thresholds or claims of
/// convergence. Historical positive ceilings retain their original meaning.
public struct GeneticSearchBudget {
    public let searchDeadline: Double?
    public let deadline: Double?
    public let trainingLimit: Int?
    public let evaluationLimit: Int?
    public let generationLimit: Int?
    private let trainingSeeds: Int

    public init(options: GeneticStudyOptions, startedAt: Double, validationReservation: Int) {
        precondition(startedAt.isFinite && validationReservation >= 0)
        deadline = options.hours > 0 ? startedAt + options.hours * 3600 : nil
        searchDeadline = options.hours > 0 ? startedAt + options.hours * 3600 * GeneticProgress.searchTimeFraction : nil
        generationLimit = options.generations == 0 ? nil : options.generations
        evaluationLimit = options.maxEvaluations == 0 ? nil : options.maxEvaluations
        trainingLimit = evaluationLimit.map { $0 - validationReservation }
        trainingSeeds = options.trainingSeeds
        precondition(trainingLimit == nil || trainingLimit! >= trainingSeeds)
    }

    /// Admit whole training seed panels, including all already queued work.
    public func trainingStopReason(now: Double, completed: Int, pending: Int = 0) -> String? {
        if let searchDeadline, now >= searchDeadline { return "time-budget" }
        if let trainingLimit, completed + pending + trainingSeeds > trainingLimit { return "evaluation-budget" }
        return nil
    }

    public func searchStopReason(now: Double, generations: Int, completed: Int) -> String? {
        if let reason = trainingStopReason(now: now, completed: completed) { return reason }
        if let generationLimit, generations >= generationLimit { return "generation-limit" }
        return nil
    }
}

/// A generation with no new evaluations requests fresh plans on the next turn.
/// It never establishes convergence and never removes existing champions.
public struct GeneticSearchRecovery {
    public private(set) var needsFreshGeneration = false
    public init() {}
    public mutating func completedGeneration(newEvaluations: Int) {
        precondition(newEvaluations >= 0)
        needsFreshGeneration = newEvaluations == 0
    }
}
