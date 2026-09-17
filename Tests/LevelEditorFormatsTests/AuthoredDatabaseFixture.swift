import Foundation
import SQLite3
import XCTest
@testable import LevelEditorFormats

final class AuthoredDatabaseFixture {
    let db: Db
    var connection: OpaquePointer { db.conn! }

    static func tower(_ category: String, level: Int, branch: Int) throws -> TowerLevel {
        let fixture = try AuthoredDatabaseFixture()
        return try XCTUnwrap(fixture.db.towerTypeDao.getTowerLevelsByBranch()[category]?[level]?[branch])
    }

    init(levelGeoJSONDao: LevelGeoJSONDAO = LevelGeoJSONDAO()) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = ["-readonly", Db.authoredDatabaseURL.path, ".dump"]
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        let sql = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, let statements = String(data: sql, encoding: .utf8) else {
            throw DbError.Db(message: "Unable to load authored SQL for tests")
        }
        db = Db(dbPath: ":memory:", fullRefresh: false, levelGeoJSONDao: levelGeoJSONDao)
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(connection, statements, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "Unable to load authored test data"
            sqlite3_free(error)
            throw DbError.Db(message: message)
        }
    }
}
