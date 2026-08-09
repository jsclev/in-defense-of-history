import Foundation

public enum Targeting: String, Codable, Sendable, CaseIterable {
    case first
    case last
    case strongest
    case shakiest
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
    public var meleeUnitCount: Int
    public var meleeUnitHP: Double
    public var meleeUnitDamageMin: Double
    public var meleeUnitDamageMax: Double
    public var meleeUnitAttackInterval: Double
    public var meleeUnitRespawnSeconds: Double
    public var meleeUnitHealPerSecond: Double

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
        meleeUnitCount: Int = 0,
        meleeUnitHP: Double = 0,
        meleeUnitDamageMin: Double = 0,
        meleeUnitDamageMax: Double = 0,
        meleeUnitAttackInterval: Double = 0,
        meleeUnitRespawnSeconds: Double = 0,
        meleeUnitHealPerSecond: Double = 0
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
        self.meleeUnitCount = meleeUnitCount
        self.meleeUnitHP = meleeUnitHP
        self.meleeUnitDamageMin = meleeUnitDamageMin
        self.meleeUnitDamageMax = meleeUnitDamageMax
        self.meleeUnitAttackInterval = meleeUnitAttackInterval
        self.meleeUnitRespawnSeconds = meleeUnitRespawnSeconds
        self.meleeUnitHealPerSecond = meleeUnitHealPerSecond
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
