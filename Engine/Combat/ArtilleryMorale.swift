import Foundation

/// A shot keeps the morale tuning it had when fired, including across upgrades.
public struct ArtilleryMoraleStrike: Equatable, Sendable {
    public let minimum: Double
    public let maximum: Double
    public let radius: Double
    public let falloffExponent: Double

    public init(tuning: TowerLevel) {
        precondition(tuning.terrorMin.isFinite && tuning.terrorMin >= 0)
        precondition(tuning.terrorMax.isFinite && tuning.terrorMax >= tuning.terrorMin)
        precondition(tuning.aoeRadius.isFinite && tuning.aoeRadius >= 0)
        precondition(tuning.aoeFalloffExponent.isFinite && tuning.aoeFalloffExponent > 0)
        minimum = tuning.terrorMin
        maximum = tuning.terrorMax
        radius = tuning.aoeRadius
        falloffExponent = tuning.aoeFalloffExponent
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
    public let rules: CombatRules

    public private(set) var value: Double
    public private(set) var impactAge = Double.infinity
    public private(set) var valueBeforeImpact: Double
    public private(set) var flinchDirection = 1.0

    public init(rules: CombatRules) {
        self.rules = rules
        value = rules.moraleMax
        valueBeforeImpact = rules.moraleMax
    }

    public var isVisible: Bool { value < rules.moraleVisibilityThreshold }
    public var response: Double { max(0, 1 - impactAge / rules.moraleResponseDuration) }
    public var displayedValue: Double {
        let t = min(1, impactAge / rules.moraleDisplayDuration)
        let ease = 1 - pow(1 - t, 3)
        return valueBeforeImpact + (value - valueBeforeImpact) * ease
    }

    public var remainingFraction: Double { min(1, max(0, value / rules.moraleMax)) }
    public var displayedFraction: Double { min(1, max(0, displayedValue / rules.moraleMax)) }

    /// Integrate only this frame's travel, including a recovery crossing. A
    /// changing speed must never recalculate the unit's entire past journey.
    public mutating func advance(seconds: Double, baseSpeed: Double,
                                 response: EnemyMoraleResponse, blocked: Bool) -> Double {
        guard seconds.isFinite, seconds > 0 else { return 0 }
        let threshold = response.speedThreshold * rules.moraleMax
        var slowedSeconds = 0.0
        if threshold >= rules.moraleMax {
            slowedSeconds = seconds
        } else if value <= threshold {
            let recoveryWait = max(0, rules.moraleRecoveryDelay - impactAge)
            let recoveryToThreshold = (threshold - value) / rules.baseMoraleRegenPerSecond
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
        else { recoveryTime = max(0, impactAge - max(previousAge, rules.moraleRecoveryDelay)) }
        value = min(rules.moraleMax, value + rules.baseMoraleRegenPerSecond * recoveryTime)
    }
}
