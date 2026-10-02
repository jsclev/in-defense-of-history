import Foundation

/// Relational GA DNA and original evidence. All calculations remain in the
/// existing GeneticCandidate/GeneticFitness and shared battle engine.
final class GeneticStore {
    let sql: GeneticSQL
    let hasPlacementStorage: Bool
    let hasPlaystyleStorage: Bool
    let hasTacticalStorage: Bool
    init(conn: OpaquePointer?) throws {
        sql = try GeneticSQL(conn)
        hasTacticalStorage = try !sql.rows("SELECT name FROM sqlite_master WHERE name='ga_tactical_order'").isEmpty
        hasPlacementStorage = try !sql.rows("SELECT name FROM sqlite_master WHERE name='ga_placement_plan'").isEmpty
        hasPlaystyleStorage = try !sql.rows("SELECT name FROM sqlite_master WHERE name='ga_playstyle'").isEmpty
    }
    func placementPlan(evaluationID: Int64) throws -> GeneticPlacementPlan? {
        guard hasPlacementStorage,
              let row = try sql.rows("SELECT * FROM ga_placement_plan WHERE evaluation_id=?", [evaluationID]).first else { return nil }
        func placements(_ phase: String) throws -> [GeneticPlacementPlan.Placement] {
            try ordered("SELECT * FROM ga_placement WHERE evaluation_id=? AND phase=? ORDER BY ordinal",
                [evaluationID, phase], count: row.int(phase + "_count")).map {
                    try .init(slot: $0.int("slot"), towerID: $0.uuid("tower_id"))
                }
        }
        var plan = try GeneticPlacementPlan(initial: placements("initial"), subsequent: placements("subsequent"),
            sourceRecordingID: row.isNull("source_recording_id") ? nil : row.uuid("source_recording_id"))
        plan.playstyle = try playstyle(evaluationID: evaluationID)
        return plan
    }
    func savePlacementPlan(_ plan: GeneticPlacementPlan, evaluationID: Int64) throws {
        guard hasPlacementStorage else { throw sql.error("missing ga_placement_plan schema; rebuild the starter from authored SQL") }
        try sql.insert("ga_placement_plan", "evaluation_id,initial_count,subsequent_count,source_recording_id",
            [evaluationID, plan.initial.count, plan.subsequent.count, plan.sourceRecordingID])
        for (phase, placements) in [("initial", plan.initial), ("subsequent", plan.subsequent)] {
            for (ordinal, placement) in placements.enumerated() {
                try sql.insert("ga_placement", "evaluation_id,phase,ordinal,slot,tower_id",
                    [evaluationID, phase, ordinal, placement.slot, placement.towerID])
            }
        }
        if let profile = plan.playstyle { try savePlaystyle(profile, evaluationID: evaluationID) }
    }

