import Foundation
import SQLite3

/// Sweep results, written to SQLite instead of a CSV.
///
/// The working database is `:memory:` so inserts never touch the disk on the
/// hot path. A disk file is ATTACHed alongside it and topped up incrementally
/// every few batches — copying only the rows added since the last flush, not
/// re-dumping the whole table — so a killed run still leaves everything it had
/// finished, the way the old `.partial` CSV checkpoint did.
///
/// SQLite takes one writer at a time, so all inserts happen on the thread that
/// owns this object, in batches wrapped in a single transaction.
final class SweepResultStore {
    private var conn: OpaquePointer?
    private var insertStmt: OpaquePointer?
    private let runID: UUID?
    private var lastFlushedRowID: Int64 = 0
    private var pendingSinceFlush = 0
    private let flushEvery: Int
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private static let columns = """
        run_id, perm, money, starting_lives, upgrade_growth, tower_range, tower_rof,
        tower_projectile_speed, tower_splash, tower_falloff,
        enemy_speed_bracket_position, enemy_hp_bracket_position,
        enemy_bounty_bracket_position, melee_hp_bracket_position,
        melee_damage_bracket_position, comp_curve, comp_mix, comp_spacing, seeds,
        win_rate, lives_p10, lives_p50, lives_p90, mean_leaked, rout_share,
        tension_mean, tension_peak, tension_final, mean_seconds,
        w1_greedy_clear, w1_greedy_leaks, w1_naive_clear, w1_naive_leaks
        """

    private static func schema(_ prefix: String) -> String {
        """
        CREATE TABLE IF NOT EXISTS \(prefix)sweep_row (
            id                            INTEGER PRIMARY KEY,
            run_id                        TEXT,
            perm                          INTEGER NOT NULL,
            money                         INTEGER NOT NULL,
            starting_lives                INTEGER NOT NULL,
            upgrade_growth                TEXT NOT NULL,
            tower_range                   TEXT NOT NULL,
            tower_rof                     TEXT NOT NULL,
            tower_projectile_speed        TEXT NOT NULL,
            tower_splash                  TEXT NOT NULL,
            tower_falloff                 TEXT NOT NULL,
            enemy_speed_bracket_position  REAL NOT NULL,
            enemy_hp_bracket_position     REAL NOT NULL,
            enemy_bounty_bracket_position REAL NOT NULL,
            melee_hp_bracket_position     REAL NOT NULL,
            melee_damage_bracket_position REAL NOT NULL,
            comp_curve                    TEXT NOT NULL,
            comp_mix                      TEXT NOT NULL,
            comp_spacing                  TEXT NOT NULL,
            seeds                         INTEGER NOT NULL,
            win_rate                      REAL NOT NULL,
            lives_p10                     REAL NOT NULL,
            lives_p50                     REAL NOT NULL,
            lives_p90                     REAL NOT NULL,
            mean_leaked                   REAL NOT NULL,
            rout_share                    REAL NOT NULL,
            tension_mean                  REAL NOT NULL,
            tension_peak                  REAL NOT NULL,
            tension_final                 REAL NOT NULL,
            mean_seconds                  REAL NOT NULL,
            w1_greedy_clear               REAL NOT NULL,
            w1_greedy_leaks               REAL NOT NULL,
            w1_naive_clear                REAL NOT NULL,
            w1_naive_leaks                REAL NOT NULL
        );
        """
    }

    init(diskPath: String, runID: UUID?, flushEveryRows: Int = 100_000) throws {
        self.runID = runID
        self.flushEvery = flushEveryRows

        guard sqlite3_open(":memory:", &conn) == SQLITE_OK else {
            throw DbError.Db(message: "Unable to open in-memory sweep database")
        }
        exec("PRAGMA journal_mode=OFF;")
        exec("PRAGMA synchronous=OFF;")
        exec("PRAGMA temp_store=MEMORY;")
        exec(Self.schema(""))

        try? FileManager.default.removeItem(atPath: diskPath)
        try? FileManager.default.createDirectory(
            atPath: (diskPath as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true)
        let escaped = diskPath.replacingOccurrences(of: "'", with: "''")
        exec("ATTACH DATABASE '\(escaped)' AS disk;")
        exec("PRAGMA disk.journal_mode=OFF;")
        exec("PRAGMA disk.synchronous=OFF;")
        exec(Self.schema("disk."))

        let placeholders = Array(repeating: "?", count: 33).joined(separator: ",")
        let sql = "INSERT INTO sweep_row (\(Self.columns)) VALUES (\(placeholders));"
        guard sqlite3_prepare_v2(conn, sql, -1, &insertStmt, nil) == SQLITE_OK else {
            throw DbError.Db(message: "sweep_row insert prepare failed: "
                + String(cString: sqlite3_errmsg(conn)))
        }
    }

    deinit {
        sqlite3_finalize(insertStmt)
        sqlite3_close_v2(conn)
    }

    private func exec(_ sql: String) {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(conn, sql, nil, nil, &err) != SQLITE_OK, let err {
            FileHandle.standardError.write(Data("  sweep db: \(String(cString: err))\n".utf8))
            sqlite3_free(err)
        }
    }

    /// Insert a batch. One transaction, one reused prepared statement.
    func insert(_ rows: [SweepRow]) {
        guard !rows.isEmpty else { return }
        exec("BEGIN;")
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
                FileHandle.standardError.write(Data(
                    "  sweep db insert: \(String(cString: sqlite3_errmsg(conn)))\n".utf8))
            }
            sqlite3_reset(insertStmt)
        }
        exec("COMMIT;")

        pendingSinceFlush += rows.count
        if pendingSinceFlush >= flushEvery { flushToDisk() }
    }

    /// Copy rows added since the last flush into the attached disk database.
    func flushToDisk() {
        guard pendingSinceFlush > 0 else { return }
        exec("""
        INSERT INTO disk.sweep_row SELECT * FROM main.sweep_row WHERE id > \(lastFlushedRowID);
        """)
        lastFlushedRowID = sqlite3_last_insert_rowid(conn)
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(conn, "SELECT COALESCE(MAX(id), 0) FROM main.sweep_row;",
                              -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW { lastFlushedRowID = sqlite3_column_int64(stmt, 0) }
            sqlite3_finalize(stmt)
        }
        pendingSinceFlush = 0
    }

    /// Final flush plus the indexes that make the results worth querying.
    func finish() {
        flushToDisk()
        // The schema qualifier goes on the INDEX name in SQLite, not the table.
        exec("CREATE INDEX IF NOT EXISTS disk.idx_sweep_row_run ON sweep_row (run_id);")
        exec("CREATE INDEX IF NOT EXISTS disk.idx_sweep_row_range ON sweep_row (tower_range);")
        exec("CREATE INDEX IF NOT EXISTS disk.idx_sweep_row_win ON sweep_row (win_rate);")
        exec("DETACH DATABASE disk;")
    }

    var rowCount: Int {
        var stmt: OpaquePointer?
        var n = 0
        if sqlite3_prepare_v2(conn, "SELECT COUNT(*) FROM main.sweep_row;", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW { n = Int(sqlite3_column_int64(stmt, 0)) }
            sqlite3_finalize(stmt)
        }
        return n
    }
}
