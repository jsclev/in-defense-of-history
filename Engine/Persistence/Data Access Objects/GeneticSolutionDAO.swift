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
    private static let columns = "run_id,candidate_id,panel,level_info_id,difficulty_id,starting_money,bounty_fraction,max_game_seconds,content_sha256,stars_used,solution_json"

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
        try serializedRows(stmt).map { $0.record }
    }
    private func serializedRows(_ stmt: OpaquePointer) throws -> [(record: GeneticSolution, json: String)] {
        let decoder = MetaUpgradesFactory.decoder(catalog: try MetaUpgradeDAO(conn: conn).get())
        var result: [(record: GeneticSolution, json: String)] = []
        var code = sqlite3_step(stmt)
        while code == SQLITE_ROW {
            guard let raw = sqlite3_column_text(stmt, 0) else {
                throw DbError.Db(message: "genetic_solution: NULL solution_json")
            }
            do {
                let json = String(cString: raw)
                let record = try decoder.decode(GeneticSolution.self, from: Data(json.utf8))
                try record.validate()
                result.append((record, json))
            } catch {
                throw DbError.Db(message: "genetic_solution: invalid solution_json: \(error)")
            }
            code = sqlite3_step(stmt)
        }
        guard code == SQLITE_DONE else {
            throw DbError.Db(message: "genetic_solution read: \(String(cString: sqlite3_errmsg(conn)))")
        }
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
            let previous = try statement("SELECT solution_json FROM genetic_solution WHERE run_id=?") {
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
            try statement("INSERT INTO genetic_solution(\(Self.columns)) VALUES(?,?,?,?,?,?,?,?,?,?,?)") { stmt in
                for record in best {
                    text(stmt, 1, runID.uuidString)
                    sqlite3_bind_int64(stmt, 2, Int64(record.candidate.id))
                    text(stmt, 3, panel.rawValue); text(stmt, 4, context.levelID.uuidString.lowercased())
                    text(stmt, 5, context.difficultyID.uuidString.lowercased())
                    sqlite3_bind_int64(stmt, 6, Int64(context.startingMoney))
                    sqlite3_bind_double(stmt, 7, context.bountyFraction)
                    sqlite3_bind_double(stmt, 8, context.maxGameSeconds)
                    text(stmt, 9, context.contentSHA256)
                    sqlite3_bind_int64(stmt, 10, Int64(record.candidate.starsUsed))
                    text(stmt, 11, String(decoding: try encoder.encode(record), as: UTF8.self))
                    try execute(stmt)
                    sqlite3_reset(stmt); sqlite3_clear_bindings(stmt)
                }
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
            SELECT solution_json FROM genetic_solution
            WHERE level_info_id=? AND difficulty_id=? AND starting_money=? AND bounty_fraction=?
              AND max_game_seconds=? AND content_sha256=? AND stars_used=? AND panel=?
              AND json_extract(solution_json,'$.formatVersion')=2
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
            SELECT solution_json FROM genetic_solution
            WHERE level_info_id=? AND difficulty_id=? AND starting_money=? AND bounty_fraction=1
              AND stars_used<=? AND panel='validation'
              AND json_extract(solution_json,'$.formatVersion')=2
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
        let found = try statement("SELECT solution_json FROM genetic_solution WHERE level_info_id=?") {
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

    /// Maintained product seed, not a diagnostic export. Serialize publishers
    /// with the DB write lock so concurrent runs cannot overwrite a newer seed.
    /// A file error is propagated; callers must not report publication success.
    public func exportSeed(to url: URL) throws {
        try transaction {
            let records = try statement("SELECT solution_json FROM genetic_solution ORDER BY run_id,panel,stars_used,candidate_id") { try serializedRows($0) }
            func quote(_ text: String) -> String { "'" + text.replacingOccurrences(of: "'", with: "''") + "'" }
            var lines = ["-- Shipping GA solutions. Generated through GeneticSolutionDAO; consumed by create_db.sh.", "BEGIN;", "DELETE FROM genetic_solution;"]
            for (record, json) in records {
                let c = record.context
                let values = [quote(record.runID.uuidString), String(record.candidate.id), quote(record.panel.rawValue),
                    quote(c.levelID.uuidString.lowercased()), quote(c.difficultyID.uuidString.lowercased()), String(c.startingMoney),
                    String(c.bountyFraction), String(c.maxGameSeconds), quote(c.contentSHA256), String(record.candidate.starsUsed),
                    quote(json)]
                lines.append("INSERT INTO genetic_solution(\(Self.columns)) VALUES(\(values.joined(separator: ",")));")
            }
            lines.append("COMMIT;\n")
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
