import Foundation

/// View-independent health-level calculation. Combat owns current/maximum HP;
/// every health indicator consumes this same bounded fraction and visibility.
final class UnitHealth {
    let fraction: Double
    let isDamaged: Bool

    init(current: Double, maximum: Double) {
        precondition(current.isFinite, "UnitHealth.current must be finite: \(current)")
        precondition(maximum.isFinite && maximum > 0,
                     "UnitHealth.maximum must be finite and positive: \(maximum)")
        fraction = min(1, max(0, current / maximum))
        isDamaged = current < maximum
    }
}
