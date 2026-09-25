import XCTest
import SQLite3
@testable import LevelEditorFormats

final class CompactRecordingTests: XCTestCase {
    private func fixture() throws -> AuthoredDatabaseFixture {
        try AuthoredDatabaseFixture(levelGeoJSONDao: LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
    }
    private func bytes(_ frame: LevelReplayFrame) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        return try encoder.encode(frame)
    }
    private func rows(_ dao: LevelRunDAO, _ id: UUID) throws -> [LevelActionRecord] {
        var result: [LevelActionRecord] = []
        while true {
            let page = try dao.actions(runID: id, after: result.last?.sequence ?? -1, limit: 3)
            if page.isEmpty { return result }
            result += page
        }
    }

    @MainActor func testSparseMovementCrossesBendsAndBlocksWithExactReplayAndFarFewerRows() throws {
        let fixture = try fixture(), dao = fixture.db.levelRunDao
        let base = try BattleTestFixture.authored(db: fixture.db)
        let enemy = try XCTUnwrap(base.enemies.first)
        var level = BattleTestFixture.level(enemy: enemy, slots: [])
        level.paths = [Path(points: [Point(0, 0), Point(100, 0), Point(100, 200), Point(4000, 200)])]
        let content = try BattleTestFixture.content(level: level, enemies: [enemy], base: base)
        let sim = try GameSimulation(recording: .database(dao, .simulator), content: content,
            startingMoney: nil, heroesEnabled: false, seed: 12)
        sim.startNextWave()
        var expected = [try bytes(LevelReplayFrame(sim.engine))]
        var legacyBytes = try LevelRecordingCodec.encode(LevelReplayFrame(sim.engine)).count
        for _ in 0..<600 {
            sim.step()
            let frame = LevelReplayFrame(sim.engine)
            expected.append(try bytes(frame))
            legacyBytes += try LevelRecordingCodec.encode(frame).count
        }
        sim.finishRecording(status: .timeout)
        let id = try XCTUnwrap(sim.runID), stored = try rows(dao, id)
        let encodedBytes = stored.reduce(0) { $0 + ($1.presentation?.count ?? 0) + $1.payloadJSON.utf8.count }
        XCTAssertLessThan(stored.count, expected.count / 20)
        XCTAssertLessThan(encodedBytes, legacyBytes / 10)
        let blocks = try stored.compactMap { row -> LevelReplayTimeline? in
            guard let data = row.presentation else { return nil }
            XCTAssertEqual(row.name, LevelReplayTimeline.rowName)
            return try LevelRecordingCodec.decode(LevelReplayTimeline.self, from: data)
        }
        XCTAssertGreaterThan(blocks.count, 1, "Exercise multiple bounded database blocks")
        XCTAssertTrue(blocks.flatMap(\.tracks).filter { $0.path.hasSuffix("/pathDistance") }
            .flatMap(\.segments).contains { $0.count > 10 && $0.increment != nil }, "Movement must be represented by segments")
        let replay = try LevelReplayer(dao: dao, runID: id)
        for value in expected {
            XCTAssertTrue(try replay.advance())
            XCTAssertEqual(try bytes(XCTUnwrap(replay.frame)), value)
        }
        XCTAssertFalse(try replay.advance())
        print("COMPACT_RECORDING_METRICS frames=\(expected.count) rows=\(stored.count) oldSnapshotBytes=\(legacyBytes) newRecordBytes=\(encodedBytes)")
    }

