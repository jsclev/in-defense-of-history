import Foundation

/// A shot keeps the morale tuning it had when fired, including across upgrades.
public struct ArtilleryMoraleStrike: Equatable, Sendable {
    public let minimum: Double
    public let maximum: Double
    public let radius: Double
    public let falloffExponent: Double

    public init(tuning: TowerLevel) {
        minimum = max(0, tuning.terrorMin)
        maximum = max(minimum, tuning.terrorMax)
        radius = max(0, tuning.aoeRadius)
        falloffExponent = max(0.01, tuning.aoeFalloffExponent)
    }

    public func loss(distance: Double, discipline: Double) -> Double {
        guard distance.isFinite, distance >= 0,
              radius == 0 || distance <= radius else { return 0 }
        let fraction = radius > 0 ? pow(distance / radius, falloffExponent) : 0
        let terror = maximum - (maximum - minimum) * fraction
        return terror * (1 - min(1, max(0, discipline)))
    }
}

/// Morale and its short impact response use game time, so pause and speed-up agree.
/// Visibility is independent of future combat-state/break thresholds.
public struct EnemyMorale: Equatable, Sendable {
    public static let visibilityThreshold = 90.0
    public static let responseDuration = 0.8
    public static let recoveryDelay = 3.0

    public private(set) var value = Tunables.moraleMax
    public private(set) var impactAge = Double.infinity
    public private(set) var valueBeforeImpact = Tunables.moraleMax
    public private(set) var flinchDirection = 1.0

    public init() {}

    public var isVisible: Bool { value < Self.visibilityThreshold }
    public var response: Double { max(0, 1 - impactAge / Self.responseDuration) }
    public var displayedValue: Double {
        let t = min(1, impactAge / 0.34)
        let ease = 1 - pow(1 - t, 3)
        return valueBeforeImpact + (value - valueBeforeImpact) * ease
    }

    public var remainingFraction: Double { min(1, max(0, value / Tunables.moraleMax)) }
    public var displayedFraction: Double { min(1, max(0, displayedValue / Tunables.moraleMax)) }

    /// Integrate only this frame's travel, including a recovery crossing. A
    /// changing speed must never recalculate the unit's entire past journey.
    public mutating func advance(seconds: Double, baseSpeed: Double,
                                 response: EnemyMoraleResponse, blocked: Bool) -> Double {
        guard seconds.isFinite, seconds > 0 else { return 0 }
        let threshold = response.speedThreshold * Tunables.moraleMax
        var slowedSeconds = 0.0
        if threshold >= Tunables.moraleMax {
            slowedSeconds = seconds
        } else if value <= threshold {
            let recoveryWait = max(0, Self.recoveryDelay - impactAge)
            let recoveryToThreshold = (threshold - value) / Tunables.baseMoraleRegenPerSecond
            slowedSeconds = min(seconds, recoveryWait + recoveryToThreshold)
        }
        advance(seconds: seconds)
        guard !blocked else { return 0 }
        return baseSpeed * (slowedSeconds * response.speedMultiplier + seconds - slowedSeconds)
    }

    @discardableResult
    public mutating func apply(loss: Double, direction: Double) -> Bool {
        guard loss.isFinite, loss > 0, value > 0 else { return false }
        valueBeforeImpact = displayedValue
        value = max(0, value - loss)
        impactAge = 0
        flinchDirection = direction < 0 ? -1 : 1
        return true
    }

    public mutating func advance(seconds: Double) {
        guard seconds.isFinite, seconds > 0 else { return }
        let previousAge = impactAge
        impactAge += seconds
        let recoveryTime: Double
        if previousAge.isInfinite { recoveryTime = seconds }
        else { recoveryTime = max(0, impactAge - max(previousAge, Self.recoveryDelay)) }
        value = min(Tunables.moraleMax, value + Tunables.baseMoraleRegenPerSecond * recoveryTime)
    }
}
