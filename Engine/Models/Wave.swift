public struct Wave: Codable, Sendable, Equatable {
    public var startTime: Double
    public var spawns: [SpawnEntry]

    public init(startTime: Double, spawns: [SpawnEntry]) {
        self.startTime = startTime
        self.spawns = spawns
    }
}
