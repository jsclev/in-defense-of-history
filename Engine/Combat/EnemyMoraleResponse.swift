/// Per-enemy morale gates, expressed as fractions of maximum morale. These
/// affect movement and damage per melee swing, not the attack interval.
public struct EnemyMoraleResponse: Codable, Equatable, Sendable {
    public var speedThreshold: Double
    public var attackThreshold: Double
    public var speedMultiplier: Double
    public var attackMultiplier: Double

    public init(speedThreshold: Double, attackThreshold: Double,
                speedMultiplier: Double, attackMultiplier: Double) {
        self.speedThreshold = speedThreshold
        self.attackThreshold = attackThreshold
        self.speedMultiplier = speedMultiplier
        self.attackMultiplier = attackMultiplier
    }

    public func movementMultiplier(morale: Double, maximum: Double) -> Double {
        morale <= speedThreshold * maximum ? speedMultiplier : 1
    }

    public func damageMultiplier(morale: Double, maximum: Double) -> Double {
        morale <= attackThreshold * maximum ? attackMultiplier : 1
    }
}