    func ensureRun(_ record: GeneticSolution) throws {
        try ensureRun(runID: record.runID, context: record.context, executableSHA256: record.executableSHA256,
                      formatVersion: record.formatVersion, heroesEnabled: record.heroesEnabled)
    }
    func ensureRun(runID: UUID, context: GeneticSolutionContext, executableSHA256: String,
                   formatVersion: Int = 2, heroesEnabled: Bool = true) throws {
        if !(try sql.rows("SELECT run_id FROM ga_run WHERE run_id=?", [runID])).isEmpty {
            let old = try self.context(runID)
            let row = try sql.one("SELECT * FROM ga_run WHERE run_id=?", [runID])
            guard old == context, try row.string("executable_sha256") == executableSHA256,
                  try row.int("format_version") == formatVersion, try row.bool("heroes_enabled") == heroesEnabled else {
                throw DbError.Db(message: "ga_run[\(runID)]: context or executable changed")
            }
            return
        }
        let c = context
        try sql.insert("ga_run", "run_id,format_version,executable_sha256,level_info_id,difficulty_id,starting_money,bounty_fraction,max_game_seconds,content_sha256,heroes_enabled",
            [runID, formatVersion, executableSHA256, c.levelID.uuidString.lowercased(), c.difficultyID.uuidString.lowercased(),
             c.startingMoney, c.bountyFraction, c.maxGameSeconds, c.contentSHA256, heroesEnabled])
        if let heroes = c.heroLoadout {
            for (ordinal, id) in heroes.selectedHeroIDs.enumerated() {
                let position = heroes.deployments.firstIndex { $0.heroID == id }
                let deployment = position.map { heroes.deployments[$0] }
                try sql.insert("ga_hero", "run_id,ordinal,hero_id,deployment_ordinal,role,spawn_feature_id,x,y,ai_enabled",
                    [runID, ordinal, id, position, deployment?.role.rawValue, deployment?.spawnFeatureID,
                     deployment?.position.x, deployment?.position.y, deployment?.aiEnabled])
            }
        }
    }
    func heroes(_ runID: UUID) throws -> GeneticHeroLoadout? {
        let run = try sql.one("SELECT heroes_enabled FROM ga_run WHERE run_id=?", [runID])
        let rows = try ordered("SELECT * FROM ga_hero WHERE run_id=? ORDER BY ordinal", [runID])
        if try !run.bool("heroes_enabled") {
            guard rows.isEmpty else { throw run.invalid("heroes_enabled") }; return nil
        }
        let deployments: [(Int, GeneticHeroLoadout.Deployment)] = try rows.compactMap { row -> (Int, GeneticHeroLoadout.Deployment)? in
            if try row.isNull("deployment_ordinal") { return nil }
            guard let role = HeroSelection.Role(rawValue: try row.string("role")) else { throw row.invalid("role") }
            return (try row.int("deployment_ordinal"), try GeneticHeroLoadout.Deployment(heroID: row.uuid("hero_id"), role: role,
                spawnFeatureID: row.string("spawn_feature_id"), position: Point(row.double("x"), row.double("y")), aiEnabled: row.bool("ai_enabled")))
        }
        let sorted = deployments.sorted { $0.0 < $1.0 }
        guard sorted.enumerated().allSatisfy({ $0.offset == $0.element.0 }) else { throw run.invalid("deployment_ordinal") }
        return try GeneticHeroLoadout(selectedHeroIDs: rows.map { try $0.uuid("hero_id") }, deployments: sorted.map(\.1))
    }
    func context(_ runID: UUID) throws -> GeneticSolutionContext {
        let r = try sql.one("SELECT * FROM ga_run WHERE run_id=?", [runID])
        let context = try GeneticSolutionContext(levelID: r.uuid("level_info_id"), difficultyID: r.uuid("difficulty_id"),
            startingMoney: r.int("starting_money"), bountyFraction: r.double("bounty_fraction"),
            maxGameSeconds: r.double("max_game_seconds"), contentSHA256: r.string("content_sha256"), heroLoadout: heroes(runID))
        try context.validate(); return context
    }
    func ordered(_ query: String, _ args: [Any?], count: Int? = nil) throws -> [GeneticSQL.Row] {
        let rows = try sql.rows(query, args)
        guard count == nil || rows.count == count else { throw sql.error("missing child rows: \(query)") }
        for (i, row) in rows.enumerated() where try row.int("ordinal") != i { throw row.invalid("ordinal") }
        return rows
    }
    func checked(_ query: String, _ args: [Any?], count: Int) throws -> [GeneticSQL.Row] {
        let rows = try sql.rows(query, args)
        guard rows.count == count else { throw sql.error("missing child rows: \(query)") }; return rows
    }

