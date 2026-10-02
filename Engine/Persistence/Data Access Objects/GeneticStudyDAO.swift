import Foundation

/// GA study persistence only. No combat, breeding, seed selection or ranking
/// rules live here. Authored DDL: Db/DDL/create_genetic_studies.sql.
public final class GeneticStudyDAO {
    private let db: Db
    private let store: GeneticStore
    private var checkpointMembers: [String: Int] = [:]
    private var sql: GeneticSQL { store.sql }
    public init(db: Db) throws { self.db = db; store = try GeneticStore(conn: db.conn) }

    public func begin(runID: UUID, context: GeneticSolutionContext, executableSHA256: String,
                      snapshotSHA256: String, buildVersion: String, options o: GeneticStudyOptions,
                      requestedStars: [Int], reachableStars: [Int], earnedStars: Int,
                      databaseUpgrades: [MetaUpgrade], trainingSeeds: [UInt64], validationSeeds: [UInt64]) throws {
        guard store.hasPlacementStorage, store.hasPlaystyleStorage else {
            throw sql.error("study requires placement tables from the current SQL-generated starter")
        }
        try sql.transaction {
            try store.ensureRun(runID: runID, context: context, executableSHA256: executableSHA256)
            try sql.insert("ga_study", "run_id,algorithm,build_version,snapshot_sha256,workers,population,generations,training_seeds,validation_seeds,finalists,max_evaluations,hours,search_seed,star_minimum,star_maximum,star_step,fixed_meta,early_wave_calls,meta_selections,minimum_meta_candidates,meta_adaptation_generations,hero_ai_override,selected_heroes_overridden,majority_tower_kind,earned_stars",
                [runID, "genetic-v13", buildVersion, snapshotSHA256, o.workers, o.population, o.generations, o.trainingSeeds, o.validationSeeds, o.finalists,
                 o.maxEvaluations, o.hours, String(o.seed), o.starMinimum, o.starMaximum, o.starStep, o.fixedMeta, o.earlyWaveCalls,
                 o.metaSelections, o.minimumMetaCandidates, o.metaAdaptationGenerations, o.heroAIEnabled, o.selectedHeroIDs != nil, o.towerLimits.majorityKind?.rawValue, earnedStars])
            if let policy = o.stopping {
                try sql.insert("ga_stopping_policy", "run_id,minimum_training_battles,stability_battles,stability_generations,solutions",
                    [runID,policy.minimumTrainingBattles,policy.stabilityBattles,policy.stabilityGenerations,policy.solutions])
            }
            for (panel, seeds) in [("training", trainingSeeds), ("validation", validationSeeds)] {
                for (i, seed) in seeds.enumerated() { try sql.insert("ga_study_seed", "run_id,panel,ordinal,seed", [runID, panel, i, String(seed)]) }
            }
            for (i, stars) in requestedStars.enumerated() {
                try sql.insert("ga_study_star", "run_id,ordinal,stars_used,reachable", [runID, i, stars, reachableStars.contains(stars)])
            }
            for upgrade in databaseUpgrades { try sql.insert("ga_study_upgrade", "run_id,upgrade_id", [runID, upgrade.rawValue]) }
            for (kind, maximum) in o.towerLimits.maximumByKind { try sql.insert("ga_tower_limit", "run_id,tower_kind,maximum", [runID, kind, maximum]) }
            for (role, strategies) in [("seed", o.seedStrategies), ("exchange", o.metaExchangeFrom.map { [$0] } ?? [])] {
                for (i, strategy) in strategies.enumerated() {
                    let id = try store.insertStrategy(strategy, runID: runID)
                    try sql.insert("ga_input_strategy", "run_id,role,ordinal,strategy_id", [runID, role, i, id])
                }
            }
        }
    }
    public func runID() throws -> UUID { try sql.one("SELECT run_id FROM ga_study").uuid("run_id") }
    public func algorithm(runID: UUID) throws -> String {
        try sql.one("SELECT algorithm FROM ga_study WHERE run_id=?", [runID]).string("algorithm")
    }

