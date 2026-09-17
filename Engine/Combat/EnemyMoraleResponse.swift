/// Per-enemy morale gates, expressed as fractions of maximum morale. These
/// affect movement and damage per melee swing, not the attack interval.
public struct EnemyMoraleResponse: Codable, Equatable, Sendable {
    public var speedThreshold: Double
    public var attackThreshold: Double
    public var speedMultiplier: Double
    public var attackMultiplier: Double

    public init(speedThreshold: Double = 0.4, attackThreshold: Double = 0.4,
                speedMultiplier: Double = 2.0 / 3.0, attackMultiplier: Double = 2.0 / 3.0) {
        self.speedThreshold = speedThreshold
        self.attackThreshold = attackThreshold
        self.speedMultiplier = speedMultiplier
        self.attackMultiplier = attackMultiplier
    }

    public func movementMultiplier(morale: Double) -> Double {
        morale <= speedThreshold * Tunables.moraleMax ? speedMultiplier : 1
    }

    public func damageMultiplier(morale: Double) -> Double {
        morale <= attackThreshold * Tunables.moraleMax ? attackMultiplier : 1
    }
}
