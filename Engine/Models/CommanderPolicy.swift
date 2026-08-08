import Foundation

public enum BuildResult: Sendable, Equatable {
    case ok
    case needGold
    case invalid
}

public protocol CommanderPolicy {
    mutating func tick(time: Double, sim: Simulation)
}

public struct ScriptedBuildOrder: CommanderPolicy, Sendable {
    public enum Action: Sendable, Equatable {
        case build(slot: Int, towerID: UUID)
        case upgrade(slot: Int)
    }

    public struct Step: Sendable, Equatable {
        public var time: Double
        public var action: Action

        public init(time: Double, action: Action) {
            self.time = time
            self.action = action
        }
    }

    private let steps: [Step]
    private var cursor: Int = 0

    public init(steps: [Step]) {
        self.steps = steps.sorted { $0.time < $1.time }
    }

    public mutating func tick(time: Double, sim: Simulation) {
        while cursor < steps.count, steps[cursor].time <= time {
            let result: BuildResult
            switch steps[cursor].action {
            case let .build(slot, towerID):
                result = sim.build(slot: slot, towerID: towerID)
            case let .upgrade(slot):
                result = sim.upgrade(slot: slot)
            }
            switch result {
            case .ok, .invalid:
                cursor += 1
            case .needGold:
                return
            }
        }
    }
}

public struct IdleCommander: CommanderPolicy, Sendable {
    public init() {}
    public mutating func tick(time: Double, sim: Simulation) {}
}
