import Foundation

public struct ReinforcementConfig: Equatable, Sendable {
    public let timeToLiveSeconds: Double
    public let cooldownSeconds: Double

    public init(timeToLiveSeconds: Double, cooldownSeconds: Double) throws {
        let maximumSeconds = Double(Int64.max / 2) / Double(SimClock.ticksPerSecond)
        guard timeToLiveSeconds.isFinite, timeToLiveSeconds > 0,
              timeToLiveSeconds < maximumSeconds,
              cooldownSeconds.isFinite, cooldownSeconds > 0,
              cooldownSeconds < maximumSeconds else {
            throw DbError.Db(message: "Reinforcement time to live and cooldown must be positive, finite game seconds.")
        }
        self.timeToLiveSeconds = timeToLiveSeconds
        self.cooldownSeconds = cooldownSeconds
    }
}
