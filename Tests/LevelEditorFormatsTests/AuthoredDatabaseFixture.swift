import Foundation
import SQLite3
import XCTest
@testable import LevelEditorFormats

final class AuthoredDatabaseFixture {
    static let metaUpgradesFactory: MetaUpgradesFactory = {
        let fixture = try! AuthoredDatabaseFixture()
        return try! MetaUpgradesFactory(catalog: fixture.db.metaUpgradeDao.get())
    }()
    static func metaProgression(_ upgrades: [MetaUpgrade]) throws -> MetaUpgradeProgression {
        try metaUpgradesFactory.make(selected: upgrades)
    }
    static var metaDecoder: JSONDecoder { MetaUpgradesFactory.decoder(catalog: metaUpgradesFactory.catalog) }

    static let combatRules: CombatRules = {
        let fixture = try! AuthoredDatabaseFixture()
        return try! withExtendedLifetime(fixture) { try fixture.db.combatRulesDao.get() }
    }()
    static let moraleResponse: EnemyMoraleResponse = {
        let fixture = try! AuthoredDatabaseFixture()
        return try! withExtendedLifetime(fixture) { try fixture.db.enemyTypeDao.getAll()[0].stats.moraleResponse }
    }()

    let db: Db
    var connection: OpaquePointer { db.conn! }

    static func tower(_ kind: TowerKind, level: Int, branch: Int) throws -> TowerLevel {
        let fixture = try AuthoredDatabaseFixture()
        return try XCTUnwrap(fixture.db.towerTypeDao.getTowerLevelsByBranch()[kind]?[level]?[branch])
    }

    init(levelGeoJSONDao: LevelGeoJSONDAO = LevelGeoJSONDAO()) throws {
        db = Db(dbPath: ":memory:", fullRefresh: false, levelGeoJSONDao: levelGeoJSONDao)
        func execute(_ sql: String) throws {
            var error: UnsafeMutablePointer<CChar>?
            guard sqlite3_exec(connection, sql, nil, nil, &error) == SQLITE_OK else {
                let message = error.map { String(cString: $0) } ?? "Unable to load authored test data"
                sqlite3_free(error)
                throw DbError.Db(message: message)
            }
        }
        func identifier(_ name: String) -> String { "\"" + name.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        let path = Db.authoredDatabaseURL.path.replacingOccurrences(of: "'", with: "''")
        try execute("ATTACH DATABASE 'file:\(path)?mode=ro' AS authored; PRAGMA foreign_keys=OFF;")
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, "SELECT type,name,sql FROM authored.sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' ORDER BY CASE type WHEN 'table' THEN 0 ELSE 1 END", -1, &statement, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(connection)))
        }
        var schema: [(String, String, String)] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            schema.append((String(cString: sqlite3_column_text(statement, 0)),
                           String(cString: sqlite3_column_text(statement, 1)),
                           String(cString: sqlite3_column_text(statement, 2))))
        }
        sqlite3_finalize(statement)
        try execute("BEGIN")
        for (_, _, sql) in schema { try execute(sql) }
        // Historical run output is not authored content. Preserve its schema
        // for persistence tests without copying millions of old result rows.
        let results: Set<String> = ["simulator_run", "sweep_row", "money_study", "money_study_result", "level_run", "level_action"]
        for (type, name, _) in schema where type == "table" && !results.contains(name) {
            let table = identifier(name)
            try execute("INSERT INTO main.\(table) SELECT * FROM authored.\(table)")
        }
        try execute("COMMIT; DETACH DATABASE authored;")
    }
}
