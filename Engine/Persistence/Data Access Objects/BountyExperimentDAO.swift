import Foundation
import SQLite3

/// Disposable content experiments. The authored database remains the source;
/// only copied bounty/optional hero-selection rows change. Normal DAOs reload
/// all inputs; the source player's hero selection is never edited.
public final class BountyExperimentDAO {
    public static func contentCopy(of source: Db, fraction: Double, selectedHeroIDs: [UUID]? = nil,
                                   heroAI: [UUID: Bool] = [:]) throws -> Db {
        guard fraction.isFinite, (0...1).contains(fraction), let original = source.conn else {
            throw DbError.Db(message: "bounty experiment: fraction must be between zero and one and source must be open")
        }
        _ = try source.combatRulesDao.get()
        let copy = Db(dbPath: ":memory:", fullRefresh: false, levelGeoJSONDao: source.levelGeoJSONDao)
        guard let target = copy.conn else { throw DbError.Db(message: "bounty experiment: missing in-memory connection") }
        func execute(_ sql: String) throws {
            guard sqlite3_exec(target, sql, nil, nil, nil) == SQLITE_OK else {
                throw DbError.Db(message: "bounty experiment: \(String(cString: sqlite3_errmsg(target)))")
            }
        }
        do {
            if source.path == ":memory:" {
                guard let backup = sqlite3_backup_init(target, "main", original, "main") else {
                    throw DbError.Db(message: "bounty experiment: unable to copy in-memory content")
                }
                let step = sqlite3_backup_step(backup, -1), finish = sqlite3_backup_finish(backup)
                guard step == SQLITE_DONE, finish == SQLITE_OK else {
                    throw DbError.Db(message: "bounty experiment: in-memory content copy failed")
                }
            } else {
                var attach: OpaquePointer?
                guard sqlite3_prepare_v2(target, "ATTACH DATABASE ? AS authored", -1, &attach, nil) == SQLITE_OK else {
                    throw DbError.Db(message: "bounty experiment: unable to attach authored content")
                }
                let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                sqlite3_bind_text(attach, 1, source.path, -1, transient)
                let attached = sqlite3_step(attach)
                sqlite3_finalize(attach)
                guard attached == SQLITE_DONE else { throw DbError.Db(message: "bounty experiment: unable to attach source") }
                try execute("PRAGMA foreign_keys=OFF; BEGIN")
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(target, "SELECT type,name,sql FROM authored.sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' ORDER BY CASE type WHEN 'table' THEN 0 ELSE 1 END", -1, &statement, nil) == SQLITE_OK else {
                    throw DbError.Db(message: "bounty experiment: missing authored schema")
                }
                var schema: [(String, String, String)] = []
                var status = sqlite3_step(statement)
                while status == SQLITE_ROW {
                    schema.append((String(cString: sqlite3_column_text(statement, 0)),
                                   String(cString: sqlite3_column_text(statement, 1)),
                                   String(cString: sqlite3_column_text(statement, 2))))
                    status = sqlite3_step(statement)
                }
                sqlite3_finalize(statement)
                guard status == SQLITE_DONE else { throw DbError.Db(message: "bounty experiment: schema read failed") }
                for (_, _, sql) in schema { try execute(sql) }
                // Retain SQL-defined result tables but not historical output.
                let history: Set<String> = ["simulator_run", "sweep_row", "money_study", "money_study_result", "level_run", "level_action",
                    "genetic_solution", "simulator_invocation", "simulator_document", "simulator_map"]
                for (type, name, _) in schema where type == "table" && !history.contains(name) {
                    let table = "\"" + name.replacingOccurrences(of: "\"", with: "\"\"") + "\""
                    try execute("INSERT INTO main.\(table) SELECT * FROM authored.\(table)")
                }
                try execute("COMMIT; DETACH DATABASE authored; PRAGMA foreign_keys=ON")
            }
            var update: OpaquePointer?
            guard sqlite3_prepare_v2(target, "UPDATE combat_rules SET kill_bounty_multiplier=kill_bounty_multiplier * ? WHERE id=1", -1, &update, nil) == SQLITE_OK else {
                throw DbError.Db(message: "bounty experiment: missing combat_rules.kill_bounty_multiplier")
            }
            sqlite3_bind_double(update, 1, fraction)
            let status = sqlite3_step(update), changed = sqlite3_changes(target)
            sqlite3_finalize(update)
            guard status == SQLITE_DONE, changed == 1 else {
                throw DbError.Db(message: "bounty experiment: expected exactly one combat_rules row")
            }
            _ = try copy.combatRulesDao.get()
            if let selectedHeroIDs {
                try copy.heroDao.setSelectedHeroes(selectedHeroIDs)
                _ = try HeroSelectionStore(dao: copy.heroDao).load()
            }
            for (id, enabled) in heroAI {
                try copy.playerSettingsDao.setHeroAIEnabled(enabled, heroID: id)
            }
            return copy
        } catch {
            copy.close()
            throw error
        }
    }
}
