import Foundation

public struct ReinforcementCooldown: Equatable, Sendable {
    public let remainingSeconds: Double
    public let remainingFraction: Double

    public var isReady: Bool { remainingSeconds == 0 }
    public var displaySeconds: Int { Int(ceil(remainingSeconds)) }
    public static let ready = ReinforcementCooldown(remainingSeconds: 0, remainingFraction: 0)
}

/// All deadlines use simulation ticks, including while waiting for the first
/// wave. Pausing freezes them; changing game speed changes both timers together.
public struct ReinforcementSchedule {
    private let lifetimeTicks: Int64
    private let cooldownTicks: Int64
    private var readyTick: Int64 = 0
    private var expiryTicksBySlot: [Int: Int64] = [:]

    public init(config: ReinforcementConfig) {
        lifetimeTicks = Int64((config.timeToLiveSeconds * Double(SimClock.ticksPerSecond)).rounded(.up))
        cooldownTicks = Int64((config.cooldownSeconds * Double(SimClock.ticksPerSecond)).rounded(.up))
    }

    public func cooldown(at tick: Int64) -> ReinforcementCooldown {
        let remaining = max(0, readyTick - tick)
        return ReinforcementCooldown(
            remainingSeconds: Double(remaining) / Double(SimClock.ticksPerSecond),
            remainingFraction: min(1, Double(remaining) / Double(cooldownTicks)))
    }

    /// A rejected tap changes neither the current cooldown nor any lifetime.
    public mutating func deploy(slot: Int, at tick: Int64) -> Bool {
        guard tick >= readyTick, expiryTicksBySlot[slot] == nil else { return false }
        expiryTicksBySlot[slot] = tick + lifetimeTicks
        readyTick = tick + cooldownTicks
        return true
    }

    /// Each group expires independently, even when lifetime exceeds cooldown.
    public mutating func expire(at tick: Int64) -> [Int] {
        let expired = expiryTicksBySlot.filter { $0.value <= tick }.map(\.key).sorted()
        for slot in expired { expiryTicksBySlot[slot] = nil }
        return expired
    }
}
