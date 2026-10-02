import Foundation

extension GeneticStore {
    func playstyle(evaluationID: Int64) throws -> GeneticPlaystyle? {
        guard hasPlaystyleStorage,
              let r = try sql.rows("SELECT * FROM ga_playstyle WHERE evaluation_id=?", [evaluationID]).first else { return nil }
        let purchases = try ordered("SELECT * FROM ga_playstyle_purchase WHERE evaluation_id=? ORDER BY ordinal", [evaluationID], count: r.int("purchase_count")).map { p in
            try GeneticPlaystyle.Purchase(seconds: p.double("seconds"), wave: p.int("wave"), slot: p.int("slot"),
                familyID: p.uuid("family_id"), tierID: p.uuid("tier_id"), action: p.string("action"),
                pathID: p.isNull("path_id") ? nil : p.string("path_id"), cost: p.int("cost"))
        }
        let towers = try ordered("SELECT * FROM ga_playstyle_tower WHERE evaluation_id=? ORDER BY ordinal", [evaluationID], count: r.int("tower_count")).map { t in
            let routes = try ordered("SELECT * FROM ga_playstyle_route WHERE evaluation_id=? AND tower_ordinal=? ORDER BY ordinal", [evaluationID, t.int("ordinal")], count: t.int("route_count")).map {
                try GeneticPlaystyle.Tower.Route(index: $0.int("route_index"), progress: $0.double("progress"))
            }
            var tower = try GeneticPlaystyle.Tower(phase: t.int("phase"), seconds: t.double("seconds"), slot: t.int("slot"),
                familyID: t.uuid("family_id"), tierID: t.uuid("tier_id"), level: t.int("level"), branch: t.int("branch"),
                attackMode: t.string("attack_mode"), spent: t.int("spent"), damage: t.double("damage"), shots: t.int("shots"),
                blockingSeconds: t.double("blocking_seconds"), income: t.int("income"), detonations: t.int("detonations"), routes: routes)
            if t.fields["slowing_seconds"] != nil, try !t.isNull("slowing_seconds") {
                tower.slowingSeconds = try t.double("slowing_seconds")
            }
            return tower
        }
        return try GeneticPlaystyle(duration: r.double("duration"), purchases: purchases, towers: towers,
            reinforcementActions: r.int("reinforcement_actions"), earlyWaveActions: r.int("early_wave_actions"),
            demolitionActions: r.int("demolition_actions"), startingLives: r.int("starting_lives"), minimumLives: r.int("minimum_lives"))
    }
    func savePlaystyle(_ p: GeneticPlaystyle, evaluationID id: Int64) throws {
        guard hasPlaystyleStorage else { throw sql.error("missing ga_playstyle schema; rebuild starter from authored SQL") }
        try sql.insert("ga_playstyle", "evaluation_id,duration,purchase_count,tower_count,reinforcement_actions,early_wave_actions,demolition_actions,starting_lives,minimum_lives",
            [id,p.duration,p.purchases.count,p.towers.count,p.reinforcementActions,p.earlyWaveActions,p.demolitionActions,p.startingLives,p.minimumLives])
        for (i,p) in p.purchases.enumerated() {
            try sql.insert("ga_playstyle_purchase", "evaluation_id,ordinal,seconds,wave,slot,family_id,tier_id,action,path_id,cost",
                [id,i,p.seconds,p.wave,p.slot,p.familyID,p.tierID,p.action,p.pathID,p.cost])
        }
        for (i,t) in p.towers.enumerated() {
            try sql.insert("ga_playstyle_tower", "evaluation_id,ordinal,phase,seconds,slot,family_id,tier_id,level,branch,attack_mode,spent,damage,shots,blocking_seconds,income,detonations,route_count,slowing_seconds",
                [id,i,t.phase,t.seconds,t.slot,t.familyID,t.tierID,t.level,t.branch,t.attackMode,t.spent,t.damage,t.shots,t.blockingSeconds,t.income,t.detonations,t.routes.count,t.slowingSeconds])
            for (j,r) in t.routes.enumerated() {
                try sql.insert("ga_playstyle_route", "evaluation_id,tower_ordinal,ordinal,route_index,progress", [id,i,j,r.index,r.progress])
            }
        }
    }
}