    @discardableResult func insertStrategy(_ strategy: GeneticStrategy, runID: UUID) throws -> Int64 {
        try strategy.reinforcements.validate()
        let priority: String, x: Double?, y: Double?
        switch strategy.reinforcements.priority {
        case .nearestExit: priority = "nearestExit"; x = nil; y = nil
        case let .nearPoint(point): priority = "nearPoint"; x = point.x; y = point.y
        }
        try sql.insert("ga_strategy", "run_id,reinforcement_priority,reinforcement_x,reinforcement_y,reinforcement_hold_seconds,decision_count,meta_upgrade_count,early_wave_count,tactical_count",
            [runID, priority, x, y, strategy.reinforcements.holdSeconds, strategy.decisions.count, strategy.metaUpgrades.count, strategy.earlyWaves.decisions.count, strategy.tactics.count])
        let id = sql.lastID
        for (i, order) in strategy.tactics.enumerated() {
            try sql.insert("ga_tactical_order", "strategy_id,ordinal,slot,kind,path_index,progress",
                [id, i, order.slot, order.kind.rawValue, order.pathIndex, order.progress])
        }
        for (i, decision) in strategy.decisions.enumerated() {
            let action: String, tower: String?, path: String?
            switch decision.step.action {
            case let .build(_, value): action = "build"; tower = value.uuidString; path = nil
            case .upgrade: action = "upgrade"; tower = nil; path = nil
            case let .purchaseUpgrade(_, value): action = "purchaseUpgrade"; tower = nil; path = value
            }
            try sql.insert("ga_decision", "strategy_id,ordinal,seconds,earliest_wave,save_for_purchase,action,slot,tower_id,upgrade_path_id",
                [id, i, decision.step.time, decision.earliestWave, decision.saveForPurchase, action, decision.step.action.slot, tower, path])
        }
        for (i, upgrade) in strategy.metaUpgrades.enumerated() {
            try sql.insert("ga_meta_upgrade", "strategy_id,ordinal,upgrade_id", [id, i, upgrade.rawValue])
        }
        for (i, decision) in strategy.earlyWaves.decisions.enumerated() {
            let policy: String, seconds: Double?, countdown: Int?, enemies: Int?
            switch decision.policy {
            case .automatic: policy = "automatic"; seconds = nil; countdown = nil; enemies = nil
            case let .afterVisible(value): policy = "afterVisible"; seconds = value; countdown = nil; enemies = nil
            case let .whenCountdownAtMost(value): policy = "whenCountdownAtMost"; seconds = nil; countdown = value; enemies = nil
            case let .whenEnemiesAtMost(count, hold): policy = "whenEnemiesAtMost"; seconds = hold; countdown = nil; enemies = count
            }
            try sql.insert("ga_early_wave", "strategy_id,ordinal,wave,policy,seconds,countdown_seconds,enemy_count", [id, i, decision.wave, policy, seconds, countdown, enemies])
        }
        return id
    }
    func strategy(_ id: Int64) throws -> GeneticStrategy {
        let r = try sql.one("SELECT * FROM ga_strategy WHERE strategy_id=?", [id])
        let priority: ReinforcementStrategy.Priority
        switch try r.string("reinforcement_priority") {
        case "nearestExit": priority = .nearestExit
        case "nearPoint": priority = try .nearPoint(Point(r.double("reinforcement_x"), r.double("reinforcement_y")))
        default: throw r.invalid("reinforcement_priority")
        }
        let decisions = try ordered("SELECT * FROM ga_decision WHERE strategy_id=? ORDER BY ordinal", [id], count: r.int("decision_count")).map { row -> GeneticStrategy.Decision in
            let action: ScriptedBuildOrder.Action, slot = try row.int("slot")
            switch try row.string("action") {
            case "build": action = try .build(slot: slot, towerID: row.uuid("tower_id"))
            case "upgrade": action = .upgrade(slot: slot)
            case "purchaseUpgrade": action = try .purchaseUpgrade(slot: slot, pathID: row.string("upgrade_path_id"))
            default: throw row.invalid("action")
            }
            return try .init(step: .init(time: row.double("seconds"), action: action), earliestWave: row.int("earliest_wave"), saveForPurchase: row.bool("save_for_purchase"))
        }
        let upgrades = try ordered("SELECT * FROM ga_meta_upgrade WHERE strategy_id=? ORDER BY ordinal", [id], count: r.int("meta_upgrade_count")).map { row -> MetaUpgrade in
            guard let upgrade = MetaUpgrade(rawValue: try row.string("upgrade_id")) else { throw row.invalid("upgrade_id") }; return upgrade
        }
        let early = try ordered("SELECT * FROM ga_early_wave WHERE strategy_id=? ORDER BY ordinal", [id], count: r.int("early_wave_count")).map { row -> EarlyWaveStrategy.Decision in
            let policy: EarlyWaveStrategy.Policy
            switch try row.string("policy") {
            case "automatic": policy = .automatic
            case "afterVisible": policy = try .afterVisible(seconds: row.double("seconds"))
            case "whenCountdownAtMost": policy = try .whenCountdownAtMost(seconds: row.int("countdown_seconds"))
            case "whenEnemiesAtMost": policy = try .whenEnemiesAtMost(count: row.int("enemy_count"), holdSeconds: row.double("seconds"))
            default: throw row.invalid("policy")
            }
            return try .init(wave: row.int("wave"), policy: policy)
        }
        let catalog = try MetaUpgradeDAO(conn: sql.conn).get()
        let value = try GeneticStrategy(decisions: decisions, metaProgression: MetaUpgradesFactory.restore(upgrades, catalog: catalog),
            reinforcements: .init(priority: priority, holdSeconds: r.double("reinforcement_hold_seconds")), earlyWaves: .init(decisions: early), tactics: tacticalOrders(strategyID: id, row: r))
        try value.reinforcements.validate()
        return value
    }

