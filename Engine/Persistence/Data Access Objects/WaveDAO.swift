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
                s.path_index
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

        guard sqlite3_bind_text(stmt, 1, levelInfoId.uuidString.lowercased(),
                                -1, SQLITE_TRANSIENT) == SQLITE_OK else {
            throw DbError.Db(message: "Unable to bind level info id")
        }

        var startTimes: [Int: Double] = [:]
        var spawnsByWave: [Int: [SpawnEntry]] = [:]
        var cumulativeDelay: [Int: Double] = [:]
        var lastSpawnIndex: [Int: Int] = [:]

        while sqlite3_step(stmt) == SQLITE_ROW {
            let waveIndex = getInt(stmt: stmt, colIndex: 0)
            startTimes[waveIndex] = getDouble(stmt: stmt, colIndex: 1)

            guard sqlite3_column_type(stmt, 3) != SQLITE_NULL else {
                spawnsByWave[waveIndex] = spawnsByWave[waveIndex] ?? []
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

            spawnsByWave[waveIndex, default: []].append(
                SpawnEntry(enemyTypeID: enemyTypeID,
                           count: count,
                           interval: interval,
                           delay: cumulativeDelay[waveIndex] ?? 0,
                           pathIndex: pathIndex)
            )
        }

        sqlite3_finalize(stmt)
        stmt = nil

        return startTimes.keys.sorted().map { index in
            Wave(startTime: startTimes[index] ?? 0, spawns: spawnsByWave[index] ?? [])
        }
    }
}
