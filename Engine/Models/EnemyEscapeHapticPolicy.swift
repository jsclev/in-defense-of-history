import Foundation

/// Semantic feedback for exit crossings. Timing uses monotonic wall time, not
/// simulation ticks, so fast-forward cannot turn a burst of escapes into a buzz.
public struct EnemyEscapeHapticPolicy {
    public enum Cue: Equatable {
        case lifeLoss
        case defeat
    }

    /// A game-specific comfort limit, not a duration prescribed by Apple.
    public static let minimumInterval: TimeInterval = 0.5
    private var lastLossTime: TimeInterval?

    public init() {}

    public mutating func feedback(previousCount: Int, escapeCount: Int,
                                  livesRemaining: Int, isEnabled: Bool,
                                  isActive: Bool, at uptime: TimeInterval) -> Cue? {
        guard escapeCount > previousCount, isEnabled, isActive else { return nil }
        // The last life has a distinct cue, even during a burst of losses.
        if livesRemaining == 0 { return .defeat }
        if let lastLossTime, uptime - lastLossTime < Self.minimumInterval {
            return nil
        }
        lastLossTime = uptime
        return .lifeLoss
    }
}