    public struct RankedPlacementCandidate {
        public let id: Int
        public let starsUsed: Int
        public let victories: Int
        public let samples: Int
        public let winRate: Double
        public let meanVictoryLives: Double
        public let meanWavesStarted: Double
        public let meanSurvivalSeconds: Double
        public let placementPlan: GeneticPlacementPlan?
        public let placementSeed: UInt64
        public func requirePlacementPlan() throws -> GeneticPlacementPlan {
            guard let plan = placementPlan else {
                throw DbError.Db(message: "candidate \(id), seed \(placementSeed): missing saved opening and subsequent placements")
            }
            return plan
        }
    }

    /// Fetch just the sortable fitness columns and saved successful placements for
    /// comparison. No evaluation receipts, battle content or recordings are loaded.
    public func rankedPlacementCandidates(runID: UUID, panel: GeneticSolutionPanel) throws -> [RankedPlacementCandidate] {
        let rows = try sql.rows("""
            SELECT f.*,e.evaluation_id,e.seed
            FROM ga_candidate_fitness f JOIN ga_evaluation e ON e.evaluation_id=(
                SELECT v.evaluation_id FROM ga_evaluation v
                WHERE v.run_id=f.run_id AND v.candidate_id=f.candidate_id AND v.panel=f.panel
                ORDER BY (v.outcome='victory') DESC,
                    CASE WHEN v.outcome='victory' THEN v.lives_remaining ELSE 0 END DESC,
                    v.waves_started DESC,CASE WHEN v.outcome='defeat' THEN v.seconds ELSE 0 END DESC,
                    length(v.seed),v.seed LIMIT 1)
            WHERE f.run_id=? AND f.panel=? AND f.panel_complete=1 AND f.victories>0
            ORDER BY f.stars_used,f.win_rate DESC,f.mean_victory_lives DESC,
                     f.mean_waves_started DESC,f.mean_survival_seconds DESC,f.candidate_id
            """, [runID, panel.rawValue])
        return try rows.map { row in
            try RankedPlacementCandidate(id: row.int("candidate_id"), starsUsed: row.int("stars_used"),
                victories: row.int("victories"), samples: row.int("samples"), winRate: row.double("win_rate"),
                meanVictoryLives: row.double("mean_victory_lives"), meanWavesStarted: row.double("mean_waves_started"),
                meanSurvivalSeconds: row.double("mean_survival_seconds"),
                placementPlan: store.placementPlan(evaluationID: row.int64("evaluation_id")), placementSeed: row.seed("seed"))
        }
    }

    public func candidate(runID: UUID, candidateID: Int, panel: GeneticSolutionPanel) throws -> GeneticCandidate {
        try store.candidate(runID: runID, candidateID: candidateID, panel: panel)
    }

