import Foundation

public enum Targeting: String, Codable, Sendable, CaseIterable {
    case first
    case last
    case strongest
    case shakiest
}

public struct MeleeUnitStats: Codable, Sendable, Equatable {
    public var soldierCount: Int
    public var attackRating: Double
    public var defenseRating: Double
    public var hp: Double
    public var rallyPointRadius: Double
    public var attackInterval: Double
    public var respawnSeconds: Double
    public var healPerSecond: Double

    public init(
        soldierCount: Int,
        attackRating: Double,
        defenseRating: Double,
        hp: Double,
        rallyPointRadius: Double,
        attackInterval: Double,
        respawnSeconds: Double,
        healPerSecond: Double
    ) {
        self.soldierCount = soldierCount
        self.attackRating = attackRating
        self.defenseRating = defenseRating
        self.hp = hp
        self.rallyPointRadius = rallyPointRadius
        self.attackInterval = attackInterval
        self.respawnSeconds = respawnSeconds
        self.healPerSecond = healPerSecond
    }

    public var damageRange: ClosedRange<Double> {
        let spread = attackRating * MilitiaTunables.attackSpread
        return (attackRating - spread)...(attackRating + spread)
    }
}

public struct TowerLevel: Codable, Sendable, Equatable {
    public var cost: Int
    public var range: Double
    public var fireInterval: Double
    public var shotMinDamage: Double
    public var shotMaxDamage: Double
    public var terrorMin: Double
    public var terrorMax: Double
    public var aoeRadius: Double
    public var aoeFalloffExponent: Double
    public var splashCoverPierce: Double
    public var contagionChance: Double
    public var targeting: Targeting
    public var projectileSpeed: Double
    public var meleeUnit: MeleeUnitStats?

    public init(
        cost: Int,
        range: Double,
        fireInterval: Double,
        shotMinDamage: Double = 0,
        shotMaxDamage: Double = 0,
        terrorMin: Double = 0,
        terrorMax: Double = 0,
        aoeRadius: Double = 0,
        aoeFalloffExponent: Double = 1.0,
        splashCoverPierce: Double = 0,
        contagionChance: Double = 0,
        targeting: Targeting = .first,
        projectileSpeed: Double = 0,
        meleeUnit: MeleeUnitStats? = nil
    ) {
        self.cost = cost
        self.range = range
        self.fireInterval = fireInterval
        self.shotMinDamage = shotMinDamage
        self.shotMaxDamage = shotMaxDamage
        self.terrorMin = terrorMin
        self.terrorMax = terrorMax
        self.aoeRadius = aoeRadius
        self.aoeFalloffExponent = aoeFalloffExponent
        self.splashCoverPierce = splashCoverPierce
        self.contagionChance = contagionChance
        self.targeting = targeting
        self.projectileSpeed = projectileSpeed
        self.meleeUnit = meleeUnit
    }
}

public struct TowerType: Codable, Sendable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var levels: [TowerLevel]

    public init(id: UUID, name: String, levels: [TowerLevel]) {
        self.id = id
        self.name = name
        self.levels = levels
    }
}

public struct Tower: Sendable {
    public var typeIndex: Int
    public var slotIndex: Int
    public var level: Int
    public var cooldown: Int

    public init(typeIndex: Int, slotIndex: Int, level: Int = 0, cooldown: Int = 0) {
        self.typeIndex = typeIndex
        self.slotIndex = slotIndex
        self.level = level
        self.cooldown = cooldown
    }
}
