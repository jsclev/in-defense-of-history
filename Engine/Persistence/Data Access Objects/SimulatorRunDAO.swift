import Foundation
import SQLite3
import os

/// Progress and status for simulator sweeps.
///
/// This lives in its own database file, **not** in `redcoat_raid.sqlite`.
/// `create_db.sh` deletes and rebuilds the content database from the DML on
/// every run, which would destroy run history — and the content database is
/// meant to be reproducible from its `.sql` files, which runtime status is not.
/// Keeping it separate also means a long sweep holding this file open never
/// blocks a content rebuild.
///
/// The schema is created on demand with `IF NOT EXISTS`, so nothing has to be
/// set up before the first sweep.
public struct SimulatorRun: Sendable {
    public let id: UUID
    public let levelName: String
    public let focus: String
    public let status: String
    public let totalIterations: Int
    public let completedIterations: Int
    public let iterationsPerSecond: Double
    public let startedAt: Date
    public let updatedAt: Date
    public let finishedAt: Date?
    public let processID: Int
    public let outputPath: String
    public let reportPath: String?
    public let errorMessage: String?

    /// 0–100. Zero when the total is not yet known.
    public var percentComplete: Double {
        totalIterations > 0
            ? Double(completedIterations) / Double(totalIterations) * 100.0
            : 0
    }

    /// Seconds of work left at the current rate, or nil if it cannot be judged.
    public var estimatedSecondsRemaining: Double? {
        guard status == SimulatorRunStatus.running,
              iterationsPerSecond > 0,
              totalIterations > completedIterations else { return nil }
        return Double(totalIterations - completedIterations) / iterationsPerSecond
    }
}

public enum SimulatorRunStatus {
    public static let running = "running"
    public static let completed = "completed"
    public static let failed = "failed"
    public static let cancelled = "cancelled"
}

public final class SimulatorRunDAO {
    private let logger = LogUtility.getLogger(LogCategory.Db, SimulatorRunDAO.self)
    private var conn: OpaquePointer?
    private let iso = ISO8601DateFormatter()

