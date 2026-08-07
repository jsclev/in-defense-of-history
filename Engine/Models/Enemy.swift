import Foundation

public struct Enemy: Sendable {
    /// Stable identity for telemetry/debugging (monotonic per simulation).
    public var spawnID: Int
    public var typeIndex: Int
    public var waveIndex: Int
    public var pathIndex: Int

    /// Distance travelled along the path polyline. Broken units move this
    /// backwards — the rout *is* the reverse traversal.
    public var distance: Double

    public var hp: Double
    public var morale: Double
    /// Sampled at spawn from the type's breakBand (hidden per-unit variance).
    public var shakenThreshold: Double
    public var state: MoraleState
    public var infected: Bool

    /// Marked during a tick; compacted (order-preserving) at tick end.
    public var removed: Bool

    // Cached trait flags so the inner loops don't scan trait arrays.
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

/// How an enemy left the field. Feeds the bounty economy and the report.
public enum EnemyFate: String, Codable, Sendable {
    case killed
    case routed
    case captured
    case leaked
}
