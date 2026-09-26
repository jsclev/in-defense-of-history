import XCTest
import CryptoKit
import SQLite3
@testable import LevelEditorFormats

final class GeneticReplayTests: XCTestCase {
    @MainActor func testVisiblePlaybackBatchesMatchHeadlessEvaluation() throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let id = try XCTUnwrap(fixture.db.levelInfoDao.getIdBy(levelName: "Charleston"))
        let study = try AuthoredMoneyStudy(db: fixture.db, levelID: id)
        let strategy = GeneticStrategy(plan: try MoneyStudyPlan(study: study,
            placementIndex: 7, upgradePolicyIndex: 2, seed: 1776),
            metaProgression: try AuthoredDatabaseFixture.metaProgression(Array(study.battle.playerUpgrades.loadout.selected)))
        let expected = try GeneticCommander.evaluate(strategy, recording: .preview, content: study.battle,
            money: 660, seed: 1776, maxSeconds: 1800)
        let engine = try BattleEngine(recording: .preview, content: study.battle, heroesEnabled: true,
            startingMoneyOverride: 660, seed: 1776, onVictory: { _, _ in 0 })
        // The app supplies artwork measurements before publishing heroes. This
        // clock-parity fixture uses explicit square images; geometry cannot
        // alter gameplay ticks or the recorded combat/economy outcome.
        engine.heroImageAspectRatios = Dictionary(uniqueKeysWithValues: study.battle.deployments.map { ($0.hero.id, 1) })
        engine.publishesPresentation = true
        let playback = GeneticPlayback(sim: GameSimulation(engine: engine), strategy: strategy,
            seed: 1776, maxSeconds: 1800)
        let batches = [0, 1, 4, 2, 8, 0, 3]
        var index = 0
        while !playback.isFinished {
            try playback.advance(ticks: batches[index % batches.count])
            engine.advance(ticks: 0, interpolation: 0.5)
            engine.advance(ticks: 0, interpolation: 1)
            index += 1
        }
        XCTAssertEqual(playback.evaluation, expected)
        try playback.advance(ticks: 100)
        XCTAssertEqual(playback.evaluation, expected, "Finished playback must remain frozen")
    }

    @MainActor func testReplayRejectsChangedAndMissingAuthoredContent() throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let id = try XCTUnwrap(fixture.db.levelInfoDao.getIdBy(levelName: "Charleston"))
        let study = try AuthoredMoneyStudy(db: fixture.db, levelID: id)
        let strategy = GeneticStrategy(plan: try MoneyStudyPlan(study: study,
            placementIndex: 7, upgradePolicyIndex: 2, seed: 1776),
            metaProgression: try AuthoredDatabaseFixture.metaProgression(Array(study.battle.playerUpgrades.loadout.selected)))
        let expected = try GeneticCommander.evaluate(strategy, recording: .preview, content: study.battle,
            money: 660, seed: 1776, maxSeconds: 2)
        let digest = SHA256.hash(data: try study.replaySnapshot(db: fixture.db, heroesEnabled: true))
            .map { String(format: "%02x", $0) }.joined()
        let document = GeneticReplayDocument(format: "genetic-replay-v6", contentSHA256: digest,
            executableSHA256: "retained-cli-binary", money: 660, maxGameSeconds: 2,
            starsUsed: study.battle.playerUpgrades.loadout.spentStars, bountyFraction: 1,
            heroLoadout: try GeneticHeroLoadout(content: study.battle), strategy: strategy, expected: expected)
        XCTAssertNoThrow(try document.loadStudy(db: fixture.db, levelName: "Charleston"))
        XCTAssertEqual(sqlite3_exec(fixture.connection,
            "UPDATE tower SET cost=cost+1", nil, nil, nil), SQLITE_OK)
        XCTAssertThrowsError(try document.loadStudy(db: fixture.db, levelName: "Charleston"))
        XCTAssertEqual(sqlite3_exec(fixture.connection,
            "DELETE FROM combat_rules", nil, nil, nil), SQLITE_OK)
        XCTAssertThrowsError(try document.loadStudy(db: fixture.db, levelName: "Charleston"))
    }
}