    /// Timestamps this class writes always carry a timezone, but a row can also
    /// be written by hand or by a script. Falling back silently to 1970 makes a
    /// bad row look like an ancient one, so try the common variants first.
    private static let fallbackFormats = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd HH:mm:ss",
    ]

    private func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        if let d = iso.date(from: s) { return d }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: s) { return d }
        for format in Self.fallbackFormats {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = format
            if let d = df.date(from: s) { return d }
        }
        logger.error("simulator_run: unparseable timestamp \(s, privacy: .public)")
        return nil
    }

    /// Where the runs database lives by default: beside the HTML reports, so
    /// everything about a sweep is in one place.
    public static let defaultPath =
        ("~/projects/in-defense-of-history-data/SimulatorRuns/simulator_runs.sqlite"
            as NSString).expandingTildeInPath

    public init(path: String = SimulatorRunDAO.defaultPath) throws {
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir,
                                                 withIntermediateDirectories: true)
        guard sqlite3_open(path, &conn) == SQLITE_OK else {
            throw DbError.Db(message: "Unable to open simulator runs db at \(path)")
        }
        // A sweep writes from one process while a status query reads from
        // another; WAL lets those coexist without blocking each other.
        exec("PRAGMA journal_mode=WAL;")
        exec("""
        CREATE TABLE IF NOT EXISTS simulator_run (
            id                   TEXT PRIMARY KEY NOT NULL,
            level_name           TEXT NOT NULL,
            focus                TEXT NOT NULL DEFAULT '',
            status               TEXT NOT NULL,
            total_iterations     INTEGER NOT NULL DEFAULT 0,
            completed_iterations INTEGER NOT NULL DEFAULT 0,
            iterations_per_second REAL NOT NULL DEFAULT 0,
            started_at           TEXT NOT NULL,
            updated_at           TEXT NOT NULL,
            finished_at          TEXT,
            process_id           INTEGER NOT NULL DEFAULT 0,
            output_path          TEXT NOT NULL DEFAULT '',
            report_path          TEXT,
            error_message        TEXT
        );
        """)
        exec("""
        CREATE INDEX IF NOT EXISTS idx_simulator_run_status
            ON simulator_run (status, started_at DESC);
        """)
    }

    deinit { sqlite3_close_v2(conn) }

    private func exec(_ sql: String) {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(conn, sql, nil, nil, &err) != SQLITE_OK, let err {
            logger.error("simulator_run: \(String(cString: err), privacy: .public)")
            sqlite3_free(err)
        }
    }

    private func bindText(_ stmt: OpaquePointer?, _ i: Int32, _ s: String?) {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        if let s { sqlite3_bind_text(stmt, i, s, -1, transient) }
        else { sqlite3_bind_null(stmt, i) }
    }

    /// Record the start of a sweep. Returns the run's id.
    @discardableResult
    public func begin(levelName: String, focus: String, totalIterations: Int,
                      outputPath: String) throws -> UUID {
        let id = UUID()
        let now = iso.string(from: Date())
        let sql = """
        INSERT INTO simulator_run
            (id, level_name, focus, status, total_iterations, completed_iterations,
             iterations_per_second, started_at, updated_at, process_id, output_path)
        VALUES (?, ?, ?, ?, ?, 0, 0, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(conn, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DbError.Db(message: "simulator_run insert prepare failed")
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, id.uuidString)
        bindText(stmt, 2, levelName)
        bindText(stmt, 3, focus)
        bindText(stmt, 4, SimulatorRunStatus.running)
        sqlite3_bind_int64(stmt, 5, Int64(totalIterations))
        bindText(stmt, 6, now)
        bindText(stmt, 7, now)
        sqlite3_bind_int64(stmt, 8, Int64(ProcessInfo.processInfo.processIdentifier))
        bindText(stmt, 9, outputPath)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DbError.Db(message: "simulator_run insert failed")
        }
        return id
    }

    /// Report progress. Cheap enough to call on every batch.
    public func progress(id: UUID, completed: Int, iterationsPerSecond: Double) {
        let sql = """
        UPDATE simulator_run
           SET completed_iterations = ?, iterations_per_second = ?, updated_at = ?
         WHERE id = ?;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(conn, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(completed))
        sqlite3_bind_double(stmt, 2, iterationsPerSecond)
        bindText(stmt, 3, iso.string(from: Date()))
        bindText(stmt, 4, id.uuidString)
        sqlite3_step(stmt)
    }

    public func finish(id: UUID, status: String, reportPath: String? = nil,
                       errorMessage: String? = nil) {
        let now = iso.string(from: Date())
        let sql = """
        UPDATE simulator_run
           SET status = ?, finished_at = ?, updated_at = ?,
               report_path = COALESCE(?, report_path),
               error_message = ?,
               completed_iterations = CASE WHEN ? = 'completed'
                                           THEN total_iterations
                                           ELSE completed_iterations END
         WHERE id = ?;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(conn, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, status)
        bindText(stmt, 2, now)
        bindText(stmt, 3, now)
        bindText(stmt, 4, reportPath)
        bindText(stmt, 5, errorMessage)
        bindText(stmt, 6, status)
        bindText(stmt, 7, id.uuidString)
        sqlite3_step(stmt)
    }

    /// Most recent runs, newest first.
    public func recent(limit: Int = 20) throws -> [SimulatorRun] {
        try query("""
        SELECT id, level_name, focus, status, total_iterations, completed_iterations,
               iterations_per_second, started_at, updated_at, finished_at,
               process_id, output_path, report_path, error_message
          FROM simulator_run
         ORDER BY started_at DESC
         LIMIT \(limit);
        """)
    }

    public func running() throws -> [SimulatorRun] {
        try recent(limit: 100).filter { $0.status == SimulatorRunStatus.running }
    }

    public func get(id: UUID) throws -> SimulatorRun? {
        try query("""
        SELECT id, level_name, focus, status, total_iterations, completed_iterations,
               iterations_per_second, started_at, updated_at, finished_at,
               process_id, output_path, report_path, error_message
          FROM simulator_run WHERE id = '\(id.uuidString)';
        """).first
    }

    private func query(_ sql: String) throws -> [SimulatorRun] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(conn, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DbError.Db(message: "simulator_run query failed")
        }
        defer { sqlite3_finalize(stmt) }

        func text(_ i: Int32) -> String? {
            guard let c = sqlite3_column_text(stmt, i) else { return nil }
            return String(cString: c)
        }

        var out: [SimulatorRun] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let idText = text(0), let id = UUID(uuidString: idText) else { continue }
            out.append(SimulatorRun(
                id: id,
                levelName: text(1) ?? "",
                focus: text(2) ?? "",
                status: text(3) ?? "",
                totalIterations: Int(sqlite3_column_int64(stmt, 4)),
                completedIterations: Int(sqlite3_column_int64(stmt, 5)),
                iterationsPerSecond: sqlite3_column_double(stmt, 6),
                startedAt: parseDate(text(7)) ?? Date(timeIntervalSince1970: 0),
                updatedAt: parseDate(text(8)) ?? Date(timeIntervalSince1970: 0),
                finishedAt: parseDate(text(9)),
                processID: Int(sqlite3_column_int64(stmt, 10)),
                outputPath: text(11) ?? "",
                reportPath: text(12),
                errorMessage: text(13)
            ))
        }
        return out
    }
}
