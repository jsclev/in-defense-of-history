import Foundation
import Combine

/// A live demonstration of saved player inputs. Combat and command eligibility
/// remain in GeneticPlayback -> GameSimulation -> BattleEngine.
@MainActor final class GeneticSolutionPlayback: ObservableObject {
    let solution: GeneticSolution
    let engine: BattleEngine
    let expected: GeneticEvaluation
    private let playback: GeneticPlayback
    private var pendingGameSeconds = 0.0
    @Published private(set) var isPaused = false
    @Published private(set) var isFinished = false
    @Published private(set) var speed: PlaySpeed

    static func best(db: Db, levelID: UUID, difficultyID: UUID) throws -> GeneticSolution? {
        let current = try AuthoredMoneyStudy(db: db, levelID: levelID)
        let candidates = try db.geneticSolutionDao.campaignCandidates(levelID: levelID,
            difficultyID: difficultyID, startingMoney: current.level.startingMoney,
            earnedStars: current.battle.playerUpgrades.loadout.starBudget)
        for solution in candidates {
            if try compatibleStudy(solution, db: db) != nil { return solution }
        }
        return nil
    }

    private static func compatibleStudy(_ solution: GeneticSolution, db: Db) throws -> AuthoredMoneyStudy? {
        try solution.validate()
        guard solution.heroesEnabled, solution.validationComplete, solution.victories > 0,
              solution.context.bountyFraction == 1, let heroes = solution.context.heroLoadout else { return nil }
        let copy = try BountyExperimentDAO.contentCopy(of: db, fraction: 1, selectedHeroIDs: heroes.selectedHeroIDs,
            heroAI: Dictionary(uniqueKeysWithValues: heroes.deployments.map { ($0.heroID, $0.aiEnabled) }))
        defer { copy.close() }
        try copy.difficultyDao.setSelected(difficultyID: solution.context.difficultyID)
        let study = try AuthoredMoneyStudy(db: copy, levelID: solution.context.levelID)
        let context = try GeneticSolutionContext(study: study, db: copy,
            startingMoney: study.level.startingMoney, bountyFraction: 1,
            maxGameSeconds: solution.context.maxGameSeconds)
        guard context == solution.context else { return nil }
        try solution.candidate.strategy.validate(study: study)
        let selected = try study.selectingMetaUpgrades(Set(solution.candidate.strategy.metaUpgrades))
        guard selected.battle.playerUpgrades.loadout.spentStars == solution.candidate.starsUsed else {
            throw DbError.Db(message: "genetic_solution[\(solution.runID)/\(solution.candidate.id)]: incorrect starsUsed")
        }
        return selected
    }

    init(solution: GeneticSolution, db: Db) throws {
        guard let study = try Self.compatibleStudy(solution, db: db),
              let expected = solution.candidate.evaluations.filter({ $0.result.outcome == .victory })
                .sorted(by: {
                    if $0.result.livesRemaining != $1.result.livesRemaining {
                        return $0.result.livesRemaining > $1.result.livesRemaining
                    }
                    return $0.seed < $1.seed
                }).first else {
            throw DbError.Db(message: "This winning solution no longer matches the authored level content.")
        }
        self.solution = solution
        self.expected = expected
        let initialSpeed = try PlaySpeed(1)
        speed = initialSpeed
        // No money override, progression reward, or changes to the player profile.
        engine = try BattleEngine(recording: .preview, content: study.battle, playSpeed: initialSpeed,
            heroesEnabled: true, startingMoneyOverride: nil, seed: expected.seed, onVictory: { _, _ in 0 })
        playback = GeneticPlayback(sim: GameSimulation(engine: engine), strategy: solution.candidate.strategy,
            seed: expected.seed, maxSeconds: solution.context.maxGameSeconds)
    }

    func togglePause() {
        guard !isFinished else { return }
        isPaused.toggle()
    }

    func setSpeed(_ speed: PlaySpeed) {
        self.speed = speed
        engine.setPlaySpeed(speed)
    }

    func advance(wallSeconds: Double) throws {
        guard !isPaused, !isFinished else { return }
        precondition(wallSeconds.isFinite && wallSeconds >= 0)
        pendingGameSeconds += wallSeconds * speed.factor
        while pendingGameSeconds + 1e-12 >= SimClock.dt && !playback.isFinished {
            try playback.advance(ticks: 1)
            pendingGameSeconds = max(0, pendingGameSeconds - SimClock.dt)
        }
        engine.advance(ticks: 0, interpolation: min(1, pendingGameSeconds / SimClock.dt))
        if playback.isFinished {
            isFinished = true
            pendingGameSeconds = 0
            engine.advance(ticks: 0, interpolation: 1)
            guard playback.evaluation == expected else {
                throw DbError.Db(message: "The live solution differs from its saved winning result; run the GA again with the current engine.")
            }
        }
    }
}
