import XCTest
import SQLite3
@testable import LevelEditorFormats

final class BattleEventRecordingTests: XCTestCase {
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
            let page = try dao.actions(runID: id, after: result.last?.sequence ?? -1, limit: 16)
            if page.isEmpty { return result }
            result += page
        }
    }
    private func compare(_ expected: LevelReplayFrame, _ actual: LevelReplayFrame) throws {
        let a = try bytes(expected), b = try bytes(actual)
        guard a != b else { return }
        let floatFields: Set<String> = ["position", "hp", "pathDistance", "heading", "remainingDistance",
            "value", "impactAge", "valueBeforeImpact", "flinchDirection",
            "previousWalkerDistances", "previousProjectilePositions"]
        func check(_ lhs: Any, _ rhs: Any, path: [String]) throws {
            if let lhs = lhs as? [String: Any], let rhs = rhs as? [String: Any], Set(lhs.keys) == Set(rhs.keys) {
                for key in lhs.keys.sorted() { try check(lhs[key]!, rhs[key]!, path: path + [key]) }
                return
            }
            if let lhs = lhs as? [Any], let rhs = rhs as? [Any], lhs.count == rhs.count {
                for index in lhs.indices { try check(lhs[index], rhs[index], path: path + [String(index)]) }
                return
            }
            if let lhs = lhs as? NSNumber, let rhs = rhs as? NSNumber {
                if lhs == rhs { return }
                if !floatFields.isDisjoint(with: path), Double(Float(lhs.doubleValue)) == rhs.doubleValue { return }
            } else if let lhs = lhs as? String, let rhs = rhs as? String {
                if lhs == rhs { return }
                // Rounded movement can cross a walking-frame boundary one
                // tick earlier. The unit and facing must still be identical.
                if path.first == "militia", path.last == "assetName" {
                    let a = lhs.split(separator: "_"), b = rhs.split(separator: "_")
                    if a.dropLast() == b.dropLast(), let x = a.last.flatMap({ Int($0) }), let y = b.last.flatMap({ Int($0) }) {
                        let distance = abs(x - y)
                        if min(distance, MeleeWalkCycle.frameCount - distance) <= 1 { return }
                    }
                }
            }
            else if lhs is NSNull, rhs is NSNull { return }
            let message = "Tick \(actual.tick), \(path.joined(separator: ".")): expected \(lhs); actual \(rhs)"
            XCTFail(message)
            throw DbError.Db(message: message)
        }
        // Only the documented state fields may round to Float. Gameplay results,
        // action strings, authored tuning, integer values and clocks stay exact.
        try check(JSONSerialization.jsonObject(with: a), JSONSerialization.jsonObject(with: b), path: [])
    }

    @MainActor func testEventOnlyBattleMatchesRecordedCombatAndPlaybackAcrossBlocks() throws {
        let fixture = try fixture(), dao = fixture.db.levelRunDao
        let content = try BattleTestFixture.authored(db: fixture.db)
        let eventRun = try GameSimulation(recording: .database(dao, .simulator), content: content,
            startingMoney: 100_000, heroesEnabled: true, seed: 91)
        let reference = try GameSimulation(recording: .database(dao, .player), content: content,
            startingMoney: 100_000, heroesEnabled: true, seed: 91)
        for sim in [eventRun, reference] {
            for (slot, offer) in sim.buildOffers.enumerated() {
                XCTAssertEqual(sim.perform(.build(slot: slot, kind: offer.kind)), .ok)
                for level in 2...4 {
                    if let next = sim.upgradeOffers(at: slot).first(where: { $0.nextLevel == level }) {
                        XCTAssertEqual(sim.perform(.upgrade(slot: slot, branch: next.branch)), .ok)
                    }
                }
            }
            sim.startNextWave()
        }
        for index in 0..<620 {
            eventRun.step(); reference.step()
            if index == 5, let enemy = eventRun.enemies.first {
                for sim in [eventRun, reference] {
                    XCTAssertEqual(sim.perform(.reinforcements(point: enemy.position)), .ok)
                }
            }
            if index == 280 {
                for sim in [eventRun, reference] { sim.pause(); sim.resume(); sim.setPlaySpeed(try PlaySpeed(2)) }
            }
            XCTAssertEqual(eventRun.result(), reference.result())
        }
        XCTAssertTrue(eventRun.engine.militia.isEmpty, "GA must not publish soldier sprites")
        XCTAssertTrue(eventRun.engine.heroes.isEmpty, "GA must not publish hero sprites")
        XCTAssertTrue(eventRun.engine.militiaPoses.isEmpty, "GA must not calculate animation poses")
        XCTAssertTrue(eventRun.engine.heroPoses.values.allSatisfy { $0.walkPhase == 0 })
        for sim in [eventRun, reference] { sim.finishRecording(status: .timeout) }
        let id = try XCTUnwrap(eventRun.runID), stored = try rows(dao, id)
        XCTAssertTrue(stored.allSatisfy { $0.category != "presentation" && $0.presentation == nil })
        XCTAssertGreaterThan(stored.filter { $0.name == BattleEventBlock.rowName }.count, 1)
        for row in stored where row.name == BattleEventBlock.rowName {
            XCTAssertEqual(row.payloadJSON, "{}", "No base64 JSON on the recording path")
            XCTAssertFalse(try XCTUnwrap(row.eventData).isEmpty)
        }
        let actual = try LevelReplayer(dao: dao, runID: id)
        let expected = try LevelReplayer(dao: dao, runID: XCTUnwrap(reference.runID))
        let writes = sqlite3_total_changes(fixture.connection)
        while try expected.advance() {
            XCTAssertTrue(try actual.advance())
            try compare(XCTUnwrap(expected.frame), XCTUnwrap(actual.frame))
            XCTAssertEqual(actual.actions.map(\.tick), expected.actions.map(\.tick))
            XCTAssertEqual(actual.actions.map(\.name), expected.actions.map(\.name))
            XCTAssertEqual(actual.actions.map(\.payloadJSON), expected.actions.map(\.payloadJSON))
        }
        XCTAssertFalse(try actual.advance())
        XCTAssertEqual(sqlite3_total_changes(fixture.connection), writes, "Playback is read-only")

        // All historical JSON formats must work through the movie reader.
        for encoding in [BattleEventBlock.rowName, BattleEventBlock.preciseRowName, BattleEventBlock.packedLegacyRowName, BattleEventBlock.legacyRowName] {
            for row in stored where row.name == BattleEventBlock.rowName {
                let block = try BattleEventBlock.decode(row, resolve: dao.loadContent)
                let data: Data
                switch encoding {
                case BattleEventBlock.rowName: data = try block.compressedData()
                case BattleEventBlock.preciseRowName: data = try LevelRecordingCodec.encode(BattleEventPackedStorage(block))
                case BattleEventBlock.packedLegacyRowName: data = try LevelRecordingCodec.encode(BattleEventStorage(block))
                default: data = try LevelRecordingCodec.encode(block)
                }
                let legacy = try LevelRecordingCodec.json(BattleEventBlock.Envelope(data: data))
                    .replacingOccurrences(of: "'", with: "''")
                XCTAssertEqual(sqlite3_exec(fixture.connection,
                    "UPDATE level_action SET name='\(encoding)',payload_json='\(legacy)',event_data=NULL WHERE run_id='\(id)' AND sequence=\(row.sequence)",
                    nil, nil, nil), SQLITE_OK)
            }
            let legacy = try LevelReplayer(dao: dao, runID: id)
            let legacyReference = try LevelReplayer(dao: dao, runID: XCTUnwrap(reference.runID))
            while try legacyReference.advance() {
                XCTAssertTrue(try legacy.advance())
                try compare(XCTUnwrap(legacyReference.frame), XCTUnwrap(legacy.frame))
                XCTAssertEqual(legacy.actions.map(\.payloadJSON), legacyReference.actions.map(\.payloadJSON))
            }
            XCTAssertFalse(try legacy.advance())
        }
    }

    @MainActor func testMovementEventsReplayAcrossBendsAndIgnoreLaterContentEdits() throws {
        let fixture = try fixture(), dao = fixture.db.levelRunDao
        let base = try BattleTestFixture.authored(db: fixture.db), enemy = try XCTUnwrap(base.enemies.first)
        var level = BattleTestFixture.level(enemy: enemy, slots: [])
        level.paths = [Path(points: [Point(0, 0), Point(100, 0), Point(100, 200), Point(4000, 200)])]
        let content = try BattleTestFixture.content(level: level, enemies: [enemy], base: base)
        var ids: [UUID] = []
        for source in [LevelRunSource.simulator, .player] {
            let sim = try GameSimulation(recording: .database(dao, source), content: content,
                startingMoney: nil, heroesEnabled: false, seed: 12)
            sim.startNextWave()
            for _ in 0..<600 { sim.step() }
            sim.finishRecording(status: .timeout); ids.append(try XCTUnwrap(sim.runID))
        }
        let stored = try rows(dao, ids[0])
        let blocks = try stored.filter { $0.name == BattleEventBlock.rowName }.map { try BattleEventBlock.decode($0, resolve: dao.loadContent) }
        XCTAssertTrue(blocks.flatMap(\.enemyNumbers.segments).contains { $0.count > 1 && $0.increments != nil })
        XCTAssertEqual(sqlite3_exec(fixture.connection,
            "UPDATE enemy_type SET enemy_type_name='Changed after recording: ' || enemy_type_name", nil, nil, nil), SQLITE_OK)
        let actual = try LevelReplayer(dao: dao, runID: ids[0]), expected = try LevelReplayer(dao: dao, runID: ids[1])
        while try expected.advance() {
            XCTAssertTrue(try actual.advance())
            try compare(XCTUnwrap(expected.frame), XCTUnwrap(actual.frame))
        }
        XCTAssertFalse(try actual.advance())
    }

    @MainActor func testMissingEventStateAndTruncatedLogsFail() throws {
        let fixture = try fixture(), dao = fixture.db.levelRunDao
        let sim = try GameSimulation(recording: .database(dao, .simulator), content: BattleTestFixture.authored(db: fixture.db),
            startingMoney: nil, heroesEnabled: false, seed: 12)
        sim.startNextWave(); sim.step(); sim.finishRecording(status: .timeout)
        let id = try XCTUnwrap(sim.runID), stored = try rows(dao, id)
        let row = try XCTUnwrap(stored.first { $0.name == BattleEventBlock.rowName })
        var block = try BattleEventBlock.decode(row, resolve: dao.loadContent)
        block.enemyNumbers = BattleEventNumbers()
        let hex = try block.compressedData().map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(sqlite3_exec(fixture.connection,
            "UPDATE level_action SET name='\(BattleEventBlock.rowName)',event_data=X'\(hex)' WHERE run_id='\(id)' AND sequence=\(row.sequence)", nil, nil, nil), SQLITE_OK)
        XCTAssertThrowsError(try LevelReplayer(dao: dao, runID: id).advance())
        XCTAssertEqual(sqlite3_exec(fixture.connection,
            "DELETE FROM level_action WHERE run_id='\(id)' AND sequence=\(row.sequence)", nil, nil, nil), SQLITE_OK)
        XCTAssertThrowsError(try LevelReplayer(dao: dao, runID: id).advance())
    }

    @MainActor func testHistoricalSchemaPlaysAllJSONFormatsWithoutWrites() throws {
        for encoding in [BattleEventBlock.rowName, BattleEventBlock.preciseRowName, BattleEventBlock.packedLegacyRowName, BattleEventBlock.legacyRowName] {
            let fixture = try fixture(), dao = fixture.db.levelRunDao
            let sim = try GameSimulation(recording: .database(dao, .simulator), content: BattleTestFixture.authored(db: fixture.db),
                startingMoney: nil, heroesEnabled: false, seed: 12)
            sim.startNextWave()
            for _ in 0..<270 { sim.step() }
            sim.finishRecording(status: .timeout)
            let id = try XCTUnwrap(sim.runID), reference = try LevelReplayer(dao: dao, runID: id)
            var frames: [Data] = [], actions: [[String]] = []
            while try reference.advance() {
                frames.append(try bytes(XCTUnwrap(reference.frame)))
                actions.append(reference.actions.map(\.payloadJSON))
            }
            for row in try rows(dao, id) where row.name == BattleEventBlock.rowName {
                let block = try BattleEventBlock.decode(row, resolve: dao.loadContent), data: Data
                switch encoding {
                case BattleEventBlock.rowName: data = try block.compressedData()
                case BattleEventBlock.preciseRowName: data = try LevelRecordingCodec.encode(BattleEventPackedStorage(block))
                case BattleEventBlock.packedLegacyRowName: data = try LevelRecordingCodec.encode(BattleEventStorage(block))
                default: data = try LevelRecordingCodec.encode(block)
                }
                let json = try LevelRecordingCodec.json(BattleEventBlock.Envelope(data: data)).replacingOccurrences(of: "'", with: "''")
                XCTAssertEqual(sqlite3_exec(fixture.connection,
                    "UPDATE level_action SET name='\(encoding)',payload_json='\(json)',event_data=NULL WHERE run_id='\(id)' AND sequence=\(row.sequence)",
                    nil, nil, nil), SQLITE_OK)
            }
            // Reproduce the historical table itself, not just legacy rows in
            // today's schema. query_only also makes a hidden migration fail.
            XCTAssertEqual(sqlite3_exec(fixture.connection, """
                ALTER TABLE level_action RENAME TO new_level_action;
                CREATE TABLE level_action (
                    run_id TEXT NOT NULL REFERENCES level_run(id),
                    sequence INTEGER NOT NULL CHECK(sequence >= 0),
                    tick INTEGER NOT NULL CHECK(tick >= 0),
                    category TEXT NOT NULL CHECK(category IN ('input','event','presentation','lifecycle')),
                    name TEXT NOT NULL CHECK(length(name) > 0),
                    payload_json TEXT NOT NULL CHECK(json_valid(payload_json)),
                    presentation BLOB,
                    CHECK((category = 'presentation') = (presentation IS NOT NULL)),
                    PRIMARY KEY(run_id,sequence)
                );
                INSERT INTO level_action SELECT run_id,sequence,tick,category,name,payload_json,presentation FROM new_level_action;
                DROP TABLE new_level_action;
                CREATE INDEX level_action_tick ON level_action(run_id,tick,sequence);
                PRAGMA query_only=ON;
                """, nil, nil, nil), SQLITE_OK)
            let legacyDAO = LevelRunDAO(conn: fixture.connection), writes = sqlite3_total_changes(fixture.connection)
            let legacy = try LevelReplayer(dao: legacyDAO, runID: id)
            var tick = 0
            while try legacy.advance() {
                XCTAssertEqual(try bytes(XCTUnwrap(legacy.frame)), frames[tick], encoding)
                XCTAssertEqual(legacy.actions.map(\.payloadJSON), actions[tick], encoding)
                tick += 1
            }
            XCTAssertEqual(tick, frames.count)
            XCTAssertEqual(sqlite3_total_changes(fixture.connection), writes)
            XCTAssertThrowsError(try legacyDAO.begin(levelID: legacy.run.levelID, source: .simulator,
                playSpeed: legacy.run.playSpeed, setup: Data([1]))) { error in
                XCTAssertTrue(String(describing: error).contains("level_action.event_data is missing"))
            }
        }
    }

    @MainActor func testMissingCorruptAndConflictingBlobPayloadsFail() throws {
        let fixture = try fixture(), dao = fixture.db.levelRunDao
        let sim = try GameSimulation(recording: .database(dao, .simulator), content: BattleTestFixture.authored(db: fixture.db),
            startingMoney: nil, heroesEnabled: false, seed: 12)
        sim.step(); sim.finishRecording(status: .timeout)
        let id = try XCTUnwrap(sim.runID), row = try XCTUnwrap(rows(dao, id).first { $0.eventData != nil })
        let whereRow = "WHERE run_id='\(id)' AND sequence=\(row.sequence)"
        // SQLite rejects values that could be mistaken for another transport.
        for assignment in ["event_data='not a blob'", "event_data=X''", "payload_json='{\"data\":\"AA==\"}'", "category='input'"] {
            XCTAssertEqual(sqlite3_exec(fixture.connection, "UPDATE level_action SET \(assignment) \(whereRow)", nil, nil, nil), SQLITE_CONSTRAINT)
        }
        // A valid BLOB's contents still have to decode, and NULL cannot hide a
        // lost BLOB behind its empty JSON placeholder.
        for assignment in ["event_data=X'00'", "event_data=NULL"] {
            XCTAssertEqual(sqlite3_exec(fixture.connection, "UPDATE level_action SET \(assignment) \(whereRow)", nil, nil, nil), SQLITE_OK)
            XCTAssertThrowsError(try LevelReplayer(dao: dao, runID: id).advance())
        }
        let conflicting = LevelActionRecord(runID: row.runID, sequence: row.sequence, tick: row.tick,
            category: row.category, name: row.name, payloadJSON: "{\"data\":\"AA==\"}", presentation: nil, eventData: row.eventData)
        XCTAssertThrowsError(try BattleEventBlock.decode(conflicting))
    }

    func testDAOStoresBlobBytesExactlyAndRollsBackInvalidBatch() throws {
        let fixture = try fixture(), dao = fixture.db.levelRunDao
        let id = try dao.begin(levelID: UUID(), source: .simulator, playSpeed: PlaySpeed(1), setup: Data([1]))
        let data = Data((0...255).map(UInt8.init))
        let action = PendingLevelAction(tick: 0, category: "event", name: BattleEventBlock.rowName, payload: "{}", eventData: data)
        try dao.append(runID: id, after: -1, actions: [action])
        XCTAssertEqual(try XCTUnwrap(dao.actions(runID: id).first).eventData, data)
        let invalid = PendingLevelAction(tick: 1, category: "input", name: "invalid", payload: "{}", eventData: data)
        XCTAssertThrowsError(try dao.append(runID: id, after: 0, actions: [action, invalid]))
        XCTAssertEqual(try dao.actions(runID: id).count, 1)
        XCTAssertEqual(try dao.get(id: id).lastSequence, 0)
    }

    func testNumericEventsPreserveExactRoundingAndInfinity() throws {
        var numbers = BattleEventNumbers(), distance = 0.0
        var expected: [Double] = []
        for tick in 0..<200 {
            expected.append(distance)
            numbers.append([distance, .infinity], at: Int64(tick)); distance += 0.3
        }
        XCTAssertEqual(numbers.segments.count, 1)
        let restored = try LevelRecordingCodec.decode(BattleEventNumbers.self, from: LevelRecordingCodec.encode(numbers))
        for tick in 0..<200 {
            let values = try restored.values(at: Int64(tick))
            XCTAssertEqual(values[0].bitPattern, expected[tick].bitPattern)
            XCTAssertEqual(values[1], .infinity)
        }
        XCTAssertThrowsError(try restored.values(at: 200))
    }

    func testPackedNumbersPreserveBitsAndRejectCorruptLengthsFlagsAndTrailingBytes() throws {
        var numbers = BattleEventNumbers()
        let expected: [[Double]] = [[-0.0, .infinity, .leastNonzeroMagnitude],
                                    [0.0, -.infinity, .greatestFiniteMagnitude], [], [0.3]]
        for (tick, values) in expected.enumerated() { numbers.append(values, at: Int64(tick)) }
        let packed = try numbers.packed(), decoded = try BattleEventNumbers.unpack(packed)
        try decoded.validate(first: 0, last: 3)
        for (tick, values) in expected.enumerated() {
            XCTAssertEqual(try decoded.values(at: Int64(tick)).map(\.bitPattern), values.map(\.bitPattern))
        }
        for end in 0..<packed.count { XCTAssertThrowsError(try BattleEventNumbers.unpack(packed.prefix(end))) }
        var trailing = packed; trailing.append(0)
        XCTAssertThrowsError(try BattleEventNumbers.unpack(trailing))
        var invalidCount = packed
        invalidCount.replaceSubrange(0..<4, with: [255, 255, 255, 255])
        XCTAssertThrowsError(try BattleEventNumbers.unpack(invalidCount))
        var invalidFlag = packed
        invalidFlag[4 + 8 + 4 + 4 + expected[0].count * 8] = 2
        XCTAssertThrowsError(try BattleEventNumbers.unpack(invalidFlag))
    }

    func testFloatStateTracksReproduceEveryRoundedObservationWithoutIncrementDrift() throws {
        var numbers = BattleEventNumbers(), original = 0.0
        var expected: [[Double]] = []
        for tick in 0..<256 {
            // Exercise movement, decreasing health, morale, infinity and signed
            // zero, including Float exponent boundaries and changing entities.
            let values = tick == 127 ? [] : [original, 91.123456789 - Double(tick) * 0.19,
                sin(Double(tick) / 13) * 100, .infinity, tick < 128 ? -0.0 : 0.0]
            expected.append(values.map { Double(Float($0)) })
            try numbers.appendFloat32(values, at: Int64(tick))
            original += 0.3
        }
        let packed = try numbers.packed(float32: true)
        let decoded = try BattleEventNumbers.unpack(packed, float32: true)
        try decoded.validate(first: 0, last: 255)
        for tick in 0..<256 {
            XCTAssertEqual(try decoded.values(at: Int64(tick)).map(\.bitPattern), expected[tick].map(\.bitPattern))
        }
        let scalarCount = numbers.segments.reduce(0) { $0 + $1.values.count + ($1.increments?.count ?? 0) }
        XCTAssertEqual(try numbers.packed().count - packed.count, scalarCount * 4)
        XCTAssertThrowsError(try numbers.appendFloat32([Double.greatestFiniteMagnitude], at: 256))
        XCTAssertThrowsError(try numbers.appendFloat32([.nan], at: 256))
        var precise = BattleEventNumbers()
        precise.append([0.123456789123], at: 0)
        XCTAssertThrowsError(try precise.packed(float32: true), "Packing must not silently round a legacy segment's start/increment")
    }

    func testFloatStateTracksRejectTruncatedAndMalformedPayloads() throws {
        var numbers = BattleEventNumbers()
        try numbers.appendFloat32([1, 2, 3], at: 0)
        try numbers.appendFloat32([2, 3, 4], at: 1)
        let packed = try numbers.packed(float32: true)
        for end in 0..<packed.count {
            XCTAssertThrowsError(try BattleEventNumbers.unpack(packed.prefix(end), float32: true))
        }
        var trailing = packed; trailing.append(0)
        XCTAssertThrowsError(try BattleEventNumbers.unpack(trailing, float32: true))
        var flag = packed; flag[4 + 8 + 4 + 4 + 3 * 4] = 2
        XCTAssertThrowsError(try BattleEventNumbers.unpack(flag, float32: true))
        var width = packed; width.replaceSubrange(16..<20, with: [255, 255, 255, 255])
        XCTAssertThrowsError(try BattleEventNumbers.unpack(width, float32: true))
    }

    @MainActor func testStorageSeparatesRotatingAimFromDefinitionsAndRejectsMissingReferences() throws {
        let fixture = try fixture()
        let content = try BattleTestFixture.authored(db: fixture.db)
        let sim = try GameSimulation(recording: .preview, content: content, startingMoney: nil, heroesEnabled: false, seed: 91)
        var tower = PlacedTower(combatRules: sim.engine.combatRules, slotIndex: 0, kind: .areaOfEffect, position: .zero)
        tower.preparedVolley = PreparedMetaVolley(effects: sim.engine.metaUpgrades)
        tower.demolitionCharge = DemolitionCharge(preparationSeconds: 10)
        tower.demolitionCharge?.place(at: CGPoint(x: 1, y: 2))
        XCTAssertTrue(tower.demolitionCharge!.detonate())
        var block = BattleEventBlock(firstTick: 0), expected: [PlacedTower] = []
        for tick in 0..<120 {
            tower.artilleryAim.track(from: .zero, to: CGPoint(x: 100, y: 100), radiansPerSecond: 0.1, deltaTime: SimClock.dt)
            tower.preparedVolley?.advance(seconds: SimClock.dt, hasTarget: false)
            tower.demolitionCharge?.advance(seconds: SimClock.dt)
            expected.append(tower)
            sim.engine.placedTowers = [tower]
            try block.append(BattleEventState(sim.engine))
            if tick < 119 { sim.engine.timer.advanceTick() }
        }
        let restored = try BattleEventBlock.decode(block.json())
        for tick in 0..<120 {
            let actual = try XCTUnwrap(restored.towers.value(at: Int64(tick)).first)
            XCTAssertEqual(actual, expected[tick])
            XCTAssertEqual(actual.artilleryAim.heading.bitPattern, expected[tick].artilleryAim.heading.bitPattern)
            XCTAssertEqual(actual.demolitionCharge?.remainingSeconds.bitPattern, expected[tick].demolitionCharge?.remainingSeconds.bitPattern)
        }
        let encoder = PropertyListEncoder(); encoder.outputFormat = .binary
        let data = try encoder.encode(BattleEventStorage(block))
        var document = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        var towers = try XCTUnwrap(document["towers"] as? [String: Any])
        let definitions = try XCTUnwrap(towers["definitions"] as? [String: Any])
        XCTAssertEqual((definitions["values"] as? [Any])?.count, 1, "Only the initial tower definition is stored while its aim and charge change")
        func decode(_ document: [String: Any]) throws -> BattleEventBlock {
            let data = try PropertyListSerialization.data(fromPropertyList: document, format: .binary, options: 0)
            return try PropertyListDecoder().decode(BattleEventStorage.self, from: data).unpack()
        }
        towers["definitions"] = ["values": [Any]()]
        document["towers"] = towers
        XCTAssertThrowsError(try decode(document))
        document["version"] = 99
        XCTAssertThrowsError(try decode(document))
    }

    func testPackedActionsPreserveTextAndRejectCorruption() throws {
        let actions = [ReplayTimelineEvent(tick: 0, category: "", name: "é⚑\u{0}", payload: "\"line\n\\end\""),
                       ReplayTimelineEvent(tick: 42, category: "event", name: "hit", payload: "{\"hp\":\"-0.0\"}")]
        let packed = try BattleEventActions.pack(actions)
        let restored = try BattleEventActions.unpack(packed)
        XCTAssertEqual(restored.map(\.tick), actions.map(\.tick))
        XCTAssertEqual(restored.map(\.category), actions.map(\.category))
        XCTAssertEqual(restored.map(\.name), actions.map(\.name))
        XCTAssertEqual(restored.map(\.payload), actions.map(\.payload))
        XCTAssertTrue(try BattleEventActions.unpack(BattleEventActions.pack([])).isEmpty)
        for end in 0..<packed.count { XCTAssertThrowsError(try BattleEventActions.unpack(packed.prefix(end))) }
        var trailing = packed; trailing.append(0)
        XCTAssertThrowsError(try BattleEventActions.unpack(trailing))
        var badCount = packed; badCount.replaceSubrange(0..<4, with: [255, 255, 255, 255])
        XCTAssertThrowsError(try BattleEventActions.unpack(badCount))
        var badUTF8 = packed; badUTF8[20] = 255
        XCTAssertThrowsError(try BattleEventActions.unpack(badUTF8))
    }

    @MainActor func testCaptureCacheTracksEveryTowerConfigurationAndAuthoredRevision() throws {
        let source = try BattleTestFixture.authored()
        let sim = try GameSimulation(recording: .preview, content: source,
            startingMoney: nil, heroesEnabled: false, seed: 91)
        let engine = sim.engine, cache = BattleEventCaptureCache()
        for family in source.arsenal.towers {
            for tier in family.tiers {
                var tower = PlacedTower(combatRules: engine.combatRules, slotIndex: 0,
                    kind: family.kind, position: .zero, level: tier.level, branch: tier.branch)
                for path in tier.tuning.upgradePaths {
                    var money = 100_000
                    for _ in path.ranks {
                        engine.placedTowers = [tower]
                        let before = cache.tuning(engine)
                        XCTAssertEqual(tower.upgrades.purchase(pathID: path.id, from: tier.tuning, money: &money), .ok)
                        engine.placedTowers = [tower]
                        let after = cache.tuning(engine)
                        XCTAssertFalse(before === after)
                        XCTAssertEqual(after.values[0], engine.towerLevel(for: tower))
                    }
                }
                engine.placedTowers = [tower]
                let snapshot = cache.tuning(engine)
                XCTAssertTrue(snapshot === cache.tuning(engine))
                XCTAssertEqual(snapshot.values[0], engine.towerLevel(for: tower))
                XCTAssertEqual(try PropertyListDecoder().decode([Int: TowerLevel].self, from: snapshot.data()), snapshot.values)
            }
        }
        engine.placedTowers = []
        XCTAssertTrue(cache.tuning(engine).values.isEmpty)
        engine.placedTowers = [PlacedTower(combatRules: engine.combatRules, slotIndex: 0, kind: .ranged, position: .zero)]
        engine.pricedTowerLevels[.ranged]?[1]?[1]?.turnRateDegrees = 0.0
        let before = cache.tuning(engine)
        _ = try before.data()
        engine.pricedTowerLevels[.ranged]?[1]?[1]?.turnRateDegrees = -0.0
        let after = cache.tuning(engine)
        XCTAssertFalse(before === after, "Even equal-valued authored edits must invalidate encoded metadata")
        XCTAssertEqual(after.values[0]?.turnRateDegrees.bitPattern, (-0.0 as Double).bitPattern)
        let restored = try PropertyListDecoder().decode([Int: TowerLevel].self, from: after.data())
        var block = BattleEventBlock(firstTick: engine.timer.tick)
        try block.append(BattleEventState(engine, cache: cache))
        let legacy = try LevelRecordingCodec.decode(BattleEventStorage.self,
            from: LevelRecordingCodec.encode(BattleEventStorage(block))).unpack()
        // Metadata keeps the existing property-list representation; the cache
        // must invalidate even for a signed-zero edit that Equatable coalesces.
        XCTAssertEqual(restored[0]?.turnRateDegrees.bitPattern,
            try legacy.tuning.value(at: engine.timer.tick)[0]?.turnRateDegrees.bitPattern)

        let other = try GameSimulation(recording: .preview, content: source.selectingMetaUpgrades([]),
            startingMoney: nil, heroesEnabled: false, seed: 91)
        other.engine.placedTowers = engine.placedTowers
        let otherSnapshot = cache.tuning(other.engine)
        XCTAssertFalse(otherSnapshot === after)
        XCTAssertEqual(otherSnapshot.values[0], other.engine.towerLevel(for: other.engine.placedTowers[0]))
    }

    @MainActor func testV3BlocksAreIndependentAndEditedTuningCannotReuseStaleBytes() throws {
        let fixture = try fixture()
        let sim = try GameSimulation(recording: .preview, content: BattleTestFixture.authored(db: fixture.db),
            startingMoney: nil, heroesEnabled: false, seed: 91)
        let cache = BattleEventCaptureCache()
        sim.engine.placedTowers = [PlacedTower(combatRules: sim.engine.combatRules, slotIndex: 0, kind: .ranged, position: .zero)]
        let snapshot = cache.tuning(sim.engine)
        var blocks: [BattleEventBlock] = []
        for _ in 0..<3 {
            var block = BattleEventBlock(firstTick: sim.engine.timer.tick)
            for _ in 0..<256 {
                try block.append(BattleEventState(sim.engine, cache: cache))
                sim.engine.timer.advanceTick()
            }
            XCTAssertEqual(block.tuning.changes.count, 1)
            XCTAssertTrue(snapshot === cache.tuning(sim.engine))
            blocks.append(block)
        }
        for block in blocks.reversed() {
            let decoded = try BattleEventBlock.decode(block.json())
            XCTAssertEqual(try decoded.tuning.value(at: block.firstTick), snapshot.values)
            XCTAssertEqual(try decoded.tuning.value(at: block.lastTick), snapshot.values)
        }
        var edited = blocks[0]
        var changed = edited.tuning.changes[0].value
        changed[0]?.range += 37
        edited.tuning.changes[0] = .init(tick: 0, value: changed)
        let decoded = try BattleEventBlock.decode(edited.json())
        XCTAssertEqual(try decoded.tuning.value(at: 0)[0]?.range, snapshot.values[0]!.range + 37)
        XCTAssertEqual(try BattleEventBlock.decode(blocks[0].json()).tuning.value(at: 0), snapshot.values)

        let encoder = PropertyListEncoder(); encoder.outputFormat = .binary
        var document = try XCTUnwrap(PropertyListSerialization.propertyList(from: encoder.encode(BattleEventPackedStorage(blocks[0])), format: nil) as? [String: Any])
        document["tuning"] = ["changes": [["tick": 0, "value": Data([255])]]]
        let malformed = try PropertyListSerialization.data(fromPropertyList: document, format: .binary, options: 0)
        XCTAssertThrowsError(try PropertyListDecoder().decode(BattleEventPackedStorage.self, from: malformed).unpack())
    }

}
