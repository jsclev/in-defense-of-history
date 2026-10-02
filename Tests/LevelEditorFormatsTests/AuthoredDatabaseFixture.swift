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
        // Recording schema follows the authored DDL even when the live checkout
        // database retains historical results under an older schema.
        let recordingSchema: Set<String> = ["level_run", "level_action", "level_run_level", "level_action_tick", "genetic_solution_recording"]
        for (_, name, sql) in schema where !recordingSchema.contains(name) && !name.hasPrefix("level_recording_") && !name.hasPrefix("ga_") && !name.hasPrefix("genetic_solution") { try execute(sql) }
        try execute(String(contentsOf: Db.authoredDatabaseURL.deletingLastPathComponent()
            .appendingPathComponent("DDL/create_level_runs.sql"), encoding: .utf8))
        for file in ["create_genetic_solutions.sql", "create_genetic_placements.sql", "create_genetic_playstyles.sql", "create_genetic_studies.sql", "create_genetic_fitness.sql"] {
            try execute(String(contentsOf: Db.authoredDatabaseURL.deletingLastPathComponent()
                .appendingPathComponent("DDL/" + file), encoding: .utf8))
        }
        // Historical run output is not authored content. Preserve its schema
        // for persistence tests without copying millions of old result rows.
        let results: Set<String> = ["simulator_run", "sweep_row", "money_study", "money_study_result", "level_run", "level_action", "genetic_solution_recording"]
        for (type, name, _) in schema where type == "table" && !results.contains(name) && !name.hasPrefix("level_recording_") && !name.hasPrefix("ga_") && !name.hasPrefix("genetic_solution") {
            let table = identifier(name)
            try execute("INSERT INTO main.\(table) SELECT * FROM authored.\(table)")
        }
        try execute(String(contentsOf: Db.authoredDatabaseURL.deletingLastPathComponent()
            .appendingPathComponent("DML/genetic_solutions.sql"), encoding: .utf8)
            .replacingOccurrences(of: "PRAGMA foreign_keys=ON;", with: "")
            .replacingOccurrences(of: "BEGIN;", with: "").replacingOccurrences(of: "COMMIT;", with: ""))
        try execute("COMMIT; DETACH DATABASE authored;")
    }
}