    @MainActor func testCachedEnemyRulesPreserveDatabaseChangesWithinOneTimelineBlock() throws {
        let fixture = try fixture()
        let original = try BattleTestFixture.authored(db: fixture.db)
        XCTAssertEqual(sqlite3_exec(fixture.connection,
            "UPDATE combat_rules SET morale_recovery_delay=morale_recovery_delay+3 WHERE id=1", nil, nil, nil), SQLITE_OK)
        let changed = try BattleTestFixture.authored(db: fixture.db)
        func frame(_ source: BattleContent, ticks: Int) throws -> LevelReplayFrame {
            let enemy = try XCTUnwrap(source.enemies.first)
            let content = try BattleTestFixture.content(level: BattleTestFixture.level(enemy: enemy, slots: []), enemies: [enemy], base: source)
            let sim = try GameSimulation(recording: .preview, content: content, startingMoney: nil, heroesEnabled: false, seed: 11)
            sim.startNextWave()
            for _ in 0..<ticks { sim.step() }
            return LevelReplayFrame(sim.engine)
        }
        let first = try frame(original, ticks: 1), second = try frame(changed, ticks: 2)
        XCTAssertFalse(first.presentation.walkers.isEmpty)
        XCTAssertNotEqual(first.presentation.walkers.first?.morale.rules, second.presentation.walkers.first?.morale.rules)
        let builder = ReplayTimelineBuilder()
        try builder.append(first); try builder.append(second)
        let timeline = try builder.finish(events: [])
        XCTAssertTrue(timeline.tracks.contains { $0.path.hasSuffix("/morale/rules") })
        let reader = try ReplayTimelineReader(timeline)
        XCTAssertEqual(try bytes(reader.frame(at: first.tick)), try bytes(first))
        XCTAssertEqual(try bytes(reader.frame(at: second.tick)), try bytes(second))
    }

    @MainActor func testSpeedChangesDoNotChangeRecordingSizeOrVirtualMovement() throws {
        let fixture = try fixture(), dao = fixture.db.levelRunDao
        let base = try BattleTestFixture.authored(db: fixture.db), enemy = try XCTUnwrap(base.enemies.first)
        let content = try BattleTestFixture.content(level: BattleTestFixture.level(enemy: enemy, slots: []), enemies: [enemy], base: base)
        var rowCounts: [Int] = [], byteCounts: [Int] = []
        var reference: [CGPoint]?
        for factor in [1.0, 2.0, 1_000_000_000.0] {
            let sim = try GameSimulation(recording: .database(dao, .simulator), content: content, playSpeed: PlaySpeed(factor),
                startingMoney: nil, heroesEnabled: false, seed: 34)
            sim.startNextWave()
            for _ in 0..<300 { sim.step() }
            sim.finishRecording(status: .timeout)
            let id = try XCTUnwrap(sim.runID), stored = try rows(dao, id)
            rowCounts.append(stored.count); byteCounts.append(stored.reduce(0) { $0 + ($1.presentation?.count ?? 0) })
            let replay = try LevelReplayer(dao: dao, runID: id)
            var positions: [CGPoint] = []
            while try replay.advance() {
                if let walker = replay.frame?.presentation.walkers.first { positions.append(walker.position) }
            }
            if let reference { XCTAssertEqual(positions, reference) } else { reference = positions }
        }
        XCTAssertEqual(Set(rowCounts).count, 1)
        XCTAssertLessThan(try XCTUnwrap(byteCounts.max()) - XCTUnwrap(byteCounts.min()), 1024,
                          "Only the stored speed scalar should differ")
    }

    @MainActor func testLegacyFullFrameRecordingsStillReplay() throws {
        let fixture = try fixture(), dao = fixture.db.levelRunDao
        let sim = try GameSimulation(recording: .preview, content: BattleTestFixture.authored(db: fixture.db),
            startingMoney: nil, heroesEnabled: false, seed: 56)
        let setup = LevelReplaySetup(engine: sim.engine, seed: 56, heroesEnabled: false)
        let id = try dao.begin(levelID: setup.level.id, source: .simulator, playSpeed: setup.playSpeed,
                               setup: LevelRecordingCodec.encode(setup))
        sim.startNextWave()
        var expected: [Data] = []
        for tick in 0..<4 {
            if tick > 0 { sim.step() }
            let frame = LevelReplayFrame(sim.engine)
            expected.append(try bytes(frame))
            try dao.append(runID: id, after: Int64(tick - 1), actions: [PendingLevelAction(tick: Int64(tick),
                category: "presentation", name: "frame", payload: "{}", presentation: LevelRecordingCodec.encode(frame))])
        }
        try dao.finish(id: id, status: .timeout, resultJSON: nil)
        let replay = try LevelReplayer(dao: dao, runID: id)
        for frame in expected { XCTAssertTrue(try replay.advance()); XCTAssertEqual(try bytes(XCTUnwrap(replay.frame)), frame) }
        XCTAssertFalse(try replay.advance())
    }

