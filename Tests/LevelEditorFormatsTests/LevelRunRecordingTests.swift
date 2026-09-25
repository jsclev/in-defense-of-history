import XCTest
import SQLite3
@testable import LevelEditorFormats

final class LevelRunRecordingTests: XCTestCase {
    private func fixture() throws -> AuthoredDatabaseFixture {
        try AuthoredDatabaseFixture(levelGeoJSONDao: LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
    }
    private func frameData(_ frame: LevelReplayFrame) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        return try encoder.encode(frame)
    }
    private func allActions(_ dao: LevelRunDAO, _ id: UUID) throws -> [LevelActionRecord] {
        var rows: [LevelActionRecord] = []
        let replay = try LevelReplayer(dao: dao, runID: id)
        while try replay.advance() { rows += replay.actions }
        return rows
    }

    @MainActor func testPlayerAndSimulatorCreateDistinctRunsAndRecordActualPurchases() throws {
        let fixture = try fixture(), dao = fixture.db.levelRunDao
        let content = try BattleTestFixture.authored(db: fixture.db)
        let earliestStart = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))
        let player = try BattleEngine(recording: .database(dao, .player), content: content,
            heroesEnabled: false, startingMoneyOverride: 100_000, seed: 123, onVictory: { _, _ in 0 })
        let sim = try GameSimulation(recording: .database(dao, .simulator), content: content,
            startingMoney: 100_000, heroesEnabled: false, seed: 123)
        let playerID = try XCTUnwrap(player.runID), simID = try XCTUnwrap(sim.runID)
        XCTAssertNotEqual(playerID, simID)
        let startedRuns = try [playerID, simID].map { try dao.get(id: $0) }
        for run in startedRuns {
            XCTAssertGreaterThanOrEqual(run.startedAt, earliestStart)
            XCTAssertLessThanOrEqual(run.startedAt, Date())
            XCTAssertNil(run.finishedAt)
        }
        player.selectSlot(0)
        XCTAssertNil(player.tapBuildButton(.ranged))
        XCTAssertEqual(player.tapBuildButton(.ranged), .ok)
        XCTAssertEqual(sim.perform(.build(slot: 0, kind: .ranged)), .ok)
        for level in 2...4 {
            player.selectPlacedTower(atSlot: 0)
            let branch = try XCTUnwrap(player.upgradeOffers.first(where: { $0.nextLevel == level })).branch
            player.tapUpgradeButton(branch: branch)
            XCTAssertEqual(player.tapUpgradeButton(branch: branch), .ok)
            XCTAssertEqual(sim.perform(.upgrade(slot: 0, branch: branch)), .ok)
        }
        let path = try XCTUnwrap(player.towerLevel(for: player.placedTowers[0])?.upgradePaths.first)
        player.selectPlacedTower(atSlot: 0); player.tapUpgradePath(path.id)
        XCTAssertEqual(player.tapUpgradePath(path.id), .ok)
        XCTAssertEqual(sim.perform(.purchaseUpgrade(slot: 0, pathID: path.id)), .ok)
        let earliestFinish = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))
        player.finishRecording(status: .abandoned); sim.finishRecording(status: .abandoned)
        for started in startedRuns {
            let finished = try dao.get(id: started.id)
            XCTAssertEqual(finished.startedAt, started.startedAt)
            XCTAssertGreaterThanOrEqual(try XCTUnwrap(finished.finishedAt), earliestFinish)
            XCTAssertLessThanOrEqual(try XCTUnwrap(finished.finishedAt), Date())
        }
        let playerRows = try allActions(dao, playerID), simRows = try allActions(dao, simID)
        XCTAssertEqual(playerRows.filter { $0.name == "towerBuilt" }.count, 1)
        XCTAssertEqual(simRows.filter { $0.name == "towerBuilt" }.count, 1)
        XCTAssertEqual(playerRows.filter { $0.name == "towerUpgraded" }.count, 3)
        XCTAssertTrue(playerRows.contains { $0.name == "tapUpgradePath" })
        XCTAssertTrue(simRows.contains { $0.payloadJSON.contains("purchaseUpgrade") })
        XCTAssertEqual(try dao.get(id: playerID).source, .player)
        XCTAssertEqual(try dao.get(id: simID).source, .simulator)
        for rows in [playerRows, simRows] {
            XCTAssertEqual(rows.map(\.sequence), (0..<rows.count).map(Int64.init))
        }
        let replay = try LevelReplayer(dao: dao, runID: playerID)
        XCTAssertTrue(try replay.advance())
        XCTAssertEqual(replay.frame?.towers.first?.upgrades, player.placedTowers.first?.upgrades)
    }

    @MainActor func testRunHistoryLoadsSavedCalendarDatesAndRejectsMalformedTimestamps() throws {
        let fixture = try fixture(), dao = fixture.db.levelRunDao
        let content = try BattleTestFixture.authored(db: fixture.db)
        let sim = try GameSimulation(recording: .database(dao, .player), content: content,
            startingMoney: nil, heroesEnabled: false, seed: 1)
        let id = try XCTUnwrap(sim.runID)
        sim.finishRecording(status: .abandoned)
        let dates = [("started_at", "2026-09-25T14:30:00Z"), ("finished_at", "2026-09-25T14:45:00Z")]
        func update(_ field: String, _ value: String) throws {
            guard sqlite3_exec(fixture.connection,
                "UPDATE level_run SET \(field)='\(value)' WHERE id='\(id)'", nil, nil, nil) == SQLITE_OK else {
                throw DbError.Db(message: String(cString: sqlite3_errmsg(fixture.connection)))
            }
        }
        for (field, value) in dates { try update(field, value) }
        let run = try dao.get(id: id)
        let listed = try XCTUnwrap(dao.runs(levelID: content.level.id).first)
        XCTAssertEqual(run.startedAt, ISO8601DateFormatter().date(from: dates[0].1))
        XCTAssertEqual(run.finishedAt, ISO8601DateFormatter().date(from: dates[1].1))
        XCTAssertEqual(listed.id, id)
        XCTAssertEqual(listed.startedAt, run.startedAt)
        XCTAssertEqual(listed.finishedAt, run.finishedAt)
        for (field, value) in dates {
            try update(field, "not-a-date")
            XCTAssertThrowsError(try dao.get(id: id)) { error in
                XCTAssertTrue(String(describing: error).contains(id.uuidString))
                XCTAssertTrue(String(describing: error).contains(field))
            }
            XCTAssertThrowsError(try dao.runs(levelID: content.level.id))
            try update(field, value)
        }
    }

    @MainActor func testEveryCommandIncludingRejectedInputsAndControlsIsRecorded() throws {
        let fixture = try fixture(), dao = fixture.db.levelRunDao
        let content = try BattleTestFixture.authored(db: fixture.db)
        let sim = try GameSimulation(recording: .database(dao, .simulator), content: content,
            startingMoney: 1, heroesEnabled: true, seed: 1)
        let hero = try XCTUnwrap(content.deployments.first?.hero.id)
        let commands: [BattleCommand] = [.build(slot: 0, kind: .ranged), .upgrade(slot: 0, branch: 1),
            .purchaseUpgrade(slot: 0, pathID: "missing"), .rally(slot: 0, point: Point(0, 0)),
            .placeDemolition(slot: 0, point: Point(0, 0)), .placeObstacles(slot: 0, point: Point(0, 0)),
            .setHeroAI(id: hero, enabled: false), .moveHero(id: hero, point: Point(-1e6, -1e6)),
            .reinforcements(point: Point(-1e6, -1e6)), .startWave]
        for command in commands { _ = sim.perform(command) }
        sim.engine.pause(); sim.engine.resume(); sim.engine.speedUp()
        sim.step(); sim.finishRecording(status: .timeout)
        let rows = try allActions(dao, XCTUnwrap(sim.runID))
        XCTAssertEqual(rows.filter { $0.category == "input" && $0.name == "command" }.count, commands.count)
        XCTAssertTrue(rows.contains { $0.payloadJSON.contains("needGold") })
        for name in ["pause", "resume", "speedUp", "waveStarted"] { XCTAssertTrue(rows.contains { $0.name == name }, name) }
        XCTAssertFalse(rows.contains { $0.name == "towerBuilt" })
        XCTAssertEqual(try dao.get(id: XCTUnwrap(sim.runID)).status, .timeout)
    }

    @MainActor func testReplayUsesRecordedStateAfterContentChangesAndNeverWrites() throws {
        let fixture = try fixture(), dao = fixture.db.levelRunDao
        let content = try BattleTestFixture.authored(db: fixture.db)
        let sim = try GameSimulation(recording: .database(dao, .simulator), content: content,
            startingMoney: 1000, heroesEnabled: false, seed: 2)
        XCTAssertEqual(sim.perform(.build(slot: 0, kind: .ranged)), .ok)
        sim.startNextWave()
        var expected: [Data] = []
        for _ in 0..<90 {
            sim.step()
            expected.append(try frameData(LevelReplayFrame(sim.engine)))
        }
        sim.finishRecording(status: .timeout)
        let id = try XCTUnwrap(sim.runID)
        let count = sqlite3_total_changes(fixture.connection)
        let replay = try LevelReplayer(dao: dao, runID: id)
        XCTAssertTrue(try replay.advance()) // Tick zero includes the completed purchases.
        for frame in expected {
            XCTAssertTrue(try replay.advance())
            XCTAssertEqual(try frameData(XCTUnwrap(replay.frame)), frame)
        }
        XCTAssertFalse(try replay.advance())
        XCTAssertEqual(sqlite3_total_changes(fixture.connection), count, "Playback must be read-only")
        XCTAssertEqual(sqlite3_exec(fixture.connection, "UPDATE tower SET shot_min_damage=shot_min_damage+9,shot_max_damage=shot_max_damage+9", nil, nil, nil), SQLITE_OK)
        let changedContent = try BattleTestFixture.authored(db: fixture.db)
        XCTAssertNotEqual(changedContent.arsenal.towerTypes[0].levels[0].shotMinDamage, content.arsenal.towerTypes[0].levels[0].shotMinDamage)
        let after = try LevelReplayer(dao: dao, runID: id)
        XCTAssertTrue(try after.advance())
        for frame in expected { XCTAssertTrue(try after.advance()); XCTAssertEqual(try frameData(XCTUnwrap(after.frame)), frame) }
    }

    @MainActor func testGeneticEvaluationsKeepEachRecordedRunID() throws {
        let fixture = try fixture(), dao = fixture.db.levelRunDao
        let content = try BattleTestFixture.authored(db: fixture.db)
        let strategy = GeneticStrategy(decisions: [], metaUpgrades: Array(content.playerUpgrades.loadout.selected))
        let first = try GeneticCommander.evaluate(strategy, recording: .database(dao, .simulator), content: content,
            money: 500, seed: 17, maxSeconds: 1)
        let second = try GeneticCommander.evaluate(strategy, recording: .database(dao, .simulator), content: content,
            money: 500, seed: 17, maxSeconds: 1)
        XCTAssertNotEqual(try XCTUnwrap(first.runID), try XCTUnwrap(second.runID))
        XCTAssertEqual(first, second, "Recording must not change engine outcomes")
        XCTAssertEqual(try dao.get(id: XCTUnwrap(first.runID)).status, .timeout)
    }

    @MainActor func testMissingRowsCorruptionAndOutOfOrderWritesFail() throws {
        let fixture = try fixture(), dao = fixture.db.levelRunDao
        XCTAssertThrowsError(try dao.get(id: UUID()))
        let sim = try GameSimulation(recording: .database(dao, .simulator), content: BattleTestFixture.authored(db: fixture.db),
            startingMoney: nil, heroesEnabled: false, seed: 1)
        let id = try XCTUnwrap(sim.runID)
        XCTAssertThrowsError(try LevelReplayer(dao: dao, runID: id))
        let action = PendingLevelAction(tick: 0, category: "input", name: "test", payload: "{}")
        XCTAssertThrowsError(try dao.append(runID: id, after: -1, actions: [action]))
        sim.step(); sim.finishRecording(status: .timeout)
        XCTAssertThrowsError(try dao.append(runID: id, after: dao.get(id: id).lastSequence, actions: [action]))
        XCTAssertEqual(sqlite3_exec(fixture.connection, "DELETE FROM level_action WHERE run_id='\(id)' AND sequence=1", nil, nil, nil), SQLITE_OK)
        let replay = try LevelReplayer(dao: dao, runID: id)
        XCTAssertThrowsError(try replay.advance())
    }

    @MainActor func testRecordedPlayDoesNotChangeCombatAndCapturesHits() throws {
        let fixture = try fixture(), dao = fixture.db.levelRunDao
        let base = try BattleTestFixture.authored(db: fixture.db)
        let enemy = try XCTUnwrap(base.enemies.first)
        let level = BattleTestFixture.level(enemy: enemy, slots: [Point(200, 70)], starts: [Point(0, 0)])
        let content = try BattleTestFixture.content(level: level, enemies: [enemy], base: base)
        let recorded = try GameSimulation(recording: .database(dao, .player), content: content,
            startingMoney: nil, heroesEnabled: false, seed: 1)
        let control = try GameSimulation(recording: .preview, content: content,
            startingMoney: nil, heroesEnabled: false, seed: 1)
        for sim in [recorded, control] {
            XCTAssertEqual(sim.perform(.build(slot: 0, kind: .ranged)), .ok)
            sim.startNextWave()
        }
        for _ in 0..<300 {
            recorded.step(); control.step()
            XCTAssertEqual(recorded.result(), control.result())
            if recorded.outcome != nil { break }
        }
        recorded.finishRecording(status: .timeout)
        let rows = try allActions(dao, XCTUnwrap(recorded.runID))
        XCTAssertTrue(rows.contains { $0.name == "towerFired" })
        XCTAssertTrue(rows.contains { $0.name == "projectileHit" })
        let replayerSource = try String(contentsOf: Db.authoredDatabaseURL.deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Engine/Models/LevelReplayer.swift"), encoding: .utf8)
        for forbidden in ["BattleEngine(", "GameSimulation(", "GeneticCommander(", "advanceBattleTick("] {
            XCTAssertFalse(replayerSource.contains(forbidden))
        }
    }

    @MainActor func testAbandonmentAndMalformedFramesAreNotSuccessfulReplays() throws {
        let fixture = try fixture(), dao = fixture.db.levelRunDao
        var sim: GameSimulation? = try GameSimulation(recording: .database(dao, .simulator),
            content: BattleTestFixture.authored(db: fixture.db), startingMoney: nil, heroesEnabled: false, seed: 1)
        let id = try XCTUnwrap(sim?.runID)
        sim = nil
        XCTAssertEqual(try dao.get(id: id).status, .abandoned)
        XCTAssertEqual(sqlite3_exec(fixture.connection,
            "UPDATE level_action SET presentation=x'01' WHERE run_id='\(id)' AND category='presentation'", nil, nil, nil), SQLITE_OK)
        let replay = try LevelReplayer(dao: dao, runID: id)
        XCTAssertThrowsError(try replay.advance())
    }
}
