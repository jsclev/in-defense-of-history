import Foundation
import CryptoKit

public struct GeneticReplayDocument: Codable {
    let format: String
    let contentSHA256: String
    let executableSHA256: String
    let money: Int
    let maxGameSeconds: Double
    let starsUsed: Int
    let bountyFraction: Double
    let heroLoadout: GeneticHeroLoadout
    let strategy: GeneticStrategy
    let expected: GeneticEvaluation
}

extension GeneticReplayDocument {
    /// Content must still match even though the presentation executable differs
    /// from the original CLI. Completion separately checks the entire outcome.
    @MainActor func loadStudy(db: Db, levelName: String) throws -> AuthoredMoneyStudy {
        guard format == "genetic-replay-v6",
              let id = try db.levelInfoDao.getIdBy(levelName: levelName) else {
            throw DbError.Db(message: "Unsupported replay format or unknown level '\(levelName)'")
        }
        try heroLoadout.validate()
        let copy = try BountyExperimentDAO.contentCopy(of: db, fraction: bountyFraction,
            selectedHeroIDs: heroLoadout.selectedHeroIDs,
            heroAI: Dictionary(uniqueKeysWithValues: heroLoadout.deployments.map { ($0.heroID, $0.aiEnabled) }))
        defer { copy.close() }
        let study = try AuthoredMoneyStudy(db: copy, levelID: id)
        let digest = SHA256.hash(data: try study.replaySnapshot(db: copy, heroesEnabled: true))
            .map { String(format: "%02x", $0) }.joined()
        guard digest == contentSHA256, heroLoadout == (try GeneticHeroLoadout(content: study.battle)) else {
            throw DbError.Db(message: "Authored content differs from the saved replay")
        }
        try strategy.validate(study: study)
        guard try strategy.playerState(in: study.battle).loadout.spentStars == starsUsed,
              money > 0, maxGameSeconds.isFinite, maxGameSeconds > 0 else {
            throw DbError.Db(message: "Replay has invalid stars used or experiment limits")
        }
        return study
    }
}

/// Strategy execution for determinism/parity checks. This is not movie playback;
/// LevelReplayer reads the actual database actions without executing a strategy.
@MainActor public final class GeneticPlayback {
    public let sim: GameSimulation
    private var commander: GeneticCommander
    private let seed: UInt64
    private let maxSeconds: Double
    private var economy: [GeneticWaveEconomy] = []
    private var previousWave = 0

    public init(sim: GameSimulation, strategy: GeneticStrategy, seed: UInt64, maxSeconds: Double) {
        self.sim = sim
        self.commander = GeneticCommander(strategy)
        self.seed = seed
        self.maxSeconds = maxSeconds
    }

    public var isFinished: Bool { sim.outcome != nil || sim.time >= maxSeconds }

    public func advance(ticks: Int) throws {
        precondition(ticks >= 0)
        for _ in 0..<ticks {
            guard !isFinished else { break }
            try commander.tick(sim: sim)
            sim.step()
            if sim.currentWave != previousWave {
                previousWave = sim.currentWave
                economy.append(GeneticWaveEconomy(wave: previousWave, seconds: sim.time,
                                                 money: sim.gold, lives: sim.lives))
            }
        }
    }

    public var evaluation: GeneticEvaluation {
        GeneticEvaluation(seed: seed, result: sim.result(), wavesStarted: sim.currentWave,
                          waveEconomy: economy, reinforcementDeployments: sim.reinforcementDeployments,
                          waveCalls: sim.waveCalls)
    }
}
