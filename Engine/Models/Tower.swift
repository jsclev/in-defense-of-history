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

    public var leashRadius: Double {
        rallyPointRadius * MilitiaTunables.leashRadiusFraction
    }

    public var engageScanRadius: Double {
        rallyPointRadius * MilitiaTunables.engageScanRadiusFraction
    }
}

public struct TowerLevel: Codable, Sendable, Equatable {
    public var cost: Int
    public var range: Double
    public var attackRange: TowerAttackRange { TowerAttackRange(range) }
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
    /// Non-nil for a planted charge that detonates at the outgoing blast boundary.
    public var demolitionPreparationSeconds: Double?
    public var engineerObstacles: EngineerObstacleStats?

    public init(
        cost: Int,
        range: Double,
        fireInterval: Double,
        shotMinDamage: Double,
        shotMaxDamage: Double,
        terrorMin: Double,
        terrorMax: Double,
        aoeRadius: Double,
        aoeFalloffExponent: Double,
        splashCoverPierce: Double,
        contagionChance: Double,
        targeting: Targeting,
        projectileSpeed: Double,
        meleeUnit: MeleeUnitStats?,
        demolitionPreparationSeconds: Double?,
        engineerObstacles: EngineerObstacleStats?
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
        self.demolitionPreparationSeconds = demolitionPreparationSeconds
        self.engineerObstacles = engineerObstacles
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case cost, range, fireInterval, shotMinDamage, shotMaxDamage, terrorMin, terrorMax
        case aoeRadius, aoeFalloffExponent, splashCoverPierce, contagionChance, targeting
        case projectileSpeed, meleeUnit, demolitionPreparationSeconds, engineerObstacles
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        cost = try values.decode(Int.self, forKey: .cost)
        range = try values.decode(Double.self, forKey: .range)
        fireInterval = try values.decode(Double.self, forKey: .fireInterval)
        shotMinDamage = try values.decode(Double.self, forKey: .shotMinDamage)
        shotMaxDamage = try values.decode(Double.self, forKey: .shotMaxDamage)
        terrorMin = try values.decode(Double.self, forKey: .terrorMin)
        terrorMax = try values.decode(Double.self, forKey: .terrorMax)
        aoeRadius = try values.decode(Double.self, forKey: .aoeRadius)
        aoeFalloffExponent = try values.decode(Double.self, forKey: .aoeFalloffExponent)
        splashCoverPierce = try values.decode(Double.self, forKey: .splashCoverPierce)
        contagionChance = try values.decode(Double.self, forKey: .contagionChance)
        targeting = try values.decode(Targeting.self, forKey: .targeting)
        projectileSpeed = try values.decode(Double.self, forKey: .projectileSpeed)
        meleeUnit = try values.decode(MeleeUnitStats?.self, forKey: .meleeUnit)
        demolitionPreparationSeconds = try values.decode(Double?.self, forKey: .demolitionPreparationSeconds)
        engineerObstacles = try values.decode(EngineerObstacleStats?.self, forKey: .engineerObstacles)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(cost, forKey: .cost)
        try values.encode(range, forKey: .range)
        try values.encode(fireInterval, forKey: .fireInterval)
        try values.encode(shotMinDamage, forKey: .shotMinDamage)
        try values.encode(shotMaxDamage, forKey: .shotMaxDamage)
        try values.encode(terrorMin, forKey: .terrorMin)
        try values.encode(terrorMax, forKey: .terrorMax)
        try values.encode(aoeRadius, forKey: .aoeRadius)
        try values.encode(aoeFalloffExponent, forKey: .aoeFalloffExponent)
        try values.encode(splashCoverPierce, forKey: .splashCoverPierce)
        try values.encode(contagionChance, forKey: .contagionChance)
        try values.encode(targeting, forKey: .targeting)
        try values.encode(projectileSpeed, forKey: .projectileSpeed)
        try values.encode(meleeUnit, forKey: .meleeUnit)
        try values.encode(demolitionPreparationSeconds, forKey: .demolitionPreparationSeconds)
        try values.encode(engineerObstacles, forKey: .engineerObstacles)
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
