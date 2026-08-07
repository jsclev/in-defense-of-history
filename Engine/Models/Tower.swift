import Foundation

public enum Targeting: String, Codable, Sendable, CaseIterable {
    /// Furthest along the path (closest to your exit). The KR default.
    case first
    /// Least far along the path.
    case last
    /// Highest current HP — the long-rifle "pick the big one" behaviour.
    case strongest
    /// Lowest current morale (skipping already-Broken units) — lets terror
    /// towers finish wavering squads and cascade breaks.
    case shakiest
}

public struct TowerLevel: Codable, Sendable, Equatable {
    public var cost: Int
    public var range: Double
    /// Seconds between volleys.
    public var fireInterval: Double
    public var shotMin: Double
    public var shotMax: Double
    public var terrorMin: Double
    public var terrorMax: Double
    /// 0 == single target. Otherwise this is the blast radius around the
    /// primary target: damage runs from shotMax at the impact center down to
    /// shotMin at the blast edge (the Kingdom Rush artillery model).
    public var aoeRadius: Double
    /// Falloff curve: damage(d) = shotMax - (shotMax - shotMin) * (d/R)^k.
    /// k = 1 is linear (KR default); large k approaches no splash reduction.
    public var aoeFalloffExponent: Double
    /// Fraction of the target's cover that splash ignores (KR artillery: 0.5).
    public var splashCoverPierce: Double
    /// Chance per volley to infect the (primary) target, scaled by (1 - hardiness).
    public var contagionChance: Double
    public var targeting: Targeting
    /// Projectile flight speed in design units/sec; 0 = hitscan. Single-target
    /// towers fire homing projectiles; blast towers fire ballistic shells at
    /// the target's fire-time position (fast enemies can leave the blast).
    public var projectileSpeed: Double
    /// Melee garrison: 0 unitCount == not a melee tower. For melee towers
    /// `range` is the flag range (how far the rally point may sit from the
    /// tower). Units block one enemy each and fight with these stats.
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
        shotMin: Double = 0,
        shotMax: Double = 0,
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
        self.shotMin = shotMin
        self.shotMax = shotMax
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
    /// levels[0] is the build; levels[1...] are upgrades.
    public var levels: [TowerLevel]

    public init(id: UUID, name: String, levels: [TowerLevel]) {
        self.id = id
        self.name = name
        self.levels = levels
    }
}

/// Runtime tower occupying a slot.
public struct Tower: Sendable {
    public var typeIndex: Int
    public var slotIndex: Int
    /// Index into TowerType.levels.
    public var level: Int
    /// Engine ticks until the next shot is allowed. Integer ticks keep fire
    /// cadence exact and identical across the CPU and GPU engines (fractional
    /// seconds drifted differently in Double vs float).
    public var cooldown: Int

    public init(typeIndex: Int, slotIndex: Int, level: Int = 0, cooldown: Int = 0) {
        self.typeIndex = typeIndex
        self.slotIndex = slotIndex
        self.level = level
        self.cooldown = cooldown
    }
}
