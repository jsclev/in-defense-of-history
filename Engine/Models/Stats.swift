public enum DamageType: String, Codable, Sendable, CaseIterable {
    case shot
    case terror
    case contagion
    case trueDamage = "true"
}

public enum MoraleState: String, Codable, Sendable {
    case steady
    case shaken
    case broken
}

public struct EnemyStats: Codable, Sendable, Equatable {
    public var maxHP: Double
    public var speed: Double
    public var cover: Double
    public var discipline: Double
    public var hardiness: Double
    public var damageMin: Double
    public var damageMax: Double
    public var gold: Int
    public var livesCost: Int
    public var breakBand: ClosedRange<Double>

    public init(
        maxHP: Double,
        speed: Double,
        cover: Double,
        discipline: Double,
        hardiness: Double,
        damageMin: Double,
        damageMax: Double,
        gold: Int,
        livesCost: Int,
        breakBand: ClosedRange<Double>
    ) {
        self.maxHP = maxHP
        self.speed = speed
        self.cover = cover
        self.discipline = discipline
        self.hardiness = hardiness
        self.damageMin = damageMin
        self.damageMax = damageMax
        self.gold = gold
        self.livesCost = livesCost
        self.breakBand = breakBand
    }
}
