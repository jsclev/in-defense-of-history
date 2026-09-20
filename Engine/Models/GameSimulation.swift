import Foundation

/// Headless input driver. It owns no battle state or gameplay rules.
@MainActor
public final class GameSimulation {
    let engine: BattleEngine
    public let content: BattleContent
    private var chosenPaths: [Int: DesignArsenal.Tier] = [:]
    private var observers: [SimulationObserver] = []

    public init(content: BattleContent, startingMoney: Int?, heroesEnabled: Bool, seed: UInt64) throws {
        self.content = content
        engine = try BattleEngine(content: content, heroesEnabled: heroesEnabled,
            startingMoneyOverride: startingMoney, seed: seed, onVictory: { _, _ in 0 })
        engine.onEvent = { [weak self] event, time in
            guard let self else { return }
            for observer in self.observers { observer.handle(event, atTime: time) }
        }
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
    public func perform(_ command: BattleCommand) -> BuildResult { engine.perform(command) }

    /// The tier ID is the commander's intended final branch, not a request to
    /// skip construction. Only the engine decides whether the build is legal.
    @discardableResult
    public func build(slot: Int, towerID: UUID) -> BuildResult {
        guard let definition = content.arsenal.towers.first(where: { $0.tiers.contains { $0.id == towerID } }),
              let final = definition.tiers.first(where: { $0.id == towerID }) else { return .invalid }
        let result = perform(.build(slot: slot, kind: definition.kind))
        if result == .ok { chosenPaths[slot] = final }
        return result
    }

    @discardableResult
    public func upgrade(slot: Int) -> BuildResult {
        guard let final = chosenPaths[slot],
              let offer = engine.upgradeOffers(at: slot).first(where: {
                  $0.nextLevel < final.level || ($0.nextLevel == final.level && $0.branch == final.branch)
              }) else { return .invalid }
        return perform(.upgrade(slot: slot, branch: offer.branch))
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
    public func result() -> SimulationResult { engine.simulationResult() }

    public func run(steps: [ScriptedBuildOrder.Step], maxSeconds: Double,
                    strictOrder: Bool = false) throws -> SimulationResult {
        var commander = ScriptedBuildOrder(steps: steps, strictOrder: strictOrder)
        while outcome == nil, time < maxSeconds {
            try commander.tick(sim: self)
            step()
        }
        return result()
    }
}
