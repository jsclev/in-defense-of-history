import Foundation
import SQLite3
import XCTest
@testable import LevelEditorFormats

final class SimulatorDatabaseTests: XCTestCase {
    private func snapshot(source: Db, destination: URL, arguments: [String]) throws -> Db {
        try SimulatorDatabase.create(source: source, destination: destination, arguments: arguments,
            schema: Db.authoredDatabaseURL.deletingLastPathComponent().appendingPathComponent("DDL/create_simulator_invocation.sql"))
    }
    private func fixture() throws -> AuthoredDatabaseFixture {
        try AuthoredDatabaseFixture(levelGeoJSONDao: LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
    }
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("simulator-database-tests-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: url) }
        return url
    }
    private func scalar(_ db: Db, _ sql: String) throws -> Int {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db.conn, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(db.conn)))
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { throw DbError.Db(message: "No scalar row") }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    func testSnapshotCapturesContentAndMapsButStartsWithoutOldResults() throws {
        let source = try fixture()
        _ = try source.db.simulatorRunDao.begin(levelName: "Charleston", focus: "prior run", totalIterations: 1, outputPath: ":memory:")
        let destination = try directory().appendingPathComponent("run.sqlite")
        let db = try snapshot(source: source.db, destination: destination, arguments: ["LibertyLineSimulator", "--genetic-study", "Charleston"])
        defer { db.close() }
        XCTAssertEqual(try scalar(db, "SELECT count(*) FROM level_info"), try scalar(source.db, "SELECT count(*) FROM level_info"))
        XCTAssertEqual(try scalar(db, "SELECT count(*) FROM simulator_map"), try scalar(source.db, "SELECT count(DISTINCT map_image_name) FROM level_info WHERE map_image_name <> ''"))
        for table in ["simulator_run", "money_study", "money_study_result", "level_run", "level_action", "genetic_solution", "simulator_document"] {
            XCTAssertEqual(try scalar(db, "SELECT count(*) FROM \(table)"), 0, table)
        }
        XCTAssertEqual(try scalar(source.db, "SELECT count(*) FROM simulator_run"), 1)
        let name = "level_15_charleston"
        XCTAssertEqual(try db.levelGeoJSONDao.sourceData(mapImageName: name), try source.db.levelGeoJSONDao.sourceData(mapImageName: name))
        XCTAssertThrowsError(try db.levelGeoJSONDao.sourceData(mapImageName: "missing"))
        XCTAssertNoThrow(try db.simulatorInvocationDao.validate())
    }

    func testSourceEditsPropagateOnlyIntoLaterSnapshots() throws {
        let source = try fixture()
        let root = try directory()
        let first = try snapshot(source: source.db, destination: root.appendingPathComponent("first.sqlite"), arguments: [])
        defer { first.close() }
        let id = try XCTUnwrap(source.db.levelInfoDao.getIdBy(levelName: "Charleston"))
        let before = try first.levelInfoDao.getBy(id: id).startingMoney
        XCTAssertEqual(sqlite3_exec(source.connection, "UPDATE level_info SET starting_money=starting_money+17", nil, nil, nil), SQLITE_OK)
        let second = try snapshot(source: source.db, destination: root.appendingPathComponent("second.sqlite"), arguments: [])
        defer { second.close() }
        XCTAssertEqual(try first.levelInfoDao.getBy(id: id).startingMoney, before)
        XCTAssertEqual(try second.levelInfoDao.getBy(id: id).startingMoney, before + 17)
    }

