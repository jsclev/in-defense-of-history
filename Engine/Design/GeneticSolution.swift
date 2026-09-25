import Foundation
import CryptoKit

/// Identifies the battle searched, independently of the player's current star
/// ledger/selection. Candidate DNA carries the exact selected upgrades.
public struct GeneticSolutionContext: Codable, Equatable, Sendable {
    public let levelID: UUID
    public let difficultyID: UUID
    public let startingMoney: Int
    public let bountyFraction: Double
    public let maxGameSeconds: Double
    public let contentSHA256: String
    /// nil only in archived format-1 solutions, which explicitly excluded heroes.
    public let heroLoadout: GeneticHeroLoadout?

    public init(study: AuthoredMoneyStudy, db: Db, startingMoney: Int,
                bountyFraction: Double, maxGameSeconds: Double) throws {
        levelID = study.level.id
        difficultyID = study.difficulty.id
        self.startingMoney = startingMoney
        self.bountyFraction = bountyFraction
        self.maxGameSeconds = maxGameSeconds
        heroLoadout = try GeneticHeroLoadout(content: study.battle)
        // Reuse the replay's complete content snapshot, excluding only mutable
        // progression. Costs, prerequisites, maps, waves and tuning stay hashed.
        var content = try JSONSerialization.jsonObject(with: study.replaySnapshot(db: db, heroesEnabled: true)) as! [String: Any]
        content.removeValue(forKey: "metaProgression")
        content["campaignUpgrades"] = (content["campaignUpgrades"] as! [[String: Any]]).map { upgrade in
            var definition = upgrade
            definition.removeValue(forKey: "selected")
            return definition
        }
        let data = try JSONSerialization.data(withJSONObject: content, options: [.sortedKeys])
        contentSHA256 = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        try validate()
    }

    func validate() throws {
        try heroLoadout?.validate()
        guard startingMoney > 0, bountyFraction.isFinite, (0...1).contains(bountyFraction),
              maxGameSeconds.isFinite, maxGameSeconds > 0, Self.isDigest(contentSHA256) else {
            throw DbError.Db(message: "genetic_solution: invalid context money/bounty/time/contentSHA256")
        }
    }

    static func isDigest(_ value: String) -> Bool {
        value.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
}

public enum GeneticSolutionPanel: String, Codable, Sendable {
    case training, validation
}

/// Self-contained shipping content: no dependency on simulator history, report
/// files or level-run recordings. "Best" means best found, not proven optimal.
public struct GeneticSolution: Codable, Sendable {
    public let formatVersion: Int
    public let runID: UUID
    public let executableSHA256: String
    public let context: GeneticSolutionContext
    public let heroesEnabled: Bool
    public let panel: GeneticSolutionPanel
    public let expectedSamples: Int
    public let candidate: GeneticCandidate

    public var validationComplete: Bool { panel == .validation && candidate.evaluations.count == expectedSamples }
    public var victories: Int { candidate.evaluations.filter { $0.result.outcome == .victory }.count }

    func validate() throws {
        let record = "genetic_solution[\(runID)/\(candidate.id)/\(panel.rawValue)]"
        try context.validate()
        let supported = (formatVersion == 1 && !heroesEnabled && context.heroLoadout == nil)
            || (formatVersion == 2 && heroesEnabled && context.heroLoadout != nil)
        guard supported, GeneticSolutionContext.isDigest(executableSHA256) else {
            throw DbError.Db(message: "\(record): invalid formatVersion/heroesEnabled/executableSHA256")
        }
        guard candidate.id >= 0, candidate.generation >= 0, candidate.starsUsed >= 0 else {
            throw DbError.Db(message: "\(record): invalid candidate id/generation/starsUsed")
        }
        let samples = candidate.evaluations
        guard expectedSamples > 0, !samples.isEmpty, samples.count <= expectedSamples,
              Set(samples.map(\.seed)).count == samples.count else {
            throw DbError.Db(message: "\(record): invalid evaluations/expectedSamples or duplicate seed")
        }
        guard samples.allSatisfy({ $0.result.seconds.isFinite && $0.result.seconds >= 0 &&
            $0.result.livesRemaining >= 0 && $0.wavesStarted >= 0 }) else {
            throw DbError.Db(message: "\(record): invalid evaluation seconds/livesRemaining/wavesStarted")
        }
    }
}
