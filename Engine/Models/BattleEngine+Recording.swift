import Foundation

extension BattleEngine {
    public var runID: UUID? { runRecorder?.id }

    func startRecording(_ destination: BattleRecording, seed: UInt64, heroesEnabled: Bool) throws {
        switch destination {
        case .preview: return
        case let .database(dao, source):
            runRecorder = try LevelRunRecorder(dao: dao, source: source,
                setup: LevelReplaySetup(engine: self, seed: seed, heroesEnabled: heroesEnabled))
            try runRecorder?.action(tick: timer.tick, category: "lifecycle", name: "started", payload: [:])
            recordFrame()
        }
    }

    /// Both direct UI handlers and the simulator command adapter cross here.
    /// Nested handlers are part of one input; combat events remain separate.
    func recordingInput<T>(_ name: String, _ fields: [String: String] = [:], _ body: () -> T) -> T {
        guard let recorder = runRecorder, !recorder.finished, recordingInputDepth == 0 else { return body() }
        recordingInputDepth += 1
        defer { recordingInputDepth -= 1 }
        var fields = fields
        fields["selectedSlot"] = selectedSlotIndex.map(String.init)
        fields["selectedTower"] = selectedTowerSlotIndex.map(String.init)
        fields["selectedHero"] = selectedHeroIndex.map(String.init)
        fields["moneyBefore"] = String(money)
        recording { try recorder.action(tick: timer.tick, category: "input", name: name, payload: fields) }
        let result = body()
        recording {
            try recorder.action(tick: timer.tick, category: "event", name: "inputResult",
                payload: ["input": name, "result": String(describing: result), "moneyAfter": String(money)])
        }
        recordFrame()
        return result
    }

    func emit(_ event: SimEvent, _ time: Double) {
        if let recorder = runRecorder, !recorder.finished {
            recording { try recorder.action(tick: timer.tick, category: "event", name: event.recordName,
                payload: ["event": try LevelRecordingCodec.json(event)]) }
        }
        onEvent?(event, time)
    }

    func recordCombat(_ name: String, _ fields: [String: String]) {
        guard let recorder = runRecorder, !recorder.finished else { return }
        recording { try recorder.action(tick: timer.tick, category: "event", name: name, payload: fields) }
    }

    func recordFrame() {
        guard let recorder = runRecorder, !recorder.finished else { return }
        // Native and headless runs record the same canonical pose at tick end.
        publishMilitia(); publishHeroes()
        recording { try recorder.frame(LevelReplayFrame(self)) }
    }

    public func finishRecording(status: LevelRunStatus) {
        guard let recorder = runRecorder, !recorder.finished else { return }
        while outcome != nil && !isPaused && !artilleryImpacts.isEmpty { advance(ticks: 1, interpolation: 1) }
        guard !recorder.finished else { return }
        recordFrame()
        recording { try recorder.finish(status: outcome == .victory ? .victory : outcome == .defeat ? .defeat : status, tick: timer.tick, result: simulationResult()) }
    }

    private func recording(_ operation: () throws -> Void) {
        do { try operation() }
        catch { fatalError("Cannot record level run \(runID?.uuidString ?? "unknown"): \(error)") }
    }
}

extension SimEvent {
    var recordName: String {
        switch self {
        case .waveStarted: return "waveStarted"
        case .towerBuilt: return "towerBuilt"
        case .towerUpgraded: return "towerUpgraded"
        case .enemySpawned: return "enemySpawned"
        case .enemyRemoved: return "enemyRemoved"
        case .towerFired: return "towerFired"
        }
    }
}