    func testSeparateConnectionsShareCheckpointsAndReopenWithoutCheckoutMaps() throws {
        let source = try fixture()
        let destination = try directory().appendingPathComponent("run.sqlite")
        let db = try snapshot(source: source.db, destination: destination, arguments: [])
        let worker = try SimulatorDatabase.open(destination)
        let first = Data("{\"generation\":1}".utf8), second = Data("{\"generation\":2}".utf8)
        try db.simulatorInvocationDao.saveDocument(first, name: "population.json")
        XCTAssertEqual(try worker.simulatorInvocationDao.document(named: "population.json"), first)
        try worker.simulatorInvocationDao.saveDocument(second, name: "population.json")
        XCTAssertEqual(try db.simulatorInvocationDao.document(named: "population.json"), second)
        worker.close(); db.close()
        let read = try SimulatorDatabase.open(destination, readOnly: true)
        defer { read.close() }
        XCTAssertEqual(try read.simulatorInvocationDao.document(named: "population.json"), second)
        XCTAssertNoThrow(try read.levelGeoJSONDao.getHeroConfiguration(mapImageName: "level_15_charleston"))
        XCTAssertThrowsError(try read.simulatorInvocationDao.saveDocument(first, name: "population.json"))
        XCTAssertEqual(try scalar(source.db, "SELECT count(*) FROM simulator_run"), 0)
    }

    func testInstalledStarterCloneUsesCapturedSchemaAndMaps() throws {
        let source = try fixture()
        let root = try directory()
        let first = try snapshot(source: source.db, destination: root.appendingPathComponent("first.sqlite"), arguments: [])
        defer { first.close() }
        try first.simulatorInvocationDao.saveDocument(Data("{\"old\":true}".utf8), name: "old.json")
        let second = try SimulatorDatabase.create(source: first, destination: root.appendingPathComponent("second.sqlite"), arguments: [])
        defer { second.close() }
        XCTAssertEqual(try scalar(second, "SELECT count(*) FROM simulator_document"), 0)
        XCTAssertEqual(try scalar(second, "SELECT count(*) FROM simulator_invocation"), 1)
        XCTAssertEqual(try second.levelGeoJSONDao.sourceData(mapImageName: "level_15_charleston"), try first.levelGeoJSONDao.sourceData(mapImageName: "level_15_charleston"))
        XCTAssertEqual(try first.simulatorInvocationDao.document(named: "old.json"), Data("{\"old\":true}".utf8))
    }

    func testExistingDestinationAndMissingMapsFailWithoutReplacingData() throws {
        let source = try fixture()
        let root = try directory(), destination = root.appendingPathComponent("existing.sqlite")
        let sentinel = Data("existing data".utf8)
        try sentinel.write(to: destination)
        XCTAssertThrowsError(try snapshot(source: source.db, destination: destination, arguments: []))
        XCTAssertEqual(try Data(contentsOf: destination), sentinel)
        let missingMaps = try AuthoredDatabaseFixture(levelGeoJSONDao: LevelGeoJSONDAO(documents: [:]))
        let failed = root.appendingPathComponent("failed.sqlite")
        XCTAssertThrowsError(try snapshot(source: missingMaps.db, destination: failed, arguments: []))
        XCTAssertFalse(FileManager.default.fileExists(atPath: failed.path))
        XCTAssertThrowsError(try SimulatorDatabase.open(root.appendingPathComponent("absent.sqlite")))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("absent.sqlite").path))
    }

    func testDefaultNamesAreUniqueBesideExecutable() {
        let executable = URL(fileURLWithPath: "/Users/example/bin/LibertyLineSimulator")
        let first = SimulatorDatabase.destination(beside: executable, buildName: "1.0.999")
        let second = SimulatorDatabase.destination(beside: executable, buildName: "1.0.999")
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(first.deletingLastPathComponent(), executable.deletingLastPathComponent())
        XCTAssertTrue(first.lastPathComponent.hasPrefix("liberty-line-simulator-1.0.999-run-"))
        XCTAssertEqual(first.pathExtension, "sqlite")
        XCTAssertEqual(SimulatorDatabase.starter(beside: executable, buildName: "1.0.999").path,
                       "/Users/example/bin/liberty-line-simulator-1.0.999.sqlite")
        XCTAssertNotEqual(SimulatorDatabase.starter(beside: executable, buildName: "1.0.998"),
                          SimulatorDatabase.starter(beside: executable, buildName: "1.0.999"))
    }
}
