import Foundation

public struct ReinforcementCooldown: Codable, Equatable, Sendable {
    public let remainingSeconds: Double
    public let remainingFraction: Double
    public var isReady: Bool { remainingSeconds == 0 }
    public var displaySeconds: Int { Int(ceil(remainingSeconds)) }
    public static let ready = ReinforcementCooldown(remainingSeconds: 0, remainingFraction: 0)
}

/// One cooldown, starting only after successful deployment. Troop lifetimes
/// are independent and never block, shorten or extend this cooldown.
public struct ReinforcementSchedule {
    private let lifetimeTicks: Int64
    private let cooldownTicks: Int64
    private var readyTick: Int64?
    private var expiryTicksBySlot: [Int: Int64] = [:]
    public init(config: ReinforcementConfig) {
        lifetimeTicks = Int64((config.timeToLiveSeconds * Double(SimClock.ticksPerSecond)).rounded(.up))
        cooldownTicks = Int64((config.cooldownSeconds * Double(SimClock.ticksPerSecond)).rounded(.up))
    }
    public func cooldown(at tick: Int64) -> ReinforcementCooldown {
        let remaining = readyTick.map { max(0, $0 - tick) } ?? 0
        return ReinforcementCooldown(remainingSeconds: Double(remaining) / Double(SimClock.ticksPerSecond),
            remainingFraction: min(1, Double(remaining) / Double(cooldownTicks)))
    }
    /// Rejected deployments never move the one cooldown deadline.
    public mutating func deploy(slot: Int, at tick: Int64) -> Bool {
        guard cooldown(at: tick).isReady, expiryTicksBySlot[slot] == nil else { return false }
        readyTick = tick + cooldownTicks
        expiryTicksBySlot[slot] = tick + lifetimeTicks
        return true
    }
    public mutating func expire(at tick: Int64) -> [Int] {
        let expired = expiryTicksBySlot.filter { $0.value <= tick }.map(\.key).sorted()
        for slot in expired { expiryTicksBySlot[slot] = nil }
        return expired
    }
}