    @MainActor func testCombatHeroesAndReinforcementsReplayExactlyAcrossBlocks() throws {
        let fixture = try fixture(), dao = fixture.db.levelRunDao
        let content = try BattleTestFixture.authored(db: fixture.db)
        let sim = try GameSimulation(recording: .database(dao, .simulator), content: content,
            startingMoney: 100_000, heroesEnabled: true, seed: 91)
        for (slot, offer) in sim.buildOffers.enumerated() {
            XCTAssertEqual(sim.perform(.build(slot: slot, kind: offer.kind)), .ok)
            for level in 2...4 {
                if let next = sim.upgradeOffers(at: slot).first(where: { $0.nextLevel == level }) {
                    XCTAssertEqual(sim.perform(.upgrade(slot: slot, branch: next.branch)), .ok)
                }
            }
        }
        sim.startNextWave()
        var expected = [try bytes(LevelReplayFrame(sim.engine))]
        for index in 0..<320 {
            sim.step()
            if index == 5, let enemy = sim.enemies.first {
                XCTAssertEqual(sim.perform(.reinforcements(point: enemy.position)), .ok)
            }
            // step() publishes alpha=0 for live interpolation; recordings use
            // the canonical end-of-tick pose, independent of rendering speed.
            sim.engine.publishMilitia(alpha: 1)
            expected.append(try bytes(LevelReplayFrame(sim.engine)))
        }
        sim.finishRecording(status: .timeout)
        let id = try XCTUnwrap(sim.runID)
        let replay = try LevelReplayer(dao: dao, runID: id)
        for (tick, frame) in expected.enumerated() {
            XCTAssertTrue(try replay.advance())
            let actual = try bytes(XCTUnwrap(replay.frame))
            if actual != frame {
                let a = Array(actual), b = Array(frame)
                let offset = zip(a, b).enumerated().first { $0.element.0 != $0.element.1 }?.offset ?? min(a.count, b.count)
                let start = max(0, offset - 80)
                XCTFail("Tick \(tick), expected \(String(decoding: b[start..<min(b.count, offset + 180)], as: UTF8.self)); actual \(String(decoding: a[start..<min(a.count, offset + 180)], as: UTF8.self))")
                return
            }
        }
        XCTAssertFalse(try replay.advance())
        XCTAssertGreaterThan(try rows(dao, id).filter { $0.presentation != nil }.count, 1)
    }

    @MainActor func testManySameTickInputsRemainOrderedWithoutRepeatedSnapshots() throws {
        let fixture = try fixture(), dao = fixture.db.levelRunDao
        let sim = try GameSimulation(recording: .database(dao, .simulator), content: BattleTestFixture.authored(db: fixture.db),
            startingMoney: 1, heroesEnabled: false, seed: 92)
        for _ in 0..<600 { XCTAssertEqual(sim.perform(.build(slot: 0, kind: .ranged)), .needGold) }
        sim.step(); sim.finishRecording(status: .timeout)
        let id = try XCTUnwrap(sim.runID), stored = try rows(dao, id)
        XCTAssertLessThan(stored.count, 5)
        let replay = try LevelReplayer(dao: dao, runID: id)
        XCTAssertTrue(try replay.advance())
        let attempts = replay.actions.filter { $0.category == "input" || $0.name == "inputResult" }
        XCTAssertEqual(attempts.count, 1200)
        for (index, action) in attempts.enumerated() {
            XCTAssertEqual(action.name, index.isMultiple(of: 2) ? "command" : "inputResult")
        }
        XCTAssertEqual(replay.frame?.money, 1)
        XCTAssertTrue(try replay.advance())
        XCTAssertFalse(try replay.advance())
    }

