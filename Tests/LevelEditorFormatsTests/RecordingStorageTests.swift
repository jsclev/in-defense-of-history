import XCTest
import SQLite3
import CryptoKit
@testable import LevelEditorFormats

final class RecordingStorageTests: XCTestCase {
    private func fixture() throws -> AuthoredDatabaseFixture {
        try AuthoredDatabaseFixture(levelGeoJSONDao: LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
    }
    private func execute(_ sql: String, _ connection: OpaquePointer) throws {
        guard sqlite3_exec(connection, sql, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(connection)))
        }
    }
    private func hex(_ data: Data) -> String { data.map { String(format: "%02x", $0) }.joined() }
    private func tagged(_ raw: Data, algorithm: NSData.CompressionAlgorithm) throws -> Data {
        Data("LLRC1".utf8) + Data([algorithm == .lzfse ? 1 : 0])
            + (try (raw as NSData).compressed(using: algorithm) as Data)
    }

    @MainActor func testNewRecordingsKeepSelfContainedLZ4SetupAndEveryEventBlock() throws {
        let f = try fixture(), dao = f.db.levelRunDao
        let content = try BattleTestFixture.authored(db: f.db)
        for seed in [UInt64(17), UInt64.max] {
            let sim = try GameSimulation(recording: .database(dao, .simulator), content: content,
                startingMoney: 100_000, heroesEnabled: true, seed: seed)
            XCTAssertEqual(sim.perform(.build(slot: 0, kind: .ranged)), .ok)
            sim.startNextWave()
            for _ in 0..<530 { sim.step() }
            sim.finishRecording(status: .timeout)
            let id = try XCTUnwrap(sim.runID), run = try dao.get(id: id)
            let setupBytes = try (run.setup as NSData).decompressed(using: .lz4) as Data
            let setup = try PropertyListDecoder().decode(LevelReplaySetup.self, from: setupBytes)
            XCTAssertEqual(setup.seed, seed)
            let rows = try dao.actions(runID: id, limit: 1000)
            let blocks = try rows.filter { $0.eventData != nil }.map { row in
                XCTAssertEqual(row.name, BattleEventBlock.rowName)
                let raw = try (XCTUnwrap(row.eventData) as NSData).decompressed(using: .lz4) as Data
                return try PropertyListDecoder().decode(BattleEventPackedStorage.self, from: raw).unpack()
            }
            XCTAssertGreaterThan(blocks.count, 1)
            XCTAssertEqual(blocks.first?.firstTick, 0)
            XCTAssertEqual(blocks.last?.lastTick, run.lastTick)
            for (previous, next) in zip(blocks, blocks.dropFirst()) {
                XCTAssertEqual(next.firstTick, previous.lastTick + 1)
            }
            let replay = try LevelReplayer(dao: dao, runID: id)
            var frames = 0
            while try replay.advance() { frames += 1 }
            XCTAssertEqual(frames, Int(run.lastTick) + 1)
        }
    }

    // Construct the retired 1.0.205 layout only in a disposable in-memory fixture.
    // Production contains no shared-content writer or retention policy.
    @MainActor private func historicalSharedRun(_ f: AuthoredDatabaseFixture) throws -> UUID {
        let dao = f.db.levelRunDao
        let sim = try GameSimulation(recording: .database(dao, .simulator), content: BattleTestFixture.authored(db: f.db),
            startingMoney: 100_000, heroesEnabled: false, seed: UInt64.max)
        XCTAssertEqual(sim.perform(.build(slot: 0, kind: .ranged)), .ok)
        sim.startNextWave()
        for _ in 0..<270 { sim.step() }
        sim.finishRecording(status: .timeout)
        let id = try XCTUnwrap(sim.runID), run = try dao.get(id: id)
        try execute("""
            CREATE TABLE level_recording_content(hash TEXT PRIMARY KEY, data BLOB NOT NULL);
            CREATE TABLE level_recording_retention(run_id TEXT PRIMARY KEY, retained INTEGER NOT NULL);
            INSERT INTO level_recording_retention VALUES('\(id)',1);
            """, f.connection)
        func store(_ raw: Data) throws -> String {
            let hash = SHA256.hash(data: raw).map { String(format: "%02x", $0) }.joined()
            try execute("INSERT OR IGNORE INTO level_recording_content VALUES('\(hash)',X'\(hex(try tagged(raw, algorithm: .lzfse)))')", f.connection)
            return hash
        }
        let setup = try LevelRecordingCodec.decode(LevelReplaySetup.self, from: run.setup)
        let json = JSONEncoder()
        json.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "+Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        var content = try XCTUnwrap(JSONSerialization.jsonObject(with: json.encode(setup)) as? [String: Any])
        content.removeValue(forKey: "seed")
        let hash = try store(JSONSerialization.data(withJSONObject: content, options: [.sortedKeys]))
        struct Reference: Codable { let hash: String; let seed: UInt64 }
        let encoder = PropertyListEncoder(); encoder.outputFormat = .binary
        let reference = Data("LLSETUP1".utf8) + (try tagged(encoder.encode(Reference(hash: hash, seed: setup.seed)), algorithm: .lz4))
        try execute("UPDATE level_run SET setup=X'\(hex(reference))' WHERE id='\(id)'", f.connection)
        for row in try dao.actions(runID: id, limit: 1000) where row.eventData != nil {
            let observed = try BattleEventBlock.decode(row)
            let legacy = try LevelRecordingCodec.encode(BattleEventPackedStorage(observed))
            var block = try XCTUnwrap(PropertyListSerialization.propertyList(from: LevelRecordingCodec.decompress(legacy), format: nil) as? [String: Any])
            var tuning = try XCTUnwrap(block["tuning"] as? [String: Any])
            var changes = try XCTUnwrap(tuning["changes"] as? [[String: Any]])
            for index in changes.indices {
                changes[index]["value"] = Data(try store(XCTUnwrap(changes[index]["value"] as? Data)).utf8)
            }
            tuning["changes"] = changes; block["tuning"] = tuning; block["version"] = 4
            let raw = try PropertyListSerialization.data(fromPropertyList: block, format: .binary, options: 0)
            try execute("UPDATE level_action SET name='battle-events-v4',event_data=X'\(hex(try tagged(raw, algorithm: .lzfse)))' WHERE run_id='\(id)' AND sequence=\(row.sequence)", f.connection)
        }
        return id
    }

    @MainActor func testHistoricalSharedLZFSEMoviesRemainReadableAndMissingContentFails() throws {
        let f = try fixture(), id = try historicalSharedRun(f), dao = f.db.levelRunDao
        try execute("UPDATE tower SET shot_min_damage=shot_min_damage+10,shot_max_damage=shot_max_damage+10", f.connection)
        let replay = try LevelReplayer(dao: dao, runID: id)
        XCTAssertEqual(replay.setup.seed, UInt64.max)
        var frames = 0
        while try replay.advance() { frames += 1 }
        XCTAssertEqual(frames, Int(try dao.get(id: id).lastTick) + 1)
        try execute("DELETE FROM level_recording_content", f.connection)
        XCTAssertThrowsError(try LevelReplayer(dao: dao, runID: id))
    }

    @MainActor func testHistoricalPrunedMovieStillReportsMissingRecording() throws {
        let f = try fixture(), id = try historicalSharedRun(f)
        try execute("UPDATE level_recording_retention SET retained=0 WHERE run_id='\(id)'", f.connection)
        XCTAssertThrowsError(try LevelReplayer(dao: f.db.levelRunDao, runID: id)) { error in
            XCTAssertTrue(String(describing: error).contains("retention policy"))
        }
    }

    func testLZ4WritesAndHistoricalTaggedCodecsPreserveExactBits() throws {
        let values: [Double] = [0, -0.0, .infinity, -.infinity, .leastNonzeroMagnitude, .greatestFiniteMagnitude, 1.2345678901234567]
        let bits = values.map(\.bitPattern)
        let encoder = PropertyListEncoder(); encoder.outputFormat = .binary
        let raw = try encoder.encode(bits), current = try LevelRecordingCodec.encode(bits)
        XCTAssertEqual(try (current as NSData).decompressed(using: .lz4) as Data, raw)
        for data in [current, try tagged(raw, algorithm: .lz4), try tagged(raw, algorithm: .lzfse)] {
            XCTAssertEqual(try LevelRecordingCodec.decode([UInt64].self, from: data), bits)
        }
        XCTAssertThrowsError(try LevelRecordingCodec.decompress(Data("LLRC1".utf8) + Data([9, 0])))
    }
}
