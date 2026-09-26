import Foundation
import SQLite3

public struct MoneyStudyResultRow: Sendable {
    public let money: Int
    public let placementPlan: Int
    public let upgradePolicy: Int
    public let results: [SimulationResult]
    public let evidenceJSON: String?
    public init(money: Int, placementPlan: Int, upgradePolicy: Int, results: [SimulationResult], evidenceJSON: String? = nil) {
        self.money = money; self.placementPlan = placementPlan
        self.upgradePolicy = upgradePolicy; self.results = results
        self.evidenceJSON = evidenceJSON
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

    /// Adaptive searches use the existing SQL-authored money-study tables.
    /// placement_plan identifies a genome; upgrade_policy identifies the frozen
    /// evaluation panel (0 training, 1 held-out). Full DNA and explicit seeds are
    /// recorded in each row's evidenceJSON. The checkpoint holds population IDs;
    /// it never rewrites a growing global array of every genome for each game.
    public func recordAdaptiveCheckpoint(runID: UUID, json: String) throws {
        try statement("UPDATE money_study SET plans_json=json_set(plans_json,'$.checkpoint',json(?)) WHERE run_id=?") {
            text($0, 1, json); text($0, 2, runID.uuidString); try execute($0)
            guard sqlite3_changes(conn) == 1 else { throw DbError.Db(message: "genetic study: missing checkpoint row") }
        }
    }

    /// A time-bounded search need not consume its evaluation ceiling. Verify
    /// persisted evidence and publish actual counts instead of claiming the cap.
    public func finishAdaptive(runID: UUID, completed: Int, reportPath: String) throws {
        try statement("SELECT COALESCE(SUM(seeds),0) FROM money_study_result WHERE run_id=?") {
            text($0, 1, runID.uuidString)
            guard sqlite3_step($0) == SQLITE_ROW, Int(sqlite3_column_int64($0, 0)) == completed else {
                throw DbError.Db(message: "genetic study: persisted evaluation count mismatch")
            }
        }
        try statement("""
            UPDATE simulator_run SET status='completed',total_iterations=?,completed_iterations=?,
                updated_at=?,finished_at=?,report_path=? WHERE id=? AND status='running'
            """) {
            sqlite3_bind_int64($0, 1, Int64(completed)); sqlite3_bind_int64($0, 2, Int64(completed))
            let now = ISO8601DateFormatter().string(from: Date())
            text($0, 3, now); text($0, 4, now); text($0, 5, reportPath); text($0, 6, runID.uuidString)
            try execute($0)
            guard sqlite3_changes(conn) == 1 else { throw DbError.Db(message: "genetic study: missing active run") }
        }
    }

    public func insert(_ rows: [MoneyStudyResultRow], runID: UUID, completed: Int, rate: Double,
                       replacingValidation: Bool = false) throws {
        guard !rows.isEmpty else { return }
        guard !replacingValidation || rows.allSatisfy({ $0.upgradePolicy == 1 && $0.evidenceJSON != nil }) else {
            throw DbError.Db(message: "genetic checkpoint: only held-out evidence may replace an existing panel")
        }
        try exec("BEGIN IMMEDIATE")
        var committed = false
        defer { if !committed { try? exec("ROLLBACK") } }
        try statement("""
            INSERT INTO money_study_result(run_id,money,placement_plan,upgrade_policy,seeds,
                victories,defeats,timeouts,mean_lives,mean_leaked,mean_seconds,seed_results_json)
            VALUES(?,?,?,?,?,?,?,?,?,?,?,?)
            \(replacingValidation ? """
            ON CONFLICT(run_id,money,placement_plan,upgrade_policy) DO UPDATE SET
                seeds=excluded.seeds,victories=excluded.victories,defeats=excluded.defeats,timeouts=excluded.timeouts,
                mean_lives=excluded.mean_lives,mean_leaked=excluded.mean_leaked,mean_seconds=excluded.mean_seconds,
                seed_results_json=excluded.seed_results_json
            WHERE excluded.seeds >= money_study_result.seeds
                AND json_extract(excluded.seed_results_json,'$.strategy') = json_extract(money_study_result.seed_results_json,'$.strategy')
                AND NOT EXISTS (
                    SELECT 1 FROM json_each(money_study_result.seed_results_json,'$.evaluations') AS previous
                    WHERE json_extract(excluded.seed_results_json,'$.evaluations[' || previous.key || ']') IS NOT json(previous.value)
                )
            """ : "")
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
                if let evidence = row.evidenceJSON {
                    text(stmt, 12, evidence)
                } else {
                    // Build fallback summaries only for callers without full
                    // evidence. GA rows already carry exact seeds and receipts.
                    let samples: [[String: Any]] = row.results.enumerated().map { index, result in
                        ["seedIndex": index, "outcome": result.outcome.rawValue,
                         "seconds": result.seconds, "lives": result.livesRemaining,
                         "gold": result.goldRemaining, "killed": result.killed, "leaked": result.leaked]
                    }
                    let data = try JSONSerialization.data(withJSONObject: samples, options: [.sortedKeys])
                    text(stmt, 12, String(decoding: data, as: UTF8.self))
                }
                try execute(stmt)
                guard sqlite3_changes(conn) == 1 else { throw DbError.Db(message: "genetic checkpoint: shrinking panel or changed candidate DNA") }
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

    /// v2+ evidence records exact spend and canonical meta genes with each
    /// candidate. Legacy fixed-loadout studies are deliberately excluded.
    public func geneticSummaryByStars(runID: UUID) throws -> [[String: Any]] {
        var result: [[String: Any]] = []
        try statement("""
            SELECT COUNT(*) FROM money_study_result r JOIN money_study s USING(run_id)
            WHERE r.run_id=? AND json_extract(s.configuration_json,'$.algorithm') IN ('genetic-v2','genetic-v3','genetic-v4','genetic-v5','genetic-v6','genetic-v7','genetic-v8')
              AND (json_type(r.seed_results_json,'$.starsUsed') IS NOT 'integer'
                OR json_extract(r.seed_results_json,'$.starsUsed')<0
                OR json_type(r.seed_results_json,'$.strategy.metaUpgrades') IS NOT 'array')
            """) {
            text($0, 1, runID.uuidString)
            guard sqlite3_step($0) == SQLITE_ROW, sqlite3_column_int64($0, 0) == 0 else {
                throw DbError.Db(message: "genetic study: missing or invalid starsUsed/metaUpgrades evidence")
            }
        }
        try statement("""
            SELECT json_extract(r.seed_results_json,'$.starsUsed'),r.upgrade_policy,
                   COUNT(*),SUM(r.seeds),SUM(r.victories),SUM(r.defeats),SUM(r.timeouts),
                   COUNT(DISTINCT json_extract(r.seed_results_json,'$.strategy.metaUpgrades'))
            FROM money_study_result r JOIN money_study s USING(run_id)
            WHERE r.run_id=? AND json_extract(s.configuration_json,'$.algorithm') IN ('genetic-v2','genetic-v3','genetic-v4','genetic-v5','genetic-v6','genetic-v7','genetic-v8')
            GROUP BY json_extract(r.seed_results_json,'$.starsUsed'),r.upgrade_policy ORDER BY 1,2
            """) { stmt in
            text(stmt, 1, runID.uuidString)
            var code = sqlite3_step(stmt)
            while code == SQLITE_ROW {
                let names = ["starsUsed", "panel", "candidates", "engineGames", "victories", "defeats", "timeouts", "metaLoadoutsTested"]
                result.append(Dictionary(uniqueKeysWithValues: names.enumerated().map {
                    ($0.element, Int(sqlite3_column_int64(stmt, Int32($0.offset))) as Any)
                }))
                code = sqlite3_step(stmt)
            }
            guard code == SQLITE_DONE else { throw DbError.Db(message: "genetic study: star summary query failed") }
        }
        return result
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
