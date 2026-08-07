// CommanderPolicy.swift
// The simulation needs a player: towers don't place themselves, so every
// balance number is conditional on a policy. This is tier one of three —
// scripted build orders (regression suite / "intended solution" encoding).
// A greedy heuristic bot and a build-order optimizer slot in behind the same
// protocol later without touching the engine.
import Foundation

/// What happened when the policy tried to act. Policies use this to decide
/// whether to wait (needGold) or move on (invalid).
public enum BuildResult: Sendable, Equatable {
    case ok
    case needGold
    case invalid
}

/// Called once per tick, before spawning and combat. The policy inspects the
/// simulation read-only and issues actions through the build/upgrade API.
public protocol CommanderPolicy {
    mutating func tick(time: Double, sim: Simulation)
}

/// A hand-authored build order. Each step waits for its trigger time, then
/// retries every tick until gold allows (or the action proves invalid).
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
                cursor += 1        // done (or impossible; don't wedge the script)
            case .needGold:
                return             // wait for income; retry next tick
            }
        }
    }
}

/// Does nothing. Useful as a baseline: a level that towers-off still can't
/// leak everything is a level whose spawn table is broken.
public struct IdleCommander: CommanderPolicy, Sendable {
    public init() {}
    public mutating func tick(time: Double, sim: Simulation) {}
}
