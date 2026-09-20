import Foundation
import SQLite3

public struct MoneyStudyResultRow: Sendable {
    public let money: Int
    public let placementPlan: Int
    public let upgradePolicy: Int
    public let results: [SimulationResult]
    public init(money: Int, placementPlan: Int, upgradePolicy: Int, results: [SimulationResult]) {
        self.money = money; self.placementPlan = placementPlan
        self.upgradePolicy = upgradePolicy; self.results = results
    }
}

/// Used serially by the study coordinator. Schema is authored by create_db.sh;
/// the simulator never creates tables or opens an alternative result database.
public final class MoneyStudyDAO {
    private let db: Db
    private let conn: OpaquePointer
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public init(db: Db) throws {
        guard let connection = db.conn else { throw DbError.Db(message: "money_study: database is closed") }
        self.db = db; conn = connection
        sqlite3_busy_timeout(conn, 5_000)
    }

    private func statement(_ sql: String, _ body: (OpaquePointer) throws -> Void) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(conn, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw DbError.Db(message: "money_study: \(String(cString: sqlite3_errmsg(conn)))")
        }
        defer { sqlite3_finalize(stmt) }
        try body(stmt)
    }
    private func text(_ stmt: OpaquePointer, _ index: Int32, _ value: String) {
        sqlite3_bind_text(stmt, index, value, -1, transient)
    }
    private func execute(_ stmt: OpaquePointer) throws {
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DbError.Db(message: "money_study write failed: \(String(cString: sqlite3_errmsg(conn)))")
        }
    }
    private func exec(_ sql: String) throws { try statement(sql) { try execute($0) } }

    public func begin(runID: UUID, configuration: String, contentSHA256: String, plans: String) throws {
        try statement("INSERT INTO money_study(run_id,configuration_json,content_sha256,plans_json) VALUES(?,?,?,?)") {
            text($0, 1, runID.uuidString); text($0, 2, configuration)
            text($0, 3, contentSHA256); text($0, 4, plans)
            try execute($0)
        }
    }

    public func insert(_ rows: [MoneyStudyResultRow], runID: UUID, completed: Int, rate: Double) throws {
        guard !rows.isEmpty else { return }
        try exec("BEGIN IMMEDIATE")
        var committed = false
        defer { if !committed { try? exec("ROLLBACK") } }
        try statement("""
            INSERT INTO money_study_result(run_id,money,placement_plan,upgrade_policy,seeds,
                victories,defeats,timeouts,mean_lives,mean_leaked,mean_seconds,seed_results_json)
            VALUES(?,?,?,?,?,?,?,?,?,?,?,?)
            """) { stmt in
            for row in rows {
                let report = BatchReport(results: row.results)
                guard report.runs > 0 else { throw DbError.Db(message: "money study: empty result group") }
                text(stmt, 1, runID.uuidString)
                for (index, value) in [row.money, row.placementPlan, row.upgradePolicy, report.runs,
                                       report.victories, report.defeats, report.timeouts].enumerated() {
                    sqlite3_bind_int64(stmt, Int32(index + 2), Int64(value))
                }
                let count = Double(report.runs)
                sqlite3_bind_double(stmt, 9, row.results.reduce(0) { $0 + Double($1.livesRemaining) } / count)
                sqlite3_bind_double(stmt, 10, Double(report.totalLeaked) / count)
                sqlite3_bind_double(stmt, 11, row.results.reduce(0) { $0 + $1.seconds } / count)
                // Compact per-seed evidence, retaining actual outcomes rather
                // than treating a timeout as a defeat or inventing early exits.
                let samples: [[String: Any]] = row.results.enumerated().map { index, result in
                    ["seedIndex": index, "outcome": result.outcome.rawValue,
                     "seconds": result.seconds, "lives": result.livesRemaining,
                     "gold": result.goldRemaining, "killed": result.killed,
                     "routed": result.routed, "captured": result.captured, "leaked": result.leaked]
                }
                let data = try JSONSerialization.data(withJSONObject: samples, options: [.sortedKeys])
                text(stmt, 12, String(decoding: data, as: UTF8.self))
                try execute(stmt)
                sqlite3_reset(stmt); sqlite3_clear_bindings(stmt)
            }
        }
        try statement("UPDATE simulator_run SET completed_iterations=?,iterations_per_second=?,updated_at=? WHERE id=? AND status='running'") {
            sqlite3_bind_int64($0, 1, Int64(completed)); sqlite3_bind_double($0, 2, rate)
            text($0, 3, ISO8601DateFormatter().string(from: Date())); text($0, 4, runID.uuidString)
            try execute($0)
            guard sqlite3_changes(conn) == 1 else { throw DbError.Db(message: "money study: run progress row is missing") }
        }
        try exec("COMMIT")
        committed = true
    }

    public func summary(runID: UUID) throws -> [[String: Any]] {
        var result: [[String: Any]] = []
        try statement("""
            SELECT money,SUM(seeds),SUM(victories),SUM(defeats),SUM(timeouts),
                   SUM(mean_lives*seeds)/SUM(seeds),SUM(mean_leaked*seeds)/SUM(seeds),
                   MAX(1.0*victories/seeds),SUM(CASE WHEN victories*1.0/seeds>=0.8 THEN 1 ELSE 0 END),COUNT(*)
            FROM money_study_result WHERE run_id=? GROUP BY money ORDER BY money
            """) { stmt in
                text(stmt, 1, runID.uuidString)
                var code = sqlite3_step(stmt)
                while code == SQLITE_ROW {
                    result.append(["money": Int(sqlite3_column_int64(stmt, 0)),
                        "runs": Int(sqlite3_column_int64(stmt, 1)), "victories": Int(sqlite3_column_int64(stmt, 2)),
                        "defeats": Int(sqlite3_column_int64(stmt, 3)), "timeouts": Int(sqlite3_column_int64(stmt, 4)),
                        "meanLives": sqlite3_column_double(stmt, 5), "meanLeaked": sqlite3_column_double(stmt, 6),
                        "bestStrategyWinRate": sqlite3_column_double(stmt, 7),
                        "strategiesAtLeast80Percent": Int(sqlite3_column_int64(stmt, 8)),
                        "strategies": Int(sqlite3_column_int64(stmt, 9))])
                    code = sqlite3_step(stmt)
                }
                guard code == SQLITE_DONE else { throw DbError.Db(message: "money study: summary query failed") }
            }
        return result
    }
}
