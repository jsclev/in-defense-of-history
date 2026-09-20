public struct Wave: Codable, Sendable, Equatable {
    /// Authored design timestamp retained for editing/export. Battle starts are
    /// controlled exclusively by WaveStartSchedule in the shared engine.
    public var startTime: Double
    public var spawns: [SpawnEntry]
    /// Game seconds from the previous wave's actual start to button reveal.
    /// Legacy documents may omit this; BattleContent rejects missing timing.
    public var callButtonDelay: Double?
    /// Game seconds from button reveal to automatic start. Ignored for wave 1.
    public var autoStartCountdown: Double?
    /// Fixed money reward for manually calling this wave after wave 1.
    public var earlyCallBonus: Int?

    public init(startTime: Double, spawns: [SpawnEntry],
                callButtonDelay: Double? = nil, autoStartCountdown: Double? = nil,
                earlyCallBonus: Int? = nil) {
        self.startTime = startTime
        self.spawns = spawns
        self.callButtonDelay = callButtonDelay
        self.autoStartCountdown = autoStartCountdown
        self.earlyCallBonus = earlyCallBonus
    }

}
