import Foundation
import SQLite3
import os

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
        guard status == SimulatorRunStatus.running.rawValue,
              iterationsPerSecond > 0,
              totalIterations > completedIterations else { return nil }
        return Double(totalIterations - completedIterations) / iterationsPerSecond
    }
}

public enum SimulatorRunStatus: String, Sendable {
    case running
    case completed
    case failed
    case cancelled
}

public final class SimulatorRunDAO {
    private let logger = LogUtility.getLogger(LogCategory.Db, SimulatorRunDAO.self)
    private var conn: OpaquePointer?
    private let iso = ISO8601DateFormatter()

    /// Timestamps this class writes always carry a timezone, but a row can also
    /// be written by hand or by a script. Falling back silently to 1970 makes a
    /// bad row look like an ancient one, so try the common variants first.
    private let fallbackFormats = [
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
        for format in fallbackFormats {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = format
            if let d = df.date(from: s) { return d }
        }
        logger.error("simulator_run: unparseable timestamp \(s, privacy: .public)")
        return nil
    }

    init(conn: OpaquePointer?) {
        self.conn = conn
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
        bindText(stmt, 4, SimulatorRunStatus.running.rawValue)
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

    public func finish(id: UUID, status: SimulatorRunStatus, reportPath: String? = nil,
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
        bindText(stmt, 1, status.rawValue)
        bindText(stmt, 2, now)
        bindText(stmt, 3, now)
        bindText(stmt, 4, reportPath)
        bindText(stmt, 5, errorMessage)
        bindText(stmt, 6, status.rawValue)
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
        try recent(limit: 100).filter { $0.status == SimulatorRunStatus.running.rawValue }
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
