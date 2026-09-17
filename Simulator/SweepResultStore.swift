import Foundation
import SQLite3

final class SweepResultStore {
    private var conn: OpaquePointer?
    private var insertStmt: OpaquePointer?
    private let runID: UUID?
    private(set) var rowCount = 0
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private let columns = """
        run_id, perm, money, starting_lives, upgrade_growth, tower_range, tower_rof,
        tower_projectile_speed, tower_splash, tower_falloff,
        enemy_speed_bracket_position, enemy_hp_bracket_position,
        enemy_bounty_bracket_position, melee_hp_bracket_position,
        melee_damage_bracket_position, comp_curve, comp_mix, comp_spacing, seeds,
        win_rate, lives_p10, lives_p50, lives_p90, mean_leaked, rout_share,
        tension_mean, tension_peak, tension_final, mean_seconds,
        w1_greedy_clear, w1_greedy_leaks, w1_naive_clear, w1_naive_leaks
        """

    init(databasePath: String, runID: UUID?) throws {
        self.runID = runID
        guard sqlite3_open_v2(databasePath, &conn, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            throw DbError.Db(message: "Unable to open the authored database for sweep results")
        }
        sqlite3_busy_timeout(conn, 5_000)

        let placeholders = Array(repeating: "?", count: 33).joined(separator: ",")
        let sql = "INSERT INTO sweep_row (\(columns)) VALUES (\(placeholders));"
        guard sqlite3_prepare_v2(conn, sql, -1, &insertStmt, nil) == SQLITE_OK else {
            throw DbError.Db(message: "sweep_row insert prepare failed: "
                + String(cString: sqlite3_errmsg(conn)))
        }
    }

    deinit {
        sqlite3_finalize(insertStmt)
        sqlite3_close_v2(conn)
    }

    private func exec(_ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(conn, sql, nil, nil, &err) != SQLITE_OK {
            let message = err.map { String(cString: $0) } ?? "Unable to write sweep results"
            sqlite3_free(err)
            throw DbError.Db(message: message)
        }
    }

    /// Insert a batch. One transaction, one reused prepared statement.
    func insert(_ rows: [SweepRow]) throws {
        guard !rows.isEmpty else { return }
        try exec("BEGIN;")
        var committed = false
        defer { if !committed { try? exec("ROLLBACK;") } }
        for row in rows {
            let p = row.perm
            var i: Int32 = 0
            func text(_ s: String) { i += 1; sqlite3_bind_text(insertStmt, i, s, -1, transient) }
            func int(_ v: Int) { i += 1; sqlite3_bind_int64(insertStmt, i, Int64(v)) }
            func real(_ v: Double) { i += 1; sqlite3_bind_double(insertStmt, i, v) }

            if let runID { text(runID.uuidString) } else { i += 1; sqlite3_bind_null(insertStmt, i) }
            int(p.index); int(p.money); int(p.lives)
            text(p.growthLabel); text(p.rangeLabel); text(p.rofLabel)
            text(p.projSpeedLabel); text(p.splashLabel); text(p.falloffLabel)
            real(p.enemySpeedBracketPosition); real(p.enemyHpBracketPosition)
            real(p.enemyBountyBracketPosition); real(p.meleeHpBracketPosition)
            real(p.meleeDamageBracketPosition)
            text(p.curve); text(p.mix); text(p.spacing)
            int(row.seedsUsed)
            real(row.winRate); real(row.livesP10); real(row.livesP50); real(row.livesP90)
            real(row.meanLeaked); real(row.routShare)
            real(row.tensionMean); real(row.tensionPeak); real(row.tensionFinal)
            real(row.meanSeconds)
            real(row.w1GreedyClear); real(row.w1GreedyLeaks)
            real(row.w1NaiveClear); real(row.w1NaiveLeaks)

            if sqlite3_step(insertStmt) != SQLITE_DONE {
                let message = String(cString: sqlite3_errmsg(conn))
                sqlite3_reset(insertStmt)
                throw DbError.Db(message: "Unable to write sweep result: \(message)")
            }
            sqlite3_reset(insertStmt)
        }
        try exec("COMMIT;")
        committed = true

        rowCount += rows.count
    }
}
