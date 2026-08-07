import Foundation

/// One line in a wave: "spawn `count` of `enemyTypeID`, one every `interval`
/// seconds, starting `delay` seconds after the wave begins, on path `pathIndex`."
public struct SpawnEntry: Codable, Sendable, Equatable {
    public var enemyTypeID: UUID
    public var count: Int
    public var interval: Double
    public var delay: Double
    public var pathIndex: Int

    public init(enemyTypeID: UUID, count: Int, interval: Double, delay: Double = 0, pathIndex: Int = 0) {
        self.enemyTypeID = enemyTypeID
        self.count = count
        self.interval = interval
        self.delay = delay
        self.pathIndex = pathIndex
    }
}
