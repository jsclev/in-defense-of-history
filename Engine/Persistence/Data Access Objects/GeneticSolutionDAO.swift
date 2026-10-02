import Foundation
import SQLite3

/// The only reader/writer for the shipping solution catalog. The schema and
/// seed are loaded by create_db.sh, never created or migrated at runtime.
public final class GeneticSolutionDAO {
    private let conn: OpaquePointer?
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; return encoder
    }()

    init(conn: OpaquePointer?) { self.conn = conn }

    private func statement<T>(_ sql: String, _ body: (OpaquePointer) throws -> T) throws -> T {
        guard let conn else { throw DbError.Db(message: "genetic_solution: database is closed") }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(conn, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw DbError.Db(message: "genetic_solution: \(String(cString: sqlite3_errmsg(conn)))")
        }
        return try body(stmt)
    }
    private func text(_ stmt: OpaquePointer, _ index: Int32, _ value: String) {
        sqlite3_bind_text(stmt, index, value, -1, transient)
    }
    private func execute(_ stmt: OpaquePointer) throws {
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DbError.Db(message: "genetic_solution write: \(String(cString: sqlite3_errmsg(conn)))")
        }
    }
    private func exec(_ sql: String) throws { try statement(sql) { try execute($0) } }
    private func transaction<T>(_ body: () throws -> T) throws -> T {
        try exec("BEGIN IMMEDIATE")
        var committed = false
        defer { if !committed { try? exec("ROLLBACK") } }
        let result = try body()
        try exec("COMMIT")
        committed = true
        return result
    }
    private func rows(_ stmt: OpaquePointer) throws -> [GeneticSolution] {
        let store = try GeneticStore(conn: conn)
        var result: [GeneticSolution] = []
        var code = sqlite3_step(stmt)
        while code == SQLITE_ROW {
            guard let rawRun = sqlite3_column_text(stmt, 0), let runID = UUID(uuidString: String(cString: rawRun)),
                  let rawPanel = sqlite3_column_text(stmt, 2), let panel = GeneticSolutionPanel(rawValue: String(cString: rawPanel)) else {
                throw DbError.Db(message: "genetic_solution: invalid run_id/panel")
            }
            result.append(try store.solution(runID: runID, candidateID: Int(sqlite3_column_int64(stmt, 1)), panel: panel))
            code = sqlite3_step(stmt)
        }
        guard code == SQLITE_DONE else { throw DbError.Db(message: "genetic_solution: read failed") }
        return result
    }

    /// Keeps the best N distinct plans per exact star spend for this run/panel.
    /// Earlier runs and other levels/scenarios are preserved. Invalid input
    /// fails before replacement; failed writes roll back the complete batch.
    @discardableResult
    public func saveBest(_ candidates: [GeneticCandidate], runID: UUID,
                         context: GeneticSolutionContext, executableSHA256: String,
                         panel: GeneticSolutionPanel, expectedSamples: Int,
                         limitPerStar: Int, study: AuthoredMoneyStudy) throws -> Int {
        try context.validate()
        guard limitPerStar > 0, context.levelID == study.level.id, context.difficultyID == study.difficulty.id,
              context.heroLoadout == (try GeneticHeroLoadout(content: study.battle)),
              Set(candidates.map(\.id)).count == candidates.count else {
            throw DbError.Db(message: "genetic_solution: invalid limit/context or duplicate candidate ID")
        }
        let records = try candidates.map { candidate in
            let record = GeneticSolution(formatVersion: 2, runID: runID, executableSHA256: executableSHA256,
                context: context, heroesEnabled: true, panel: panel, expectedSamples: expectedSamples, candidate: candidate)
            try record.validate()
            try candidate.strategy.validate(study: study)
            guard try candidate.strategy.playerState(in: study.battle).loadout.spentStars == candidate.starsUsed else {
                throw DbError.Db(message: "genetic_solution[\(runID)/\(candidate.id)]: starsUsed disagrees with DAO upgrade costs")
            }
            return record
        }
        let best = try Dictionary(grouping: records, by: { $0.candidate.starsUsed }).keys.sorted().flatMap { stars in
            try distinctRanked(records.filter { $0.candidate.starsUsed == stars }, limit: limitPerStar)
        }
        // An interrupted run with no evaluated candidates cannot erase content.
        guard !best.isEmpty else { return 0 }
        return try transaction {
            let previous = try statement("SELECT run_id,candidate_id,panel FROM ga_solution_details WHERE run_id=?") {
                text($0, 1, runID.uuidString); return try rows($0)
            }
            guard previous.allSatisfy({ $0.context == context && $0.executableSHA256 == executableSHA256 }) else {
                throw DbError.Db(message: "genetic_solution[\(runID)]: run context changed")
            }
            for record in best {
                for old in previous where old.candidate.id == record.candidate.id {
                    guard old.candidate.strategy == record.candidate.strategy,
                          old.candidate.generation == record.candidate.generation,
                          old.candidate.starsUsed == record.candidate.starsUsed else {
                        throw DbError.Db(message: "genetic_solution[\(runID)/\(record.candidate.id)]: candidate DNA changed")
                    }
                    if old.panel == panel {
                        guard old.expectedSamples == expectedSamples,
                              record.candidate.evaluations.starts(with: old.candidate.evaluations) else {
                            throw DbError.Db(message: "genetic_solution[\(runID)/\(record.candidate.id)]: evaluation panel shrank or changed")
                        }
                    }
                }
            }
            try statement("DELETE FROM genetic_solution WHERE run_id=? AND panel=?") {
                text($0, 1, runID.uuidString); text($0, 2, panel.rawValue); try execute($0)
            }
            let store = try GeneticStore(conn: conn)
            for record in best {
                try store.ensureRun(record)
                try store.saveCandidate(record.candidate, runID: runID, panel: panel, expected: expectedSamples)
                try store.sql.insert("genetic_solution", "run_id,candidate_id,panel", [runID, record.candidate.id, panel.rawValue])
            }
            return best.count
        }
    }

    /// Adviser entry point. Exact content/scenario matching prevents stale or
    /// experimental plans being offered for another battle. Training and partial
    /// panels require an explicit request; absence is returned as an empty list.
    public func best(context: GeneticSolutionContext, starsUsed: Int, study: AuthoredMoneyStudy,
                     panel: GeneticSolutionPanel = .validation, requireCompletePanel: Bool = true,
                     winningOnly: Bool = true, limit: Int = 8) throws -> [GeneticSolution] {
        try context.validate()
        guard starsUsed >= 0, limit > 0, context.levelID == study.level.id, context.difficultyID == study.difficulty.id,
              context.heroLoadout == (try GeneticHeroLoadout(content: study.battle)) else {
            throw DbError.Db(message: "genetic_solution: invalid lookup context/starsUsed/limit")
        }
        let found = try statement("""
            SELECT run_id,candidate_id,panel FROM ga_solution_details
            WHERE level_info_id=? AND difficulty_id=? AND starting_money=? AND bounty_fraction=?
              AND max_game_seconds=? AND content_sha256=? AND stars_used=? AND panel=?
              AND format_version=2
            """) {
            text($0, 1, context.levelID.uuidString.lowercased()); text($0, 2, context.difficultyID.uuidString.lowercased())
            sqlite3_bind_int64($0, 3, Int64(context.startingMoney)); sqlite3_bind_double($0, 4, context.bountyFraction)
            sqlite3_bind_double($0, 5, context.maxGameSeconds); text($0, 6, context.contentSHA256)
            sqlite3_bind_int64($0, 7, Int64(starsUsed)); text($0, 8, panel.rawValue)
            return try rows($0)
        }
        for record in found {
            guard record.context == context, record.heroesEnabled else {
                throw DbError.Db(message: "genetic_solution[\(record.runID)/\(record.candidate.id)]: mismatched hero loadout/context")
            }
            try record.candidate.strategy.validate(study: study)
            guard try record.candidate.strategy.playerState(in: study.battle).loadout.spentStars == starsUsed else {
                throw DbError.Db(message: "genetic_solution[\(record.runID)/\(record.candidate.id)]: invalid starsUsed")
            }
        }
        return try distinctRanked(found.filter {
            (!requireCompletePanel || $0.candidate.evaluations.count == $0.expectedSamples) && (!winningOnly || $0.victories > 0)
        }, limit: limit)
    }

    /// Preview candidates retain their recorded heroes and upgrade selection.
    /// The caller must verify the full content fingerprint before playing one.
    public func campaignCandidates(levelID: UUID, difficultyID: UUID, startingMoney: Int,
                                   earnedStars: Int) throws -> [GeneticSolution] {
        let found = try statement("""
            SELECT run_id,candidate_id,panel FROM ga_solution_details
            WHERE level_info_id=? AND difficulty_id=? AND starting_money=? AND bounty_fraction=1
              AND stars_used<=? AND panel='validation'
              AND format_version=2
            """) {
            text($0, 1, levelID.uuidString.lowercased())
            text($0, 2, difficultyID.uuidString.lowercased())
            sqlite3_bind_int64($0, 3, Int64(startingMoney))
            sqlite3_bind_int64($0, 4, Int64(earnedStars))
            return try rows($0)
        }
        // Keep different content versions until the caller checks compatibility.
        return found.filter { $0.validationComplete && $0.victories > 0 }.sorted {
            if $0.candidate.fitness != $1.candidate.fitness { return $0.candidate.fitness > $1.candidate.fitness }
            if $0.candidate.evaluations.count != $1.candidate.evaluations.count {
                return $0.candidate.evaluations.count > $1.candidate.evaluations.count
            }
            if $0.runID != $1.runID { return $0.runID.uuidString < $1.runID.uuidString }
            return $0.candidate.id < $1.candidate.id
        }
    }

    /// Historical evidence for the balance auditor. These are leads, not proof
    /// of current balance: the auditor records their contexts and reruns DNA.
    public func analysisCandidates(levelID: UUID, limit: Int = 50) throws -> [GeneticSolution] {
        guard (1...1000).contains(limit) else { throw DbError.Db(message: "genetic_solution: invalid audit limit") }
        let found = try statement("SELECT run_id,candidate_id,panel FROM ga_solution_details WHERE level_info_id=?") {
            text($0, 1, levelID.uuidString.lowercased()); return try rows($0)
        }
        return try distinctRanked(found, limit: limit)
    }

    private func distinctRanked(_ records: [GeneticSolution], limit: Int) throws -> [GeneticSolution] {
        let ranked = records.sorted {
            if $0.candidate.fitness != $1.candidate.fitness { return $0.candidate.fitness > $1.candidate.fitness }
            if $0.candidate.evaluations.count != $1.candidate.evaluations.count {
                return $0.candidate.evaluations.count > $1.candidate.evaluations.count
            }
            if $0.runID != $1.runID { return $0.runID.uuidString < $1.runID.uuidString }
            return $0.candidate.id < $1.candidate.id
        }
        var seen: Set<Data> = [], result: [GeneticSolution] = []
        for record in ranked {
            if try seen.insert(encoder.encode(record.candidate.strategy)).inserted { result.append(record) }
            if result.count == limit { break }
        }
        return result
    }

    /// Publish the existing held-out ranking without reranking demonstration runs.
    public func validatedCandidates(runID: UUID, limit: Int) throws -> [GeneticSolution] {
        guard limit > 0 else { throw DbError.Db(message: "genetic_solution: invalid publication limit") }
        let found = try statement("SELECT run_id,candidate_id,panel FROM ga_panel WHERE run_id=? AND panel='validation' AND sample_count=expected_samples") {
            text($0, 1, runID.uuidString); return try rows($0)
        }
        return try distinctRanked(found.filter { $0.validationComplete && $0.victories > 0 }, limit: limit)
    }

    /// Keep authored advice for other levels when replacing one level's catalog.
    public func copyCatalog(from source: GeneticSolutionDAO, excludingLevelID: UUID) throws {
        let records = try source.statement("SELECT run_id,candidate_id,panel FROM ga_solution_details WHERE level_info_id<>?") {
            source.text($0, 1, excludingLevelID.uuidString.lowercased()); return try source.rows($0)
        }
        try transaction {
            let store = try GeneticStore(conn: conn)
            for record in records {
                try store.ensureRun(record)
                try store.saveCandidate(record.candidate, runID: record.runID, panel: record.panel, expected: record.expectedSamples)
                try store.sql.insert("genetic_solution", "run_id,candidate_id,panel", [record.runID, record.candidate.id, record.panel.rawValue])
            }
        }
    }

    public func recordingID(for solution: GeneticSolution) throws -> UUID {
        try solution.validate()
        return try statement("SELECT level_run_id,seed FROM genetic_solution_recording WHERE run_id=? AND candidate_id=? AND panel=?") {
            text($0, 1, solution.runID.uuidString); sqlite3_bind_int64($0, 2, Int64(solution.candidate.id))
            text($0, 3, solution.panel.rawValue)
            guard sqlite3_step($0) == SQLITE_ROW, let raw = sqlite3_column_text($0, 0),
                  let id = UUID(uuidString: String(cString: raw)), let seedText = sqlite3_column_text($0, 1),
                  let seed = UInt64(String(cString: seedText)), solution.candidate.evaluations.contains(where: { $0.seed == seed }) else {
                throw DbError.Db(message: "genetic_solution[\(solution.runID)/\(solution.candidate.id)]: missing or invalid playback recording")
            }
            let run = try LevelRunDAO(conn: conn).get(id: id)
            guard run.levelID == solution.context.levelID, run.source == .simulator,
                  [.victory, .defeat, .timeout].contains(run.status) else {
                throw DbError.Db(message: "genetic_solution: playback recording does not match the solution")
            }
            return id
        }
    }

    /// Fail before spending an evaluation budget on an old starter schema.
    public func requireRecordingStorage() throws {
        do {
            try statement("SELECT run_id FROM ga_run LIMIT 0") { try execute($0) }
            try statement("""
                SELECT run_id,candidate_id,panel,seed,level_run_id,outcome,lives_remaining,
                       waves_started,seconds,matches_evaluation
                FROM genetic_solution_recording LIMIT 0
                """) { try execute($0) }
        } catch {
            throw DbError.Db(message: "GA playback storage requires a fresh starter generated by Db/create_db.sh and the CLI installer: \(error)")
        }
    }

    /// One demonstration per retained plan, after all evaluations are saved.
    /// Prefer the held-out panel for each star group; if validation never ran
    /// for a group, retain the explicit training label on its demonstrations.
    public func recordingCandidates(runID: UUID) throws -> [GeneticSolution] {
        let found = try statement("SELECT run_id,candidate_id,panel FROM ga_solution_details WHERE run_id=?") {
            text($0, 1, runID.uuidString); return try rows($0)
        }
        return try Dictionary(grouping: found, by: { $0.candidate.starsUsed }).keys.sorted().flatMap { stars in
            let group = found.filter { $0.candidate.starsUsed == stars }
            let validation = group.filter { $0.panel == .validation }
            return try distinctRanked(validation.isEmpty ? group.filter { $0.panel == .training } : validation,
                                      limit: group.count)
        }
    }

    /// Link the completed rerun and its own result; never update original fitness evidence.
    /// Differences from the original evaluation are allowed and made explicit.
    @discardableResult
    public func saveRecording(for solution: GeneticSolution, evaluation: GeneticEvaluation) throws -> Bool {
        try solution.validate()
        guard let recordingID = evaluation.runID, evaluation.result.seconds.isFinite,
              let original = solution.candidate.evaluations.first(where: { $0.seed == evaluation.seed }) else {
            throw DbError.Db(message: "genetic_solution_recording: missing recording or original evaluation seed")
        }
        let run = try LevelRunDAO(conn: conn).get(id: recordingID)
        guard run.source == .simulator, run.levelID == solution.context.levelID,
              run.status.rawValue == evaluation.result.outcome.rawValue else {
            throw DbError.Db(message: "genetic_solution_recording: recording has the wrong level, source or terminal status")
        }
        let matches = evaluation == original && (original.builtTowersByKind == nil
            || evaluation.builtTowersByKind == original.builtTowersByKind)
        try transaction {
            let saved = try statement("SELECT run_id,candidate_id,panel FROM ga_solution_details WHERE run_id=? AND candidate_id=? AND panel=?") {
                text($0, 1, solution.runID.uuidString)
                sqlite3_bind_int64($0, 2, Int64(solution.candidate.id)); text($0, 3, solution.panel.rawValue)
                return try rows($0)
            }
            guard saved.count == 1, saved[0].context == solution.context,
                  saved[0].candidate.strategy == solution.candidate.strategy,
                  saved[0].candidate.evaluations == solution.candidate.evaluations else {
                throw DbError.Db(message: "genetic_solution_recording: retained solution changed or is missing")
            }
            try statement("""
                INSERT INTO genetic_solution_recording
                    (run_id,candidate_id,panel,seed,level_run_id,outcome,lives_remaining,waves_started,seconds,matches_evaluation)
                VALUES(?,?,?,?,?,?,?,?,?,?)
                """) {
                text($0, 1, solution.runID.uuidString); sqlite3_bind_int64($0, 2, Int64(solution.candidate.id))
                text($0, 3, solution.panel.rawValue); text($0, 4, String(evaluation.seed))
                text($0, 5, recordingID.uuidString); text($0, 6, evaluation.result.outcome.rawValue)
                sqlite3_bind_int64($0, 7, Int64(evaluation.result.livesRemaining))
                sqlite3_bind_int64($0, 8, Int64(evaluation.wavesStarted))
                sqlite3_bind_double($0, 9, evaluation.result.seconds)
                sqlite3_bind_int($0, 10, matches ? 1 : 0); try execute($0)
            }
        }
        return matches
    }

    /// Maintained product seed, not a diagnostic export. Serialize publishers
    /// with the DB write lock so concurrent runs cannot overwrite a newer seed.
    /// A file error is propagated; callers must not report publication success.
    public func exportSeed(to url: URL) throws {
        try transaction {
            let store = try GeneticStore(conn: conn)
            // Validate every retained record before publishing a product seed.
            _ = try statement("SELECT run_id,candidate_id,panel FROM genetic_solution") { try rows($0) }
            let runFilter = "run_id IN (SELECT run_id FROM genetic_solution)"
            let candidateFilter = "(run_id,candidate_id) IN (SELECT run_id,candidate_id FROM genetic_solution)"
            let strategyFilter = "strategy_id IN (SELECT strategy_id FROM ga_candidate WHERE \(candidateFilter))"
            let panelFilter = "(run_id,candidate_id,panel) IN (SELECT run_id,candidate_id,panel FROM genetic_solution)"
            let evaluationFilter = "evaluation_id IN (SELECT evaluation_id FROM ga_evaluation WHERE \(panelFilter))"
            let tables = [("ga_run", runFilter), ("ga_hero", runFilter), ("ga_strategy", strategyFilter)]
                + ["ga_decision", "ga_meta_upgrade", "ga_early_wave", "ga_tactical_order"].map { ($0, strategyFilter) }
                + [("ga_candidate", candidateFilter), ("ga_panel", panelFilter), ("ga_evaluation", panelFilter)]
                + ["ga_enemy_fate", "ga_wave_progress", "ga_wave_leak", "ga_wave_economy", "ga_reinforcement_deployment", "ga_wave_call", "ga_built_tower", "ga_placement_plan", "ga_placement", "ga_playstyle", "ga_playstyle_purchase", "ga_playstyle_tower", "ga_playstyle_route", "ga_tactical_action"].map { ($0, evaluationFilter) }
                + [("genetic_solution", "1")]
            let runs = try store.sql.rows("SELECT DISTINCT run_id FROM genetic_solution ORDER BY run_id").map { try Self.quote($0.string("run_id")) }
            var lines = ["-- Relational shipping GA catalog; generated through GeneticSolutionDAO.", "PRAGMA foreign_keys=ON;", "BEGIN;",
                         "DELETE FROM genetic_solution;", "DELETE FROM ga_run WHERE run_id IN (\(runs.joined(separator: ","))); "]
            for (table, filter) in tables {
                if table.hasPrefix("ga_tactical"), !store.hasTacticalStorage { continue }
                if table.hasPrefix("ga_placement"), !store.hasPlacementStorage { continue }
                if table.hasPrefix("ga_playstyle"), !store.hasPlaystyleStorage { continue }
                let columns = try store.sql.rows("PRAGMA table_info(\(table))").map { try $0.string("name") }
                for row in try store.sql.rows("SELECT * FROM \(table) WHERE \(filter) ORDER BY \(columns[0])") {
                    let values = try columns.map { key -> String in
                        switch row.fields[key] {
                        case .null: return "NULL"
                        case let .text(value): return Self.quote(value)
                        case let .integer(value): return String(value)
                        case let .real(value): return String(value) // Double round-trip, not SQLite quote()'s rounded decimal.
                        default: throw row.invalid(key)
                        }
                    }
                    lines.append("INSERT INTO \(table)(\(columns.joined(separator: ","))) VALUES(\(values.joined(separator: ",")));")
                }
            }
            lines.append("COMMIT;\n")
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        }
    }
    private static func quote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "''") + "'" }

    /// Stream one generated SQL export per demonstration. Keep exports outside Git.
    /// BLOBs use SQLite's exact hex literals; no extra compression, JSON wrapping
    /// or whole-catalog buffer.
    public func exportRecordingSeeds(for solutions: [GeneticSolution], directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        for solution in solutions {
            let id = try recordingID(for: solution)
            let url = directory.appendingPathComponent("candidate-\(solution.candidate.id).sql")
            try Data().write(to: url, options: .withoutOverwriting)
            let file = try FileHandle(forWritingTo: url)
            defer { try? file.close() }
            func write(_ line: String) throws { try file.write(contentsOf: Data((line + "\n").utf8)) }
            try write("-- Retained GA demonstration, regenerated from candidate \(solution.candidate.id).\nBEGIN;")
            let tables = [
                ("level_run", "id,level_id,source,play_speed_factor,started_at,finished_at,status,last_sequence,last_tick,format_version,setup,result_json", "id"),
                ("level_action", "run_id,sequence,tick,category,name,payload_json,presentation,event_data", "run_id"),
                ("genetic_solution_recording", "run_id,candidate_id,panel,seed,level_run_id,outcome,lives_remaining,waves_started,seconds,matches_evaluation", "level_run_id")
            ]
            for (table, columns, key) in tables {
                let expressions = columns.split(separator: ",").map { "quote(\($0))" }.joined(separator: " || ',' || ")
                let order = table == "level_action" ? " ORDER BY sequence" : ""
                try statement("SELECT \(expressions) FROM \(table) WHERE \(key)=?\(order)") {
                    text($0, 1, id.uuidString)
                    var code = sqlite3_step($0)
                    while code == SQLITE_ROW {
                        guard let values = sqlite3_column_text($0, 0) else { throw DbError.Db(message: "genetic recording export: missing values") }
                        try write("INSERT INTO \(table)(\(columns)) VALUES(\(String(cString: values)));")
                        code = sqlite3_step($0)
                    }
                    guard code == SQLITE_DONE else { throw DbError.Db(message: "genetic recording export failed") }
                }
            }
            try write("COMMIT;")
        }
    }
}
