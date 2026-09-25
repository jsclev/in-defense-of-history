import Foundation

/// Game seconds per wall-clock second. Combat always uses fixed SimClock ticks.
public struct PlaySpeed: Codable, Equatable {
    public let factor: Double

    public init(_ factor: Double) throws {
        // Bounds keep wall-clock durations representable, even at the fastest
        // setting. The upper limit is effectively CPU-bound for simulation.
        guard factor.isFinite, (0.01...1_000_000_000).contains(factor) else {
            throw DbError.Db(message: "play_speed.factor: expected a finite number from 0.01 through 1000000000, got \(factor)")
        }
        self.factor = factor
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(values.decode(Double.self, forKey: .factor))
    }

    var tickDuration: Duration { .seconds(SimClock.dt / factor) }
}

public struct PlaySpeedConfiguration {
    public let player: PlaySpeed
    public let simulator: PlaySpeed
    public let editor: PlaySpeed
}
