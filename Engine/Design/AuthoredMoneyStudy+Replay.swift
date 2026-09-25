import Foundation

/// Canonical authored-content identity shared by CLI and visible replays.
extension AuthoredMoneyStudy {
    public func replaySnapshot(db: Db) throws -> Data {
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
        let content: [String: Any] = [
            "engine": "shared-game-engine", "level": try json(level),
            "mapGeoJSON": try JSONSerialization.jsonObject(with: db.levelGeoJSONDao.sourceData(mapImageName: level.mapImageName)),
            "unlocks": Dictionary(uniqueKeysWithValues: battle.unlocks.map { ($0.key.rawValue, $0.value) }),
            "canvas": try json(battle.virtualCanvas),
            "towers": try json(catalog.towerTypes),
            "enemies": try json(battle.enemies), "combatRules": try json(arsenal.combatRules),
            "difficulty": difficulty.name, "enemyHPMultiplier": difficulty.enemyHPMultiplier,
            "campaignUpgrades": upgrades, "heroes": false,
            "metaProgression": ["earnedStars": loadout.starBudget, "spentStars": loadout.spentStars,
                "availableStars": loadout.availableStars,
                "bestStarsByLevel": Dictionary(uniqueKeysWithValues: battle.playerUpgrades.bestStarsByLevel.map { ($0.key.uuidString, $0.value) })],
            "reinforcementConfig": ["cooldownSeconds": battle.reinforcementConfig.cooldownSeconds,
                "timeToLiveSeconds": battle.reinforcementConfig.timeToLiveSeconds]]
        return try JSONSerialization.data(withJSONObject: content, options: [.sortedKeys])
    }

}
