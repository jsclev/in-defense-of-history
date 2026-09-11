import Foundation
import SQLite3

public class WaveDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "level_wave", loggerName: WaveDAO.self)
    }

    public func getWavesFor(levelInfoId: UUID) throws -> [Wave] {
        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                lw.wave_index,
                lw.spawn_time,
                s.spawn_index,
                s.enemy_type_id,
                s.num_enemies,
                s.spawn_time_since_previous_spawn,
                s.spawn_interval,
                s.path_index,
                lw.call_button_delay,
                lw.auto_start_countdown,
                lw.early_call_bonus
            FROM
                level_wave lw
            LEFT JOIN
                level_wave_enemy_spawn s ON s.level_wave_id = lw.id
            WHERE
                lw.level_info_id = ?
            ORDER BY
                lw.wave_index, s.spawn_index
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_bind_text(stmt, 1, levelInfoId.uuidString.lowercased(),
                                -1, SQLITE_TRANSIENT) == SQLITE_OK else {
            throw DbError.Db(message: "Unable to bind level info id")
        }

        var wavesByIndex: [Int: Wave] = [:]
        var cumulativeDelay: [Int: Double] = [:]
        var lastSpawnIndex: [Int: Int] = [:]

        var result = sqlite3_step(stmt)
        while result == SQLITE_ROW {
            defer { result = sqlite3_step(stmt) }
            let waveIndex = getInt(stmt: stmt, colIndex: 0)
            if wavesByIndex[waveIndex] == nil {
                let delay = getDouble(stmt: stmt, colIndex: 8)
                let countdown = getDouble(stmt: stmt, colIndex: 9)
                let numericTypes = [SQLITE_INTEGER, SQLITE_FLOAT]
                guard numericTypes.contains(sqlite3_column_type(stmt, 8)), delay.isFinite, delay >= 0,
                      numericTypes.contains(sqlite3_column_type(stmt, 9)), countdown.isFinite, countdown >= 0 else {
                    throw DbError.Db(message: "Wave \(waveIndex) is missing valid database start timing.")
                }
                let bonus = getInt(stmt: stmt, colIndex: 10)
                guard sqlite3_column_type(stmt, 10) == SQLITE_INTEGER, bonus >= 0 else {
                    throw DbError.Db(message: "Wave \(waveIndex) is missing a valid database early-call bonus.")
                }
                wavesByIndex[waveIndex] = Wave(startTime: getDouble(stmt: stmt, colIndex: 1),
                                               spawns: [], callButtonDelay: delay,
                                               autoStartCountdown: countdown, earlyCallBonus: bonus)
            }

            guard sqlite3_column_type(stmt, 3) != SQLITE_NULL else {
                continue
            }

            let spawnIndex = getInt(stmt: stmt, colIndex: 2)
            let enemyTypeID = try getUUID(stmt: stmt, colIndex: 3, msg: "enemy type id")
            let count = getInt(stmt: stmt, colIndex: 4)
            let gap = getDouble(stmt: stmt, colIndex: 5)
            let interval = getDouble(stmt: stmt, colIndex: 6)
            let pathIndex = getInt(stmt: stmt, colIndex: 7)

            if lastSpawnIndex[waveIndex] != spawnIndex {
                cumulativeDelay[waveIndex] = (cumulativeDelay[waveIndex] ?? 0) + gap
                lastSpawnIndex[waveIndex] = spawnIndex
            }

            wavesByIndex[waveIndex]?.spawns.append(
                SpawnEntry(enemyTypeID: enemyTypeID,
                           count: count,
                           interval: interval,
                           delay: cumulativeDelay[waveIndex] ?? 0,
                           pathIndex: pathIndex)
            )
        }

        guard result == SQLITE_DONE else {
            throw DbError.Db(message: "Unable to load waves: \(String(cString: sqlite3_errmsg(conn)))")
        }

        return wavesByIndex.sorted { $0.key < $1.key }.map(\.value)
    }
}