    func saveCandidate(_ candidate: GeneticCandidate, runID: UUID, panel: GeneticSolutionPanel, expected: Int) throws {
        guard !candidate.evaluations.isEmpty, candidate.evaluations.count <= expected,
              Set(candidate.evaluations.map(\.seed)).count == candidate.evaluations.count else {
            throw sql.error("candidate \(candidate.id): invalid evaluation panel")
        }
        let key: [Any?] = [runID, candidate.id]
        let previous = try sql.rows("SELECT * FROM ga_candidate WHERE run_id=? AND candidate_id=?", key)
        if let row = previous.first {
            guard try row.int("generation") == candidate.generation, try row.int("stars_used") == candidate.starsUsed,
                  try strategy(row.int64("strategy_id")) == candidate.strategy else {
                throw sql.error("candidate \(candidate.id): DNA changed")
            }
        } else {
            let strategyID = try insertStrategy(candidate.strategy, runID: runID)
            try sql.insert("ga_candidate", "run_id,candidate_id,generation,stars_used,strategy_id", key + [candidate.generation, candidate.starsUsed, strategyID])
        }
        let panelKey = key + [panel.rawValue]
        let panels = try sql.rows("SELECT * FROM ga_panel WHERE run_id=? AND candidate_id=? AND panel=?", panelKey)
        var existing = 0
        if let old = panels.first {
            let samples = try evaluations(runID: runID, candidateID: candidate.id, panel: panel)
            existing = samples.count
            guard try old.int("expected_samples") == expected, candidate.evaluations.count >= existing,
                  zip(samples, candidate.evaluations).allSatisfy({ Self.exact($0.0, $0.1) }) else {
                throw sql.error("candidate \(candidate.id): panel shrank or original evaluation changed")
            }
            try sql.execute("UPDATE ga_panel SET sample_count=? WHERE run_id=? AND candidate_id=? AND panel=?", [candidate.evaluations.count] + panelKey)
        } else {
            try sql.insert("ga_panel", "run_id,candidate_id,panel,expected_samples,sample_count", panelKey + [expected, candidate.evaluations.count])
        }
        for ordinal in existing..<candidate.evaluations.count {
            try insertEvaluation(candidate.evaluations[ordinal], key: panelKey, ordinal: ordinal)
        }
    }
    static func exact(_ lhs: GeneticEvaluation, _ rhs: GeneticEvaluation) -> Bool {
        lhs == rhs && lhs.runID == rhs.runID && lhs.builtTowersByKind == rhs.builtTowersByKind && lhs.placementPlan == rhs.placementPlan && lhs.tacticalActions == rhs.tacticalActions
    }
    private func insertEvaluation(_ e: GeneticEvaluation, key: [Any?], ordinal: Int) throws {
        let r = e.result
        try sql.insert("ga_evaluation", "run_id,candidate_id,panel,ordinal,seed,level_run_id,outcome,seconds,lives_remaining,gold_remaining,gold_earned,killed,leaked,waves_started,built_towers_known,fate_count,progress_count,leak_count,economy_count,reinforcement_count,wave_call_count,built_tower_count,tactical_count",
            key + [ordinal, String(e.seed), e.runID, r.outcome.rawValue, r.seconds, r.livesRemaining, r.goldRemaining, r.goldEarned, r.killed, r.leaked,
                   e.wavesStarted, e.builtTowersByKind != nil, r.fatesByTypeID.count, r.waveMaxProgress.count, r.leaksByWave.count,
                   e.waveEconomy.count, e.reinforcementDeployments.count, e.waveCalls.count, e.builtTowersByKind?.count ?? 0, e.tacticalActions?.count])
        let id = sql.lastID
        if let plan = e.placementPlan { try savePlacementPlan(plan, evaluationID: id) }
        for (i, action) in (e.tacticalActions ?? []).enumerated() {
            try sql.insert("ga_tactical_action", "evaluation_id,ordinal,seconds,wave,slot,kind,x,y",
                [id, i, action.seconds, action.wave, action.slot, action.kind.rawValue, action.point.x, action.point.y])
        }
        for (type, fate) in r.fatesByTypeID {
            try sql.insert("ga_enemy_fate", "evaluation_id,enemy_type_id,killed,leaked", [id, type, fate.killed, fate.leaked])
        }
        for (i, value) in r.waveMaxProgress.enumerated() { try sql.insert("ga_wave_progress", "evaluation_id,ordinal,max_progress", [id, i, value]) }
        for (i, value) in r.leaksByWave.enumerated() { try sql.insert("ga_wave_leak", "evaluation_id,ordinal,leaked", [id, i, value]) }
        for (i, value) in e.waveEconomy.enumerated() {
            try sql.insert("ga_wave_economy", "evaluation_id,ordinal,wave,seconds,money,lives", [id, i, value.wave, value.seconds, value.money, value.lives])
        }
        for (i, value) in e.reinforcementDeployments.enumerated() {
            try sql.insert("ga_reinforcement_deployment", "evaluation_id,ordinal,seconds,wave,x,y", [id, i, value.seconds, value.wave, value.point.x, value.point.y])
        }
        for (i, value) in e.waveCalls.enumerated() {
            try sql.insert("ga_wave_call", "evaluation_id,ordinal,seconds,wave,countdown_seconds,early_call_bonus,money_before,money_after",
                [id, i, value.seconds, value.wave, value.countdownSeconds, value.earlyCallBonus, value.moneyBefore, value.moneyAfter])
        }
        for (kind, count) in e.builtTowersByKind ?? [:] { try sql.insert("ga_built_tower", "evaluation_id,tower_kind,count", [id, kind, count]) }
    }
    func evaluations(runID: UUID, candidateID: Int, panel: GeneticSolutionPanel) throws -> [GeneticEvaluation] {
        let args: [Any?] = [runID, candidateID, panel.rawValue]
        let p = try sql.one("SELECT * FROM ga_panel WHERE run_id=? AND candidate_id=? AND panel=?", args)
        return try ordered("SELECT * FROM ga_evaluation WHERE run_id=? AND candidate_id=? AND panel=? ORDER BY ordinal", args, count: p.int("sample_count")).map { r in
            let id = try r.int64("evaluation_id")
            let fates = try checked("SELECT * FROM ga_enemy_fate WHERE evaluation_id=?", [id], count: r.int("fate_count"))
            let progress = try ordered("SELECT * FROM ga_wave_progress WHERE evaluation_id=? ORDER BY ordinal", [id], count: r.int("progress_count"))
            let leaks = try ordered("SELECT * FROM ga_wave_leak WHERE evaluation_id=? ORDER BY ordinal", [id], count: r.int("leak_count"))
            let economy = try ordered("SELECT * FROM ga_wave_economy WHERE evaluation_id=? ORDER BY ordinal", [id], count: r.int("economy_count"))
            let reinforcements = try ordered("SELECT * FROM ga_reinforcement_deployment WHERE evaluation_id=? ORDER BY ordinal", [id], count: r.int("reinforcement_count"))
            let calls = try ordered("SELECT * FROM ga_wave_call WHERE evaluation_id=? ORDER BY ordinal", [id], count: r.int("wave_call_count"))
            let built = try checked("SELECT * FROM ga_built_tower WHERE evaluation_id=?", [id], count: r.int("built_tower_count"))
            guard let outcome = Outcome(rawValue: try r.string("outcome")) else { throw r.invalid("outcome") }
            let result = try SimulationResult(outcome: outcome, seconds: r.double("seconds"), livesRemaining: r.int("lives_remaining"),
                goldRemaining: r.int("gold_remaining"), goldEarned: r.int("gold_earned"), killed: r.int("killed"), leaked: r.int("leaked"),
                fatesByTypeID: Dictionary(uniqueKeysWithValues: fates.map { try ($0.uuid("enemy_type_id"), SimulationResult.TypeFates(killed: $0.int("killed"), leaked: $0.int("leaked"))) }),
                waveMaxProgress: progress.map { try $0.double("max_progress") }, leaksByWave: leaks.map { try $0.int("leaked") })
            return try GeneticEvaluation(runID: r.isNull("level_run_id") ? nil : r.uuid("level_run_id"),
                builtTowersByKind: r.bool("built_towers_known") ? Dictionary(uniqueKeysWithValues: built.map { try ($0.string("tower_kind"), $0.int("count")) }) : nil,
                placementPlan: placementPlan(evaluationID: id), tacticalActions: tacticalActions(evaluationID: id, row: r),
                seed: r.seed("seed"), result: result, wavesStarted: r.int("waves_started"),
                waveEconomy: economy.map { try .init(wave: $0.int("wave"), seconds: $0.double("seconds"), money: $0.int("money"), lives: $0.int("lives")) },
                reinforcementDeployments: reinforcements.map { try .init(seconds: $0.double("seconds"), wave: $0.int("wave"), point: .init($0.double("x"), $0.double("y"))) },
                waveCalls: calls.map { try .init(seconds: $0.double("seconds"), wave: $0.int("wave"), countdownSeconds: $0.isNull("countdown_seconds") ? nil : $0.int("countdown_seconds"),
                    earlyCallBonus: $0.int("early_call_bonus"), moneyBefore: $0.int("money_before"), moneyAfter: $0.int("money_after")) })
        }
    }
    func candidate(runID: UUID, candidateID: Int, panel: GeneticSolutionPanel) throws -> GeneticCandidate {
        let row = try sql.one("SELECT * FROM ga_candidate WHERE run_id=? AND candidate_id=?", [runID, candidateID])
        let value = try GeneticCandidate(id: candidateID, generation: row.int("generation"), strategy: strategy(row.int64("strategy_id")),
            evaluations: evaluations(runID: runID, candidateID: candidateID, panel: panel))
        guard try value.starsUsed == row.int("stars_used") else { throw row.invalid("stars_used") }; return value
    }
    func solution(runID: UUID, candidateID: Int, panel: GeneticSolutionPanel) throws -> GeneticSolution {
        let r = try sql.one("SELECT * FROM ga_run WHERE run_id=?", [runID])
        let p = try sql.one("SELECT * FROM ga_panel WHERE run_id=? AND candidate_id=? AND panel=?", [runID, candidateID, panel.rawValue])
        let value = try GeneticSolution(formatVersion: r.int("format_version"), runID: runID, executableSHA256: r.string("executable_sha256"),
            context: context(runID), heroesEnabled: r.bool("heroes_enabled"), panel: panel, expectedSamples: p.int("expected_samples"),
            candidate: candidate(runID: runID, candidateID: candidateID, panel: panel))
        try value.validate(); return value
    }
}
