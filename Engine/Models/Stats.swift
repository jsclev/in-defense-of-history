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
    public var moraleResponse: EnemyMoraleResponse

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
        breakBand: ClosedRange<Double>,
        moraleResponse: EnemyMoraleResponse
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
        self.moraleResponse = moraleResponse
    }

    private enum CodingKeys: String, CodingKey {
        case maxHP, speed, cover, discipline, hardiness, damageMin, damageMax
        case gold, livesCost, breakBand, moraleResponse
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(maxHP: try values.decode(Double.self, forKey: .maxHP),
                  speed: try values.decode(Double.self, forKey: .speed),
                  cover: try values.decode(Double.self, forKey: .cover),
                  discipline: try values.decode(Double.self, forKey: .discipline),
                  hardiness: try values.decode(Double.self, forKey: .hardiness),
                  damageMin: try values.decode(Double.self, forKey: .damageMin),
                  damageMax: try values.decode(Double.self, forKey: .damageMax),
                  gold: try values.decode(Int.self, forKey: .gold),
                  livesCost: try values.decode(Int.self, forKey: .livesCost),
                  breakBand: try values.decode(ClosedRange<Double>.self, forKey: .breakBand),
                  moraleResponse: try values.decode(EnemyMoraleResponse.self, forKey: .moraleResponse))
    }
}
