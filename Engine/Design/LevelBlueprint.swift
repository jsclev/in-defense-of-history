// LevelBlueprint.swift
// Art-free level authoring. A blueprint is the whole level-design surface —
// paths, slots, waves, pacing, and the intended-solution build order — in a
// 1600x900 virtual space. makeLevel() compiles it to the engine's LevelInfo;
// no artwork, database, or renderer involved.
import Foundation
import CoreGraphics

public struct LevelBlueprint: Sendable {
    public static let designWidth: Double = 1600
    public static let designHeight: Double = 900

    public struct Road: Sendable {
        public var name: String
        public var waypoints: [Point]

        public init(_ name: String, _ waypoints: [Point]) {
            self.name = name
            self.waypoints = waypoints
        }
    }

    public struct SpawnLine: Sendable {
        public var foe: Foe
        public var count: Int
        public var every: Double
        public var delay: Double
        public var road: Int

        public init(_ foe: Foe, count: Int, every: Double, delay: Double = 0, road: Int = 0) {
            self.foe = foe
            self.count = count
            self.every = every
            self.delay = delay
            self.road = road
        }

        var lastSpawnTime: Double { delay + Double(max(0, count - 1)) * every }
    }

    public struct WaveSketch: Sendable {
        /// Seconds between the previous wave's final spawn and this wave's first.
        public var breather: Double
        public var lines: [SpawnLine]

        public init(breather: Double = 10, lines: [SpawnLine]) {
            self.breather = breather
            self.lines = lines
        }
    }

    public struct BuildStep: Sendable {
        public enum Order: Sendable {
            case place(Emplacement, slot: Int)
            case upgrade(slot: Int)
        }
        public var at: Double
        public var order: Order

        public init(at: Double, _ order: Order) {
            self.at = at
            self.order = order
        }
    }

    public var name: String
    public var startingGold: Int
    public var lives: Int
    public var roads: [Road]
    public var slots: [Point]
    public var waves: [WaveSketch]
    /// The designer's intended solution; the balance harness plays this.
    public var intendedSolution: [BuildStep]

    public init(
        name: String,
        startingGold: Int,
        lives: Int,
        roads: [Road],
        slots: [Point],
        waves: [WaveSketch],
        intendedSolution: [BuildStep] = []
    ) {
        self.name = name
        self.startingGold = startingGold
        self.lives = lives
        self.roads = roads
        self.slots = slots
        self.waves = waves
        self.intendedSolution = intendedSolution
    }

    /// Stable per-blueprint id derived from the name, so runs and reports
    /// reference the same level across processes.
    public var id: UUID {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in name.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100_0000_01b3
        }
        let hex = String(format: "%016llx", hash)
        let a = String(hex.prefix(8))
        let b = String(hex.dropFirst(8).prefix(4))
        return UUID(uuidString: "\(a)-\(b)-4000-8000-b1e0b1e0b1e0")!
    }

    public func makeLevel() -> LevelInfo {
        var compiled: [Wave] = []
        var clock = 0.0
        for sketch in waves {
            let start = clock + sketch.breather
            compiled.append(Wave(
                startTime: start,
                spawns: sketch.lines.map {
                    SpawnEntry(
                        enemyTypeID: $0.foe.id,
                        count: $0.count,
                        interval: $0.every,
                        delay: $0.delay,
                        pathIndex: $0.road
                    )
                }
            ))
            clock = start + (sketch.lines.map(\.lastSpawnTime).max() ?? 0)
        }
        return LevelInfo(
            id: id,
            name: name,
            campaign: Campaign(id: id, name: "Design Lab"),
            startedAt: Date(timeIntervalSince1970: 0),
            endedAt: Date(timeIntervalSince1970: 0),
            startingMoney: startingGold,
            numStartingLives: lives,
            numWaves: waves.count,
            playableRect: CGRect(x: 0, y: 0, width: Self.designWidth, height: Self.designHeight),
            paths: roads.map { Path(points: $0.waypoints) },
            towerSlots: slots.enumerated().map { i, p in
                // Slot ids only need to be stable within the blueprint.
                TowerSlot(id: UUID(uuidString: String(format: "b0000000-0000-4000-8000-%012d", i))!, position: p)
            },
            waves: compiled
        )
    }

    public func scriptedSolution() -> ScriptedBuildOrder {
        ScriptedBuildOrder(steps: intendedSolution.map { step in
            switch step.order {
            case let .place(e, slot):
                return ScriptedBuildOrder.Step(time: step.at, action: .build(slot: slot, towerID: e.id))
            case let .upgrade(slot):
                return ScriptedBuildOrder.Step(time: step.at, action: .upgrade(slot: slot))
            }
        })
    }
}
