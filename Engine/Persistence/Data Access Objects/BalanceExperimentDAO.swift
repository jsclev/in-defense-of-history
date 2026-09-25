import Foundation
import SQLite3

/// Mutates only a disposable SQLite content copy. Normal DAOs validate the
/// original and reload every varied value before the shared engine sees it.
public enum BalanceExperimentDAO {
    public static func contentCopy(of source: Db, levelID: UUID, scenario: BalanceScenario) throws -> Db {
        try scenario.validate()
        let original = try AuthoredMoneyStudy(db: source, levelID: levelID)
        let roster = Dictionary(uniqueKeysWithValues: original.battle.enemies.map { ($0.key, $0.id) })
        let replacements = try scenario.enemyKeys.map { key -> UUID in
            guard let id = roster[key] else { throw DbError.Db(message: "enemy_type[\(key)]: unknown balance replacement key") }
            return id
        }
        let copy = try BountyExperimentDAO.contentCopy(of: source, fraction: 1)
        guard let conn = copy.conn else { throw DbError.Db(message: "balance experiment: missing in-memory connection") }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        func statement(_ sql: String, _ bind: (OpaquePointer) -> Void) throws {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(conn, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
                throw DbError.Db(message: "balance experiment: \(String(cString: sqlite3_errmsg(conn)))")
            }
            bind(stmt)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw DbError.Db(message: "balance experiment: \(String(cString: sqlite3_errmsg(conn)))")
            }
        }
        do {
            if scenario.rangedDamageMultiplier != 1 {
                try statement("""
                    UPDATE tower SET shot_min_damage=shot_min_damage * ?, shot_max_damage=shot_max_damage * ?
                    WHERE tower_type_id IN (SELECT id FROM tower_type WHERE tower_type_key='ranged')
                    """) {
                    sqlite3_bind_double($0, 1, scenario.rangedDamageMultiplier)
                    sqlite3_bind_double($0, 2, scenario.rangedDamageMultiplier)
                }
                guard sqlite3_changes(conn) > 0 else { throw DbError.Db(message: "tower_type[ranged]: no damage rows") }
            }
            if !replacements.isEmpty {
                // Re-author spawn rows at identical per-enemy times and routes.
                // Counts, wave clocks and bonuses stay fixed; enemy stats and
                // bounties follow the chosen authored types without adjustment.
                for (waveIndex, wave) in original.level.waves.enumerated() {
                    struct Event { let time: Double; let path: Int; let enemy: UUID; let order: Int }
                    var events: [Event] = [], ordinal = 0, replaced = 0
                    for spawn in wave.spawns {
                        for index in 0..<spawn.count {
                            let replace = Int(Double(ordinal + 1) * scenario.replacementFraction)
                                > Int(Double(ordinal) * scenario.replacementFraction)
                            let id = replace ? replacements[replaced % replacements.count] : spawn.enemyTypeID
                            if replace { replaced += 1 }
                            events.append(Event(time: spawn.delay + Double(index) * spawn.interval,
                                                path: spawn.pathIndex, enemy: id, order: ordinal))
                            ordinal += 1
                        }
                    }
                    events.sort { $0.time == $1.time ? $0.order < $1.order : $0.time < $1.time }
                    try statement("DELETE FROM level_wave_enemy_spawn WHERE level_wave_id IN (SELECT id FROM level_wave WHERE level_info_id=? AND wave_index=?)") {
                        sqlite3_bind_text($0, 1, levelID.uuidString.lowercased(), -1, transient)
                        sqlite3_bind_int($0, 2, Int32(waveIndex + 1))
                    }
                    var previous = 0.0
                    for (index, event) in events.enumerated() {
                        try statement("""
                            INSERT INTO level_wave_enemy_spawn(id,level_wave_id,enemy_type_id,spawn_index,num_enemies,
                                spawn_time_since_previous_spawn,spawn_interval,path_index)
                            SELECT ?,id,?,?,1,?,1,? FROM level_wave WHERE level_info_id=? AND wave_index=?
                            """) {
                            sqlite3_bind_text($0, 1, UUID().uuidString.lowercased(), -1, transient)
                            sqlite3_bind_text($0, 2, event.enemy.uuidString.lowercased(), -1, transient)
                            sqlite3_bind_int64($0, 3, Int64(index)); sqlite3_bind_double($0, 4, event.time - previous)
                            sqlite3_bind_int64($0, 5, Int64(event.path))
                            sqlite3_bind_text($0, 6, levelID.uuidString.lowercased(), -1, transient)
                            sqlite3_bind_int($0, 7, Int32(waveIndex + 1))
                        }
                        guard sqlite3_changes(conn) == 1 else { throw DbError.Db(message: "level_wave[\(waveIndex + 1)]: missing experiment wave") }
                        previous = event.time
                    }
                }
            }
            _ = try AuthoredMoneyStudy(db: copy, levelID: levelID)
            return copy
        } catch { copy.close(); throw error }
    }
}
