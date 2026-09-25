import XCTest
import SQLite3
@testable import LevelEditorFormats

final class LevelHUDRecordingTests: XCTestCase {
    private func fixture() throws -> AuthoredDatabaseFixture {
        try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
    }

    @MainActor func testHUDSelectionCooldownAndActivationsReplayAtEverySpeedWithoutWrites() throws {
        let fixture = try fixture()
        let content = try BattleTestFixture.authored(db: fixture.db)
        let sim = try GameSimulation(recording: .database(fixture.db.levelRunDao, .player),
            content: content, startingMoney: nil, heroesEnabled: true, seed: 1776)
        let engine = sim.engine
        let entrance = try XCTUnwrap(engine.callWaveButtonPositions.first)
        engine.activateHUD(.primaryHero)
        engine.tapCallWave(at: entrance)
        var expected = [LevelHUDState(engine: engine)]
        for tick in 1...180 {
            sim.step()
            switch tick {
            case 30: engine.activateHUD(.reinforcements)
            case 45:
                let road = try XCTUnwrap(engine.paths.first)
                let point = road.point(atDistance: road.totalLength / 2)
                engine.placeReinforcements(at: CGPoint(x: point.x, y: point.y))
                XCTAssertFalse(engine.reinforcementCooldown.isReady)
            case 60: engine.activateHUD(.speed)
            case 70:
                engine.activateHUD(.pause)
                XCTAssertTrue(engine.isPaused)
                engine.resume()
            case 80: engine.tapCallWave(at: entrance)
            case 100:
                engine.activateHUD(.secondaryHero)
                engine.activateHUD(.inventory)
            case 125: engine.activateHUD(.primaryHero)
            default: break
            }
            expected.append(LevelHUDState(engine: engine))
        }
        sim.finishRecording(status: .abandoned)
        let id = try XCTUnwrap(sim.runID)
        XCTAssertTrue(expected[0].heroes[0].isSelected)
        XCTAssertTrue(expected[0].callWaveSelection.isSelected(entrance, for: 1))
        XCTAssertTrue(expected[30].isPlacingReinforcements)
        XCTAssertFalse(expected[45].isPlacingReinforcements)
        XCTAssertGreaterThan(expected[45].reinforcementCooldown.remainingFraction, 0)
        XCTAssertTrue(expected[60].isActivated(.speed))
        XCTAssertFalse(expected[90].isActivated(.speed))
        XCTAssertTrue(expected[70].isActivated(.pause), "Same-tick resume must preserve the pause activation")
        XCTAssertTrue(expected[80].callWaveSelection.hasConfirmed)
        XCTAssertEqual(Set(expected.flatMap(\.activated)), Set(LevelHUDControl.allCases))

        // A replay keeps the played HUD layout even after the authored selection changes.
        try fixture.db.hudLayoutDao.set(hudLayoutConfig: content.hudLayout.moving(.heroBar, to: .northEast))
        let writes = sqlite3_total_changes(fixture.connection)
        for speed in [0.5, 1.0, 4.0] {
            let playback = try LevelReplayPlayback(dao: fixture.db.levelRunDao, runID: id, speed: PlaySpeed(speed))
            XCTAssertEqual(playback.setup.hudLayout, content.hudLayout)
            XCTAssertEqual(playback.frame.hud, expected[0])
            for hud in expected.dropFirst() {
                try playback.advance(wallSeconds: SimClock.dt / speed)
                XCTAssertEqual(playback.frame.hud, hud)
            }
        }
        XCTAssertEqual(sqlite3_total_changes(fixture.connection), writes)
    }

    @MainActor func testDifferentWaveEntranceRequiresItsOwnConfirmationAndRecordsSelection() throws {
        let fixture = try fixture()
        let authored = try BattleTestFixture.authored(db: fixture.db)
        // Expose both authored entrances to this wave. Charleston's first
        // campaign wave uses only one route.
        let content = try BattleTestFixture.content(level: authored.level, enemies: authored.enemies, base: authored)
        let sim = try GameSimulation(recording: .database(fixture.db.levelRunDao, .player),
            content: content, startingMoney: nil, heroesEnabled: true, seed: 2)
        let points = sim.engine.callWaveButtonPositions
        guard points.count > 1 else { return XCTFail("Fixture needs two wave entrances") }
        sim.engine.tapCallWave(at: points[0])
        sim.step()
        sim.engine.tapCallWave(at: points[1])
        XCTAssertTrue(sim.engine.callWaveSelection.isSelected(points[1], for: 1))
        XCTAssertEqual(sim.engine.waveSchedule.nextWaveIndex, 0)
        sim.step()
        sim.engine.tapCallWave(at: points[1])
        XCTAssertEqual(sim.engine.waveSchedule.nextWaveIndex, 1)
        sim.finishRecording(status: .abandoned)
        let replay = try LevelReplayer(dao: fixture.db.levelRunDao, runID: XCTUnwrap(sim.runID))
        XCTAssertTrue(try replay.advance())
        XCTAssertTrue(try XCTUnwrap(replay.frame?.hud).callWaveSelection.isSelected(points[0], for: 1))
        XCTAssertTrue(try replay.advance())
        XCTAssertTrue(try XCTUnwrap(replay.frame?.hud).callWaveSelection.isSelected(points[1], for: 1))
        XCTAssertTrue(try replay.advance())
        XCTAssertTrue(try XCTUnwrap(replay.frame?.hud).callWaveSelection.hasConfirmed)
    }

    private func omitting<T: Encodable>(_ key: String, from value: T) throws -> Data {
        let data = try PropertyListEncoder().encode(value)
        var dictionary = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        dictionary.removeValue(forKey: key)
        let edited = try PropertyListSerialization.data(fromPropertyList: dictionary, format: .binary, options: 0)
        return try (edited as NSData).compressed(using: .lz4) as Data
    }

    @MainActor func testOldRecordingsRemainReadableButMissingHUDInNewRecordingsFails() throws {
        let fixture = try fixture(), dao = fixture.db.levelRunDao
        let sim = try GameSimulation(recording: .preview, content: BattleTestFixture.authored(db: fixture.db),
            startingMoney: nil, heroesEnabled: true, seed: 3)
        let setup = LevelReplaySetup(engine: sim.engine, seed: 3, heroesEnabled: true)
        let oldFrame = try omitting("hud", from: LevelReplayFrame(sim.engine))
        for legacy in [true, false] {
            let blob = try legacy ? omitting("hudLayout", from: setup) : LevelRecordingCodec.encode(setup)
            let id = try dao.begin(levelID: setup.level.id, source: .player, playSpeed: setup.playSpeed, setup: blob)
            try dao.append(runID: id, after: -1, actions: [PendingLevelAction(tick: 0, category: "presentation",
                name: "frame", payload: "{}", presentation: oldFrame)])
            try dao.finish(id: id, status: .abandoned, resultJSON: nil)
            let replay = try LevelReplayer(dao: dao, runID: id)
            if legacy {
                XCTAssertTrue(try replay.advance())
                XCTAssertNil(replay.frame?.hud)
            } else {
                XCTAssertThrowsError(try replay.advance()) { XCTAssertTrue(String(describing: $0).contains("missing recorded HUD")) }
            }
        }
    }
}
