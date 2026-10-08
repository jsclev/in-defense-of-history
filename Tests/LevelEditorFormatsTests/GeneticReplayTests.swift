import XCTest
import CryptoKit
import SQLite3
@testable import LevelEditorFormats

final class GeneticReplayTests: XCTestCase {
    private func scalar(_ sql: String, _ fixture: AuthoredDatabaseFixture) throws -> Int64 {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(fixture.connection, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(fixture.connection)))
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { throw DbError.Db(message: "Missing scalar") }
        return sqlite3_column_int64(statement, 0)
    }

    @MainActor func testFullWinningAndLosingEvaluationsNeedNoPlaybackAndMatchRecordedReruns() throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        // Recording parity must not depend on a published campaign winner:
        // authored wave/content changes deliberately invalidate that catalog.
        let source = try BattleTestFixture.authored(db: fixture.db)
        let ranger = try XCTUnwrap(source.enemies.first { $0.id == Foe.queensRanger.id })
        var level = BattleTestFixture.level(enemy: ranger, slots: [Point(200, 90)])
        level.numStartingLives = 1
        let battle = try BattleTestFixture.content(level: level, enemies: source.enemies, base: source)
        let ranged = try XCTUnwrap(battle.arsenal.towers.first { $0.kind == .ranged })
        let finalTier = try XCTUnwrap(ranged.tiers.first { $0.level == 4 && $0.branch == 1 })
        let progression = try AuthoredDatabaseFixture.metaProgression([])
        let reinforcements = ReinforcementStrategy(priority: .nearestExit, holdSeconds: 1000)
        let winning = GeneticStrategy(decisions: [
            .init(step: .init(time: 0, action: .build(slot: 0, towerID: finalTier.id))),
            .init(step: .init(time: 0, action: .upgrade(slot: 0))),
            .init(step: .init(time: 0, action: .upgrade(slot: 0))),
            .init(step: .init(time: 0, action: .upgrade(slot: 0)))
        ], metaProgression: progression, reinforcements: reinforcements)
        let losing = GeneticStrategy(decisions: [], metaProgression: progression,
                                     reinforcements: reinforcements)
        let cases: [(GeneticStrategy, UInt64, Outcome)] = [
            (winning, 1776, .victory),
            (losing, UInt64.max, .defeat)
        ]
        for (strategy, seed, outcome) in cases {
            let runsBefore = try scalar("SELECT count(*) FROM level_run", fixture)
            let rowsBefore = try scalar("SELECT count(*) FROM level_action", fixture)
            let started = ProcessInfo.processInfo.systemUptime
            let evaluation = try GeneticCommander.evaluate(strategy, recording: .evaluation, content: battle,
                money: level.startingMoney, seed: seed, maxSeconds: 1800, heroesEnabled: false)
            let evaluationSeconds = ProcessInfo.processInfo.systemUptime - started
            XCTAssertNil(evaluation.runID)
            XCTAssertEqual(evaluation.result.outcome, outcome)
            XCTAssertEqual(try scalar("SELECT count(*) FROM level_run", fixture), runsBefore)
            XCTAssertEqual(try scalar("SELECT count(*) FROM level_action", fixture), rowsBefore)
            let recordStarted = ProcessInfo.processInfo.systemUptime
            let recorded = try GeneticCommander.evaluate(strategy, recording: .database(fixture.db.levelRunDao, .simulator),
                content: battle, money: level.startingMoney, seed: seed, maxSeconds: 1800, heroesEnabled: false)
            let recordedSeconds = ProcessInfo.processInfo.systemUptime - recordStarted
            XCTAssertEqual(recorded, evaluation)
            XCTAssertEqual(recorded.builtTowersByKind, evaluation.builtTowersByKind)
            XCTAssertEqual(GeneticFitness([recorded]), GeneticFitness([evaluation]))
            let recordingID = try XCTUnwrap(recorded.runID)
            XCTAssertEqual(try scalar("SELECT count(*) FROM level_run", fixture), runsBefore + 1)
            let bytes = try scalar("SELECT coalesce(sum(length(event_data)),0) FROM level_action WHERE run_id='\(recordingID)'", fixture)
            XCTAssertGreaterThan(bytes, 0)
            let replay = try LevelReplayer(dao: fixture.db.levelRunDao, runID: recordingID)
            while try replay.advance() {}
            print("GA recording comparison: \(outcome.rawValue), seed=\(seed), evaluationSeconds=\(evaluationSeconds), recordedSeconds=\(recordedSeconds), evaluationPlaybackBytes=0, recordedEventBytes=\(bytes)")
        }
    }

    @MainActor func testEvaluationSkipsPayloadSerializationAndPoseUpdates() throws {
        let battle = try BattleEngine(recording: .evaluation, content: BattleTestFixture.authored(), heroesEnabled: true,
            startingMoneyOverride: 1000, seed: 1776, onVictory: { _, _ in 0 })
        var payloads = 0, actions = 0
        func payload() -> [String: String] { payloads += 1; return ["unused": "value"] }
        battle.recordingInput("test", payload()) { actions += 1 }
        battle.recordCombat("test", payload())
        XCTAssertEqual(actions, 1)
        XCTAssertEqual(payloads, 0)
        XCTAssertEqual(battle.perform(.build(slot: 17, kind: .melee)), .ok)
        XCTAssertEqual(battle.perform(.startWave), .ok)
        battle.advance(ticks: 300, interpolation: 0)
        XCTAssertNil(battle.runRecorder)
        XCTAssertTrue(battle.militiaPoses.isEmpty)
        XCTAssertTrue(battle.militiaPrevPositions.isEmpty)
        XCTAssertTrue(battle.recordedFacingTargets.isEmpty)
    }

    @MainActor func testVisiblePlaybackBatchesMatchHeadlessEvaluation() throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let id = try XCTUnwrap(fixture.db.levelInfoDao.getIdBy(levelName: "Yorktown"))
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
        let id = try XCTUnwrap(fixture.db.levelInfoDao.getIdBy(levelName: "Yorktown"))
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
        XCTAssertNoThrow(try document.loadStudy(db: fixture.db, levelName: "Yorktown"))
        XCTAssertEqual(sqlite3_exec(fixture.connection,
            "UPDATE tower SET cost=cost+1", nil, nil, nil), SQLITE_OK)
        XCTAssertThrowsError(try document.loadStudy(db: fixture.db, levelName: "Yorktown"))
        XCTAssertEqual(sqlite3_exec(fixture.connection,
            "DELETE FROM combat_rules", nil, nil, nil), SQLITE_OK)
        XCTAssertThrowsError(try document.loadStudy(db: fixture.db, levelName: "Yorktown"))
    }
}
