import Foundation

public struct Enemy: Sendable {
    public var spawnID: Int
    public var typeIndex: Int
    public var waveIndex: Int
    public var pathIndex: Int

    public var distance: Double

    public var hp: Double
    public var morale: Double
    public var shakenThreshold: Double
    public var state: MoraleState
    public var infected: Bool

    public var removed: Bool

    public var isWavering: Bool
    public var isMercenary: Bool
    public var isSteadyAdvance: Bool

    public init(
        spawnID: Int,
        typeIndex: Int,
        waveIndex: Int,
        pathIndex: Int,
        type: EnemyType,
        shakenThreshold: Double
    ) {
        self.spawnID = spawnID
        self.typeIndex = typeIndex
        self.waveIndex = waveIndex
        self.pathIndex = pathIndex
        self.distance = 0
        self.hp = type.stats.maxHP
        self.morale = Tunables.moraleMax
        self.shakenThreshold = shakenThreshold
        self.state = .steady
        self.infected = false
        self.removed = false
        self.isWavering = type.traits.contains(.wavering)
        self.isMercenary = type.traits.contains(.mercenary)
        self.isSteadyAdvance = type.traits.contains(.steadyAdvance)
    }
}

public enum EnemyFate: String, Codable, Sendable {
    case killed
    case routed
    case captured
    case leaked
}
