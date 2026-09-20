import Foundation

public struct ReinforcementCooldown: Equatable, Sendable {
    public let remainingSeconds: Double
    public let remainingFraction: Double
    public var isReady: Bool { remainingSeconds == 0 }
    public var displaySeconds: Int { Int(ceil(remainingSeconds)) }
    public static let ready = ReinforcementCooldown(remainingSeconds: 0, remainingFraction: 0)
}

/// One ready deployment at battle entry. Extra reserve capacity refills serially
/// in simulation time; deployment never extends an existing group's lifetime.
public struct ReinforcementSchedule {
    private let lifetimeTicks: Int64
    private let cooldownTicks: Int64
    public let capacity: Int
    private var stored = 1
    private var nextRechargeTick: Int64?
    private var expiryTicksBySlot: [Int: Int64] = [:]
    public init(config: ReinforcementConfig, capacity: Int = 1) {
        precondition(capacity > 0)
        self.capacity = capacity
        lifetimeTicks = Int64((config.timeToLiveSeconds * Double(SimClock.ticksPerSecond)).rounded(.up))
        cooldownTicks = Int64((config.cooldownSeconds * Double(SimClock.ticksPerSecond)).rounded(.up))
        nextRechargeTick = capacity > 1 ? cooldownTicks : nil
    }
    public func availableDeployments(at tick: Int64) -> Int {
        guard let next = nextRechargeTick, tick >= next else { return stored }
        return stored + Int(min(Int64(capacity - stored), (tick - next) / cooldownTicks + 1))
    }
    public func cooldown(at tick: Int64) -> ReinforcementCooldown {
        var remaining: Int64 = 0
        if availableDeployments(at: tick) == 0, let next = nextRechargeTick { remaining = max(0, next - tick) }
        // A reserve upgrade allows two simultaneous groups, not unlimited accumulation.
        let active = expiryTicksBySlot.values.filter { $0 > tick }
        if capacity > 1, active.count >= capacity, let earliest = active.min() { remaining = max(remaining, earliest - tick) }
        return ReinforcementCooldown(remainingSeconds: Double(remaining) / Double(SimClock.ticksPerSecond),
            remainingFraction: min(1, Double(remaining) / Double(cooldownTicks)))
    }
    private mutating func refresh(at tick: Int64) {
        let updated = availableDeployments(at: tick), gained = updated - stored
        stored = updated
        if stored == capacity { nextRechargeTick = nil }
        else if gained > 0, let next = nextRechargeTick { nextRechargeTick = next + Int64(gained) * cooldownTicks }
    }
    /// Invalid taps consume no charge and never reset a recharge deadline.
    public mutating func deploy(slot: Int, at tick: Int64) -> Bool {
        guard cooldown(at: tick).isReady, expiryTicksBySlot[slot] == nil else { return false }
        refresh(at: tick)
        guard stored > 0 else { return false }
        stored -= 1
        if nextRechargeTick == nil { nextRechargeTick = tick + cooldownTicks }
        expiryTicksBySlot[slot] = tick + lifetimeTicks
        return true
    }
    public mutating func expire(at tick: Int64) -> [Int] {
        refresh(at: tick)
        let expired = expiryTicksBySlot.filter { $0.value <= tick }.map(\.key).sorted()
        for slot in expired { expiryTicksBySlot[slot] = nil }
        return expired
    }
}
