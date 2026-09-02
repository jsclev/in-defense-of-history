import Foundation

public struct HeroCombatStats: Sendable, Equatable {
    public let attackRating: Double
    public let defenseRating: Double
    public let hp: Double
    public let attackInterval: Double
    public let respawnSeconds: Double
    public let healPerSecond: Double
    public let moveSpeed: Double

    public init(
        attackRating: Double,
        defenseRating: Double,
        hp: Double,
        attackInterval: Double,
        respawnSeconds: Double,
        healPerSecond: Double,
        moveSpeed: Double
    ) {
        self.attackRating = attackRating
        self.defenseRating = defenseRating
        self.hp = hp
        self.attackInterval = attackInterval
        self.respawnSeconds = respawnSeconds
        self.healPerSecond = healPerSecond
        self.moveSpeed = moveSpeed
    }

    public var damageRange: ClosedRange<Double> {
        let spread = attackRating * MilitiaTunables.attackSpread
        return (attackRating - spread)...(attackRating + spread)
    }
}

public struct LevelHero: Sendable, Equatable {
    public let heroId: UUID
    public let enemyPathIndex: Int
    public let combat: HeroCombatStats

    public init(heroId: UUID, enemyPathIndex: Int, combat: HeroCombatStats) {
        self.heroId = heroId
        self.enemyPathIndex = enemyPathIndex
        self.combat = combat
    }
}
