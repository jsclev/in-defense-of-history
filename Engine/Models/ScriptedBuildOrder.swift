import Foundation

/// A player's decisions, separate from gameplay. All action results come from
/// the engine. Waiting, build priority and charge-site choice are strategy.
public struct ScriptedBuildOrder: Sendable {
    public enum Action: Sendable, Equatable {
        case build(slot: Int, towerID: UUID)
        case upgrade(slot: Int)
        case purchaseUpgrade(slot: Int, pathID: String)

        var slot: Int {
            switch self {
            case let .build(slot, _), let .upgrade(slot), let .purchaseUpgrade(slot, _): return slot
            }
        }
    }

    public struct Step: Sendable, Equatable {
        public var time: Double
        public var action: Action
        public init(time: Double, action: Action) { self.time = time; self.action = action }
    }

    public let steps: [Step]
    private var pending: [(offset: Int, element: Step)]
    private let strictOrder: Bool

    public init(steps: [Step], strictOrder: Bool = false) {
        self.steps = steps
        pending = Array(steps.enumerated())
        self.strictOrder = strictOrder
    }

    @MainActor public mutating func tick(sim: GameSimulation) throws {
        var blockedSlots: Set<Int> = []
        var done: Set<Int> = []
        for (index, step) in pending {
            let slot = step.action.slot
            guard step.time <= sim.time, !blockedSlots.contains(slot) else {
                blockedSlots.insert(slot)
                if strictOrder { break }
                continue
            }
            switch sim.execute(step.action) {
            case .ok: done.insert(index)
            case .needGold: blockedSlots.insert(slot)
            case .invalid: throw DbError.Db(message: "Engine rejected scripted command: \(step.action)")
            }
            if strictOrder && blockedSlots.contains(slot) { break }
        }
        pending.removeAll { done.contains($0.offset) }
        for site in sim.readyDemolitionSites {
            _ = sim.perform(.placeDemolition(slot: site.slot, point: site.point))
        }
        // This commander chooses to call wave one after its opening purchases.
        // Subsequent automatic starts and all rewards belong to the engine.
        if sim.currentWave == 0 { sim.startNextWave() }
    }
}
