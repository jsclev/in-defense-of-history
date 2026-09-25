import Foundation

/// Canonical authored-content identity shared by CLI and visible replays.
extension AuthoredMoneyStudy {
    public func replaySnapshot(db: Db, heroesEnabled: Bool = false) throws -> Data {
        let encoder = JSONEncoder()
        func json<T: Encodable>(_ value: T) throws -> Any {
            try JSONSerialization.jsonObject(with: encoder.encode(value))
        }
        let loadout = battle.playerUpgrades.loadout
        let upgrades: [[String: Any]] = loadout.catalog.upgrades.map { definition in
            ["id": definition.id.rawValue, "selected": loadout.selected.contains(definition.id),
             "title": definition.title, "starCost": definition.cost,
             "prerequisite": definition.prerequisite.map { $0.rawValue as Any } ?? NSNull(),
             "parameters": Dictionary(uniqueKeysWithValues: definition.parameters.map { ($0.key.rawValue, $0.value) })]
        }
        var content: [String: Any] = [
            "engine": "shared-game-engine", "level": try json(level),
            "mapGeoJSON": try JSONSerialization.jsonObject(with: db.levelGeoJSONDao.sourceData(mapImageName: level.mapImageName)),
            "unlocks": Dictionary(uniqueKeysWithValues: battle.unlocks.map { ($0.key.rawValue, $0.value) }),
            "canvas": try json(battle.virtualCanvas),
            "towers": try json(catalog.towerTypes),
            "enemies": try json(battle.enemies), "combatRules": try json(arsenal.combatRules),
            "difficulty": difficulty.name, "enemyHPMultiplier": difficulty.enemyHPMultiplier,
            "campaignUpgrades": upgrades, "heroes": heroesEnabled,
            "metaProgression": ["earnedStars": loadout.starBudget, "spentStars": loadout.spentStars,
                "availableStars": loadout.availableStars,
                "bestStarsByLevel": Dictionary(uniqueKeysWithValues: battle.playerUpgrades.bestStarsByLevel.map { ($0.key.uuidString, $0.value) })],
            "reinforcementConfig": ["cooldownSeconds": battle.reinforcementConfig.cooldownSeconds,
                "timeToLiveSeconds": battle.reinforcementConfig.timeToLiveSeconds]]
        if heroesEnabled {
            content["heroLoadout"] = try json(GeneticHeroLoadout(content: battle))
            content["selectedHeroRankings"] = battle.chosenHeroes.heroes.map {
                ["id": $0.id.uuidString, "ranking": $0.ranking] as [String: Any]
            }
            // Arrays follow deployment order; avoid non-String dictionary keys
            // whose Codable ordering is not stable across worker processes.
            content["heroContent"] = try battle.deployments.map { deployment -> [String: Any] in
                let id = deployment.hero.id
                guard let combat = battle.heroCombat[id], let ai = battle.heroAI[id] else {
                    throw DbError.Db(message: "hero[\(id)]: missing combat or AI configuration in genetic snapshot")
                }
                return ["id": id.uuidString, "combat": try json(combat),
                    "ai": ["controller": ai.controller.rawValue, "decisionInterval": ai.decisionInterval,
                        "retreatHealthFraction": ai.retreatHealthFraction, "resumeHealthFraction": ai.resumeHealthFraction]]
            }
        }
        return try JSONSerialization.data(withJSONObject: content, options: [.sortedKeys])
    }

}
