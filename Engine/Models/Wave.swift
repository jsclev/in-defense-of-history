public struct Wave: Codable, Sendable, Equatable {
    /// Absolute start time in seconds from level start. (A call-next-wave-early
    /// mechanic later becomes an offset applied to this.)
    public var startTime: Double
    public var spawns: [SpawnEntry]

    public init(startTime: Double, spawns: [SpawnEntry]) {
        self.startTime = startTime
        self.spawns = spawns
    }
}
