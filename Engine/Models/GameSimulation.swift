import Foundation

/// Headless input driver. It owns no battle state or gameplay rules.
@MainActor
public final class GameSimulation {
    let engine: BattleEngine
    public let content: BattleContent
    private var chosenPaths: [Int: DesignArsenal.Tier] = [:]
    private var observers: [SimulationObserver] = []
    private var pacingStarted = false
    public private(set) var reinforcementDeployments: [ReinforcementDeployment] = []

    public convenience init(recording: BattleRecording, content: BattleContent, playSpeed: PlaySpeed? = nil, startingMoney: Int?, heroesEnabled: Bool, seed: UInt64) throws {
        let engine = try BattleEngine(recording: recording, content: content, playSpeed: playSpeed ?? content.playSpeeds.simulator, heroesEnabled: heroesEnabled,
            startingMoneyOverride: startingMoney, seed: seed, onVictory: { _, _ in 0 })
        self.init(engine: engine)
    }

    /// Attach an automated input driver to a fresh engine for parity checks.
    /// Movie playback uses LevelReplayer and never constructs this adapter.
    public init(engine: BattleEngine) {
        precondition(engine.elapsedTime == 0 && engine.waveSchedule.nextWaveIndex == 0)
        self.engine = engine
        self.content = engine.content
        engine.onEvent = { [weak self] event, time in
            guard let self else { return }
            for observer in self.observers { observer.handle(event, atTime: time) }
        }
    }

    public var runID: UUID? { engine.runID }
    public var playSpeed: PlaySpeed { engine.playSpeed }
    public func setPlaySpeed(_ speed: PlaySpeed) { engine.setPlaySpeed(speed) }
    public func finishRecording(status: LevelRunStatus) { engine.finishRecording(status: status) }

    public func pause() { engine.pause() }
    public func resume() { engine.resume() }
    public func recordDriverControl(_ name: String, value: String) {
        engine.recordingInput(name, ["value": value]) {}
    }

    public var time: Double { engine.elapsedTime }
    public var gold: Int { engine.money }
    public var lives: Int { engine.lives }
    public var earnedMetaStars: Int { engine.earnedMetaStars }
    public var outcome: Outcome? { engine.outcome }
    public var towers: [BattleTowerSnapshot] { engine.towerSnapshots }
    public var enemies: [BattleEnemySnapshot] { engine.enemySnapshots }
    public var canStartWave: Bool { engine.awaitingWaveStart }
    public var currentWave: Int { engine.waveSchedule.nextWaveIndex }
    public var nextWaveNumber: Int { engine.nextWaveNumber }
    public var waveCountdownSeconds: Int? { engine.waveCountdownSeconds }
    public var waveCalls: [WaveCallReceipt] { engine.waveCallReceipts }
    public var canCallReinforcements: Bool { engine.canCallReinforcements }
    public var readyDemolitionSites: [(slot: Int, point: Point)] { engine.readyDemolitionSites }
    public func upgradeOffers(at slot: Int) -> [(nextLevel: Int, branch: Int, cost: Int)] { engine.upgradeOffers(at: slot) }
    public var shotsByMode: [TowerAttackMode: Int] { engine.shotsByMode }
    public var shotsBySlot: [Int: Int] { engine.shotsBySlot }
    public var demolitionDetonations: Int { engine.demolitionDetonations }
    public var buildOffers: [(kind: TowerKind, cost: Int)] {
        engine.availableTowerKinds.sorted { $0.rawValue < $1.rawValue }.map { ($0, engine.buildCost(for: $0)!) }
    }
    public func addObserver(_ observer: SimulationObserver) { observers.append(observer) }

    @discardableResult
    public func perform(_ command: BattleCommand) -> BuildResult {
        let result = engine.perform(command)
        if result == .ok, case let .reinforcements(point) = command {
            reinforcementDeployments.append(ReinforcementDeployment(seconds: time, wave: currentWave, point: point))
        }
        return result
    }

    /// The tier ID is the commander's intended final branch, not a request to
    /// skip construction. Only the engine decides whether the build is legal.
    @discardableResult
    public func build(slot: Int, towerID: UUID) -> BuildResult {
        return engine.recordingInput("buildIntent", ["slot": String(slot), "towerID": towerID.uuidString]) {
            guard let definition = content.arsenal.towers.first(where: { $0.tiers.contains { $0.id == towerID } }),
                  let final = definition.tiers.first(where: { $0.id == towerID }) else { return .invalid }
            let result = perform(.build(slot: slot, kind: definition.kind))
            if result == .ok { chosenPaths[slot] = final }
            return result
        }
    }

    @discardableResult
    public func upgrade(slot: Int) -> BuildResult {
        return engine.recordingInput("upgradeIntent", ["slot": String(slot)]) {
            guard let final = chosenPaths[slot],
                  let offer = engine.upgradeOffers(at: slot).first(where: {
                      $0.nextLevel < final.level || ($0.nextLevel == final.level && $0.branch == final.branch)
                  }) else { return .invalid }
            return perform(.upgrade(slot: slot, branch: offer.branch))
        }
    }

    @discardableResult
    public func purchaseUpgrade(slot: Int, pathID: String) -> BuildResult {
        perform(.purchaseUpgrade(slot: slot, pathID: pathID))
    }

    @discardableResult
    public func execute(_ action: ScriptedBuildOrder.Action) -> BuildResult {
        switch action {
        case let .build(slot, id): return build(slot: slot, towerID: id)
        case let .upgrade(slot): return upgrade(slot: slot)
        case let .purchaseUpgrade(slot, pathID): return purchaseUpgrade(slot: slot, pathID: pathID)
        }
    }

    public func startNextWave() { _ = perform(.startWave) }
    public func step() { engine.advance(ticks: 1, interpolation: 0) }
    /// Production headless loops use wall-clock deadlines at the configured
    /// rate. At a high factor, deadlines are already past and no sleep occurs.
    /// Editor/display drivers pace externally and use the exact-tick step().
    public func stepPaced() {
        guard !engine.isPaused, engine.runRecorder?.finished != true else { return }
        if !pacingStarted { engine.timer.resync(); pacingStarted = true }
        engine.timer.waitUntilNextTick()
        step()
    }
    public func result() -> SimulationResult { engine.simulationResult() }

    public func run(steps: [ScriptedBuildOrder.Step], maxSeconds: Double,
                    strictOrder: Bool = false, reinforcements: ReinforcementStrategy = .immediate) throws -> SimulationResult {
        var completed = false
        defer { if !completed { finishRecording(status: .failed) } }
        var commander = ScriptedBuildOrder(steps: steps, strictOrder: strictOrder, reinforcements: reinforcements)
        while outcome == nil, time < maxSeconds {
            try commander.tick(sim: self)
            stepPaced()
        }
        let result = result()
        finishRecording(status: result.outcome == .victory ? .victory : result.outcome == .defeat ? .defeat : .timeout)
        completed = true
        return result
    }
}