    @MainActor func testMissingAndOverlappingSegmentsFailRatherThanInventingValues() throws {
        let fixture = try fixture()
        let sim = try GameSimulation(recording: .preview, content: BattleTestFixture.authored(db: fixture.db),
            startingMoney: nil, heroesEnabled: false, seed: 78)
        let builder = ReplayTimelineBuilder()
        try builder.append(LevelReplayFrame(sim.engine))
        sim.step(); try builder.append(LevelReplayFrame(sim.engine))
        let original = try builder.finish(events: [])
        let missing = LevelReplayTimeline(version: 1, firstTick: 0, lastTick: 1,
            tracks: original.tracks.filter { $0.path != "/money" }, events: [])
        let reader = try ReplayTimelineReader(missing)
        XCTAssertThrowsError(try reader.frame(at: 0))
        let track = try XCTUnwrap(original.tracks.first)
        let overlap = ReplayTimelineTrack(path: track.path, segments: track.segments + track.segments)
        XCTAssertThrowsError(try ReplayTimelineReader(LevelReplayTimeline(version: 1, firstTick: 0, lastTick: 1,
            tracks: [overlap], events: [])))
        let outOfOrder = [ReplayTimelineEvent(tick: 1, category: "input", name: "one", payload: "{}"),
                          ReplayTimelineEvent(tick: 0, category: "input", name: "two", payload: "{}")]
        XCTAssertThrowsError(try ReplayTimelineReader(LevelReplayTimeline(version: 1, firstTick: 0, lastTick: 1,
            tracks: original.tracks, events: outOfOrder)))
    }
    private final class TransactionCounter { var begins = 0 }

    @MainActor func testCompleteBlocksShareTransactionsAndFinishDrainsTheBatch() throws {
        let fixture = try fixture(), dao = fixture.db.levelRunDao
        let counter = TransactionCounter()
        sqlite3_trace_v2(fixture.connection, UInt32(SQLITE_TRACE_STMT), { _, context, statement, _ in
            guard let context, let statement, let sql = sqlite3_sql(OpaquePointer(statement)) else { return 0 }
            if String(cString: sql) == "BEGIN IMMEDIATE" {
                Unmanaged<TransactionCounter>.fromOpaque(context).takeUnretainedValue().begins += 1
            }
            return 0
        }, Unmanaged.passUnretained(counter).toOpaque())
        defer { sqlite3_trace_v2(fixture.connection, 0, nil, nil) }
        let base = try BattleTestFixture.authored(db: fixture.db), enemy = try XCTUnwrap(base.enemies.first)
        var level = BattleTestFixture.level(enemy: enemy, slots: [])
        level.paths = [Path(points: [Point(0, 0), Point(4000, 0)])]
        let content = try BattleTestFixture.content(level: level, enemies: [enemy], base: base)
        let sim = try GameSimulation(recording: .database(dao, .simulator), content: content,
            startingMoney: nil, heroesEnabled: false, seed: 93)
        sim.startNextWave()
        for _ in 0..<900 { sim.step() }
        sim.finishRecording(status: .timeout)
        let id = try XCTUnwrap(sim.runID), saved = try rows(dao, id)
        XCTAssertEqual(saved.count, 5, "Start row plus four complete timeline blocks")
        XCTAssertEqual(counter.begins, 2, "Start transaction plus one four-block batch")
        let replay = try LevelReplayer(dao: dao, runID: id)
        var count = 0
        while try replay.advance() { count += 1 }
        XCTAssertEqual(count, 901)
        XCTAssertEqual(replay.actions.last?.name, "timeout")
    }

    @MainActor func testCachedTowerContentChangesWithinARecordingBlock() throws {
        let fixture = try fixture(), dao = fixture.db.levelRunDao
        let sim = try GameSimulation(recording: .database(dao, .simulator), content: BattleTestFixture.authored(db: fixture.db),
            startingMoney: 100_000, heroesEnabled: false, seed: 94)
        XCTAssertEqual(sim.perform(.build(slot: 0, kind: .ranged)), .ok)
        sim.startNextWave()
        var expected = [try bytes(LevelReplayFrame(sim.engine))]
        for index in 0..<80 {
            sim.step()
            if index == 40 {
                let offer = try XCTUnwrap(sim.upgradeOffers(at: 0).first)
                XCTAssertEqual(sim.perform(.upgrade(slot: 0, branch: offer.branch)), .ok)
            }
            expected.append(try bytes(LevelReplayFrame(sim.engine)))
        }
        sim.finishRecording(status: .timeout)
        let replay = try LevelReplayer(dao: dao, runID: XCTUnwrap(sim.runID))
        for frame in expected {
            XCTAssertTrue(try replay.advance())
            XCTAssertEqual(try bytes(XCTUnwrap(replay.frame)), frame)
        }
        XCTAssertFalse(try replay.advance())
    }

}