    /// Run only on an explicit migrated copy. Unknown candidates remain unknown;
    /// recovered demonstrations are identified separately from original results.
    public func recoverRecordedPlacements() throws -> Int {
        guard store.hasPlacementStorage else { throw sql.error("apply create_genetic_placements.sql to a copy first") }
        return try sql.transaction {
            var count = 0
            let rows = try sql.rows("""
                SELECT e.evaluation_id,r.level_run_id FROM genetic_solution_recording r
                JOIN ga_evaluation e USING(run_id,candidate_id,panel,seed)
                LEFT JOIN ga_placement_plan p USING(evaluation_id)
                WHERE p.evaluation_id IS NULL ORDER BY e.evaluation_id
                """)
            for row in rows {
                let plan = try GeneticPlacementRecovery.read(dao: db.levelRunDao, recordingID: row.uuid("level_run_id"))
                try store.savePlacementPlan(plan, evaluationID: row.int64("evaluation_id"))
                count += 1
            }
            return count
        }
    }
    public func recordImport(runID: UUID, context: GeneticSolutionContext, executableSHA256: String,
                             sourceDatabase: String, sourceRunID: UUID) throws {
        try sql.transaction {
            try store.ensureRun(runID: runID, context: context, executableSHA256: executableSHA256)
            try sql.insert("ga_import", "run_id,source_database,source_run_id,selection",
                [runID, sourceDatabase, sourceRunID, "Creative playstyle selection from original placement, purchase and activity records against every selected candidate; original fitness preserved; selected before held-out evaluation"])
        }
    }
    public func saveEvidence(_ candidate: GeneticCandidate, runID: UUID, panel: GeneticSolutionPanel, expectedSamples: Int) throws {
        try sql.transaction { try store.saveCandidate(candidate, runID: runID, panel: panel, expected: expectedSamples) }
    }
    public func saveGoalProgress(runID: UUID, convergence: GeneticSearchConvergence) throws {
        try sql.transaction {
            for (stars, state) in convergence.groups {
                try sql.execute("INSERT OR REPLACE INTO ga_search_goal VALUES(?,?,?,?,?,?,?,?)",
                    [runID, stars, state.battles, state.lastImprovementBattle, state.lastImprovementGeneration,
                     state.lastExplorationBattle, state.lastExplorationGeneration, state.winningNiches.count])
            }
        }
    }
    public func beginQualification(runID: UUID, attempt: Int, context: GeneticSolutionContext,
                                   executableSHA256: String, trainingBattles: Int, generations: Int,
                                   seeds: [UInt64]) throws -> UUID {
        let evidenceID = UUID()
        try sql.transaction {
            try store.ensureRun(runID: evidenceID, context: context, executableSHA256: executableSHA256)
            try sql.insert("ga_qualification", "study_run_id,attempt,evidence_run_id,training_battles,generations,status",
                [runID, attempt, evidenceID, trainingBattles, generations, "running"])
            for (i, seed) in seeds.enumerated() {
                try sql.insert("ga_qualification_seed", "evidence_run_id,ordinal,seed", [evidenceID, i, String(seed)])
            }
        }
        return evidenceID
    }
    public func finishQualification(evidenceID: UUID, status: String) throws {
        try sql.execute("UPDATE ga_qualification SET status=? WHERE evidence_run_id=? AND status='running'", [status,evidenceID])
        guard sql.changes == 1 else { throw sql.error("qualification attempt is missing or already finished") }
    }
    public func finalValidationSeeds(runID: UUID, seeds: [UInt64]) throws {
        try sql.transaction {
            try sql.execute("DELETE FROM ga_study_seed WHERE run_id=? AND panel='validation'", [runID])
            for (i, seed) in seeds.enumerated() {
                try sql.insert("ga_study_seed", "run_id,panel,ordinal,seed", [runID,"validation",i,String(seed)])
            }
        }
    }
    public func workerConfiguration() throws -> GeneticWorkerConfiguration {
        let id = try runID(), context = try store.context(id)
        guard try ["genetic-v8", "genetic-v9", "genetic-v10", "genetic-v11", "genetic-v12", "genetic-v13"].contains(sql.one("SELECT algorithm FROM ga_study WHERE run_id=?", [id]).string("algorithm")) else {
            throw sql.error("unsupported study algorithm")
        }
        let row = try sql.one("SELECT * FROM ga_study JOIN ga_run USING(run_id) WHERE run_id=?", [id])
        guard let heroes = context.heroLoadout else { throw row.invalid("heroes_enabled") }
        return try GeneticWorkerConfiguration(runID: id, levelID: context.levelID, contentSHA256: row.string("snapshot_sha256"),
            executableSHA256: row.string("executable_sha256"), bountyFraction: context.bountyFraction,
            money: context.startingMoney, maxSeconds: context.maxGameSeconds, heroLoadout: heroes)
    }
    public func seeds(runID: UUID, panel: GeneticSolutionPanel) throws -> [UInt64] {
        let row = try sql.one("SELECT training_seeds,validation_seeds FROM ga_study WHERE run_id=?", [runID])
        return try store.ordered("SELECT * FROM ga_study_seed WHERE run_id=? AND panel=? ORDER BY ordinal", [runID, panel.rawValue],
            count: row.int(panel == .training ? "training_seeds" : "validation_seeds")).map { try $0.seed("seed") }
    }
    public func options(runID: UUID) throws -> GeneticStudyOptions {
        let r = try sql.one("SELECT * FROM ga_study WHERE run_id=?", [runID]), context = try store.context(runID)
        var o = GeneticStudyOptions()
        o.stopping = nil
        if !(try sql.rows("SELECT name FROM sqlite_master WHERE name='ga_stopping_policy'")).isEmpty,
           let policy = try sql.rows("SELECT * FROM ga_stopping_policy WHERE run_id=?", [runID]).first {
            var value = GeneticStoppingPolicy()
            value.minimumTrainingBattles = try policy.int("minimum_training_battles")
            value.stabilityBattles = try policy.int("stability_battles")
            value.stabilityGenerations = try policy.int("stability_generations")
            value.solutions = try policy.int("solutions")
            try value.validate(); o.stopping = value
        }
        o.money = context.startingMoney; o.bountyFraction = context.bountyFraction; o.maxGameSeconds = context.maxGameSeconds
        o.workers = try r.int("workers"); o.population = try r.int("population"); o.generations = try r.int("generations")
        o.trainingSeeds = try r.int("training_seeds"); o.validationSeeds = try r.int("validation_seeds"); o.finalists = try r.int("finalists")
        o.maxEvaluations = try r.int("max_evaluations"); o.hours = try r.double("hours"); o.seed = try r.seed("search_seed")
        o.starMinimum = try r.isNull("star_minimum") ? nil : r.int("star_minimum"); o.starMaximum = try r.isNull("star_maximum") ? nil : r.int("star_maximum")
        o.starStep = try r.int("star_step"); o.fixedMeta = try r.bool("fixed_meta"); o.earlyWaveCalls = try r.bool("early_wave_calls")
        o.metaSelections = try r.int("meta_selections"); o.minimumMetaCandidates = try r.int("minimum_meta_candidates")
        o.metaAdaptationGenerations = try r.int("meta_adaptation_generations")
        o.heroAIEnabled = try r.isNull("hero_ai_override") ? nil : r.bool("hero_ai_override")
        o.selectedHeroIDs = try r.bool("selected_heroes_overridden") ? context.heroLoadout?.selectedHeroIDs : nil
        let limits = try sql.rows("SELECT * FROM ga_tower_limit WHERE run_id=?", [runID])
        let majority: TowerKind?
        if try r.isNull("majority_tower_kind") { majority = nil }
        else {
            guard let value = TowerKind(rawValue: try r.string("majority_tower_kind")) else { throw r.invalid("majority_tower_kind") }; majority = value
        }
        o.towerLimits = try .init(maximumByKind: Dictionary(uniqueKeysWithValues: limits.map { try ($0.string("tower_kind"), $0.int("maximum")) }), majorityKind: majority)
        o.seedStrategies = try store.ordered("SELECT * FROM ga_input_strategy WHERE run_id=? AND role='seed' ORDER BY ordinal", [runID]).map { try store.strategy($0.int64("strategy_id")) }
        let exchanges = try sql.rows("SELECT * FROM ga_input_strategy WHERE run_id=? AND role='exchange'", [runID])
        guard exchanges.count <= 1 else { throw r.invalid("exchange strategy") }
        o.metaExchangeFrom = try exchanges.first.map { try store.strategy($0.int64("strategy_id")) }
        return o
    }
    public func insert(_ candidates: [GeneticCandidate], runID: UUID, panel: GeneticSolutionPanel, expectedSamples: Int,
                       completed: Int, rate: Double) throws {
        guard !candidates.isEmpty else { return }
        try sql.transaction {
            for candidate in candidates { try store.saveCandidate(candidate, runID: runID, panel: panel, expected: expectedSamples) }
            try sql.execute("UPDATE simulator_run SET completed_iterations=?,iterations_per_second=?,updated_at=? WHERE id=? AND status='running'",
                [completed, rate, ISO8601DateFormatter().string(from: Date()), runID])
            guard sql.changes == 1 else { throw sql.error("study progress row is missing or not running") }
        }
    }
    public func bestTrainingCandidates(runID: UUID, seeds: [UInt64], limit: Int) throws -> [GeneticCandidate] {
        guard limit > 0, !seeds.isEmpty, Set(seeds).count == seeds.count else { throw sql.error("invalid training seeds/limit") }
        let candidates = try sql.rows("SELECT candidate_id FROM ga_panel WHERE run_id=? AND panel='training'", [runID]).map { row in
            let c = try store.candidate(runID: runID, candidateID: row.int("candidate_id"), panel: .training)
            guard c.evaluations.map(\.seed) == seeds else { throw row.invalid("training seed panel") }; return c
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        var seen: Set<Data> = [], selected: [GeneticCandidate] = []
        for c in GeneticCandidate.ranked(candidates) {
            if try seen.insert(encoder.encode(c.strategy)).inserted { selected.append(c) }
            if selected.count == limit { break }
        }
        return selected
    }
    public func checkpoint(runID: UUID, populations: [Int: GeneticMetaPopulation], generations: Int, nextID: Int, cacheHits: Int) throws {
        // Append population membership once. Rewriting every historical candidate
        // every generation makes long searches quadratic in database writes.
        var saved = checkpointMembers
        try sql.transaction {
            try sql.execute("""
                INSERT INTO ga_checkpoint VALUES(?,?,?,?) ON CONFLICT(run_id) DO UPDATE SET
                completed_generations=excluded.completed_generations,
                next_candidate_id=excluded.next_candidate_id,cache_hits=excluded.cache_hits
                """, [runID,generations,nextID,cacheHits])
            for stars in populations.keys.sorted() {
                let group = populations[stars]!
                for (i, selection) in group.selections.enumerated() {
                    let key: [Any?] = [runID, stars, selection.key]
                    try sql.execute("""
                        INSERT INTO ga_population_selection VALUES(?,?,?,?,?,?,?,?)
                        ON CONFLICT(run_id,stars_used,selection_key) DO UPDATE SET
                        ordinal=excluded.ordinal,active=excluded.active
                        """, key + [i, selection.introducedGeneration, selection.active, group.plansPerSelection, group.minimumCandidates])
                    for upgrade in selection.upgrades.upgrades {
                        try sql.execute("INSERT OR IGNORE INTO ga_population_upgrade VALUES(?,?,?,?)", key + [upgrade.rawValue])
                    }
                    for niche in selection.behaviorChampions.keys.sorted() {
                        try sql.execute("INSERT OR REPLACE INTO ga_population_niche VALUES(?,?,?,?,?,?)",
                            key + [niche, selection.behaviorChampions[niche]!.id, selection.breedingVisits[niche, default: 0]])
                    }
                    let cacheKey = "\(runID)/\(stars)/\(selection.key)"
                    let count: Int
                    if let previous = saved[cacheKey] { count = previous }
                    else {
                        count = try sql.one("SELECT COUNT(*) AS count FROM ga_population_member WHERE run_id=? AND stars_used=? AND selection_key=?",key).int("count")
                    }
                    guard count <= selection.candidates.count else { throw sql.error("population evidence cannot shrink") }
                    for candidate in selection.candidates.dropFirst(count) {
                        try sql.insert("ga_population_member", "run_id,stars_used,selection_key,candidate_id,archive_ordinal", key + [candidate.id, nil])
                    }
                    try sql.execute("UPDATE ga_population_member SET archive_ordinal=NULL WHERE run_id=? AND stars_used=? AND selection_key=? AND archive_ordinal IS NOT NULL",key)
                    for (ordinal,candidate) in selection.archive.enumerated() {
                        try sql.execute("UPDATE ga_population_member SET archive_ordinal=? WHERE run_id=? AND stars_used=? AND selection_key=? AND candidate_id=?",
                            [ordinal] + key + [candidate.id])
                        guard sql.changes == 1 else { throw sql.error("archive candidate missing from population evidence") }
                    }
                    saved[cacheKey] = selection.candidates.count
                }
            }
        }
        checkpointMembers = saved // A failed transaction must not advance the append cursor.
    }
    public func saveProgress(_ p: GeneticProgress.Snapshot) throws {
        try sql.transaction {
            try sql.execute("DELETE FROM ga_progress WHERE run_id=?", [p.runID])
            try sql.insert("ga_progress", "run_id,phase,percent_complete,elapsed_seconds,estimated_seconds_remaining,completed_generations,training_evaluations,validation_evaluations",
                [p.runID,p.phase.rawValue,p.percentComplete,p.elapsedSeconds,p.estimatedSecondsRemaining,p.completedGenerations,p.trainingEvaluations,p.validationEvaluations])
            for (i,m) in p.milestones.enumerated() { try sql.insert("ga_progress_milestone", "run_id,ordinal,percent,elapsed_seconds", [p.runID,i,m.percent,m.elapsedSeconds]) }
        }
    }
    public func progress() throws -> GeneticProgress.Snapshot {
        let r = try sql.one("SELECT * FROM ga_progress"), id = try r.uuid("run_id")
        guard let phase = GeneticProgress.Phase(rawValue: try r.string("phase")) else { throw r.invalid("phase") }
        let milestones = try store.ordered("SELECT * FROM ga_progress_milestone WHERE run_id=? ORDER BY ordinal", [id])
        return try .init(runID: id, phase: phase, percentComplete: r.double("percent_complete"), elapsedSeconds: r.double("elapsed_seconds"),
            estimatedSecondsRemaining: r.isNull("estimated_seconds_remaining") ? nil : r.double("estimated_seconds_remaining"),
            completedGenerations: r.int("completed_generations"), trainingEvaluations: r.int("training_evaluations"), validationEvaluations: r.int("validation_evaluations"),
            milestones: milestones.map { try .init(percent: $0.int("percent"), elapsedSeconds: $0.double("elapsed_seconds")) })
    }
    public func geneticSummaryByStars(runID: UUID) throws -> [[String: Any]] {
        // Distinct selections compare relational upgrade sets, encoded only as
        // a transient GROUP_CONCAT key. No JSON columns or stored packed sets.
        let rows = try sql.rows("""
            SELECT stars_used, panel, COUNT(*) AS candidates,SUM(samples) AS engine_games,
                   SUM(victories) AS victories,SUM(defeats) AS defeats,SUM(timeouts) AS timeouts,
                   COUNT(DISTINCT COALESCE((SELECT group_concat(upgrade_id,',') FROM
                       (SELECT upgrade_id FROM ga_meta_upgrade u WHERE u.strategy_id=f.strategy_id ORDER BY upgrade_id)),'')) AS meta_loadouts
            FROM ga_candidate_fitness f WHERE run_id=? GROUP BY stars_used,panel ORDER BY stars_used,panel
            """, [runID])
        return try rows.map { r in
            try ["starsUsed": r.int("stars_used"), "panel": r.string("panel") == "training" ? 0 : 1,
             "candidates": r.int("candidates"), "engineGames": r.int("engine_games"), "victories": r.int("victories"),
             "defeats": r.int("defeats"), "timeouts": r.int("timeouts"), "metaLoadoutsTested": r.int("meta_loadouts")]
        }
    }
    public func saveSummary(runID: UUID, stopReason: String, validationComplete: Bool, evaluationSeconds: Double,
                            recordingSeconds: Double, totalSeconds: Double, cacheHits: Int, generations: Int,
                            candidates: Int, recordings: Int) throws {
        try sql.execute("INSERT OR REPLACE INTO ga_summary VALUES(?,?,?,?,?,?,?,?,?,?)",
            [runID,stopReason,validationComplete,evaluationSeconds,recordingSeconds,totalSeconds,cacheHits,generations,candidates,recordings])
    }
    public func finish(runID: UUID, completed: Int) throws {
        // Final publication copies the final qualification panel to the study.
        // Count actual battles once, including every rejected blind assessment.
        let attempts = try sql.one("SELECT COUNT(*) AS count FROM ga_qualification WHERE study_run_id=?", [runID]).int("count")
        let row = try attempts == 0
            ? sql.one("SELECT COUNT(*) AS count FROM ga_evaluation WHERE run_id=?", [runID])
            : sql.one("""
                SELECT COUNT(*) AS count FROM ga_evaluation
                WHERE (run_id=? AND panel='training') OR run_id IN
                    (SELECT evidence_run_id FROM ga_qualification WHERE study_run_id=?)
                """, [runID,runID])
        guard try row.int("count") == completed else { throw row.invalid("persisted evaluation count") }
        let now = ISO8601DateFormatter().string(from: Date())
        try sql.execute("UPDATE simulator_run SET status='completed',total_iterations=?,completed_iterations=?,updated_at=?,finished_at=?,report_path=? WHERE id=? AND status='running'",
            [completed,completed,now,now,db.path,runID])
        guard sql.changes == 1 else { throw sql.error("study completion row is missing or not running") }
    }
}
