import Foundation
import Observation

@MainActor
@Observable
final class SimSession {
    private(set) var blueprint: LevelBlueprint
    private(set) var level: LevelInfo
    let catalog: ContentCatalog
    private(set) var sim: Simulation

    var seed: UInt64 = 1776
    var speed: Int = 1
    var paused = false
    var autopilot = false
    var selectedSlot: Int?

    private(set) var banner: String?
    private(set) var bannerUntil: Double = 0
    private(set) var frame: Int = 0
    private(set) var deniedUntil: Double = 0
    private(set) var batchSummary: String?
    private(set) var recording: [MapDraft.BuildStep] = []

    struct Flash {
        var from: Point
        var to: Point
        var towerTypeIndex: Int
        var until: Double
    }
    private(set) var flashes: [Flash] = []

    private var accumulator = 0.0
    private var lastDate: Date?

    init(blueprint: LevelBlueprint) {
        let level = blueprint.makeLevel()
        let catalog = DesignArsenal.catalog()
        self.blueprint = blueprint
        self.level = level
        self.catalog = catalog
        self.sim = Self.freshSim(level: level, catalog: catalog, blueprint: blueprint,
                                 seed: 1776, autopilot: false)
        attachObserver()
    }

    private static func freshSim(
        level: LevelInfo, catalog: ContentCatalog, blueprint: LevelBlueprint,
        seed: UInt64, autopilot: Bool
    ) -> Simulation {
        let policy: any CommanderPolicy = autopilot ? blueprint.scriptedSolution() : IdleCommander()
        return try! Simulation(level: level, catalog: catalog, policy: policy, seed: seed)
    }

    func restart() {
        sim = Self.freshSim(level: level, catalog: catalog, blueprint: blueprint,
                            seed: seed, autopilot: autopilot)
        attachObserver()
        accumulator = 0
        lastDate = nil
        flashes = []
        banner = nil
        selectedSlot = nil
        batchSummary = nil
        recording = []
        paused = false
        frame += 1
    }

    func select(blueprint bp: LevelBlueprint) {
        blueprint = bp
        level = bp.makeLevel()
        restart()
    }

    func advance(to date: Date) {
        guard !paused, sim.outcome == nil else { lastDate = date; return }
        defer { frame += 1 }
        guard let last = lastDate else { lastDate = date; return }
        let dt = min(0.25, date.timeIntervalSince(last))
        lastDate = date
        accumulator += dt * Double(SimClock.ticksPerSecond * speed)
        var steps = Int(accumulator)
        accumulator -= Double(steps)
        steps = min(steps, SimClock.ticksPerSecond * 8)
        for _ in 0..<steps where sim.outcome == nil {
            sim.step()
        }
        flashes.removeAll { $0.until < sim.time }
        if let until = banner.map({ _ in bannerUntil }), sim.time > until {
            banner = nil
        }
    }

    func build(_ e: Emplacement, at slot: Int) {
        let result = sim.build(slot: slot, towerID: e.id)
        if result == .needGold { deniedUntil = sim.time + 0.7 }
        if result == .ok {
            recording.append(.init(at: recordTime, kind: "place",
                                   emplacement: e.rawValue, slot: slot))
        }
        frame += 1
    }

    func upgrade(slot: Int) {
        let result = sim.upgrade(slot: slot)
        if result == .needGold { deniedUntil = sim.time + 0.7 }
        if result == .ok {
            recording.append(.init(at: recordTime, kind: "upgrade",
                                   emplacement: nil, slot: slot))
        }
        frame += 1
    }

    private var recordTime: Double {
        max(1, (sim.time * 2).rounded() / 2)
    }

    var currentWave: Int {
        level.waves.filter { $0.startTime <= sim.time }.count
    }

    var goldDenied: Bool { sim.time < deniedUntil }

    func towerType(at slot: Int) -> (type: TowerType, level: Int)? {
        guard let t = sim.towers[slot] else { return nil }
        return (catalog.towerTypes[t.typeIndex], t.level)
    }

    func runQuickBatch() {
        let report = try? Batch.run(
            level: level, catalog: catalog, baseSeed: seed, count: 100
        ) { _ -> any CommanderPolicy in
            blueprint.scriptedSolution()
        }
        guard let r = report else { return }
        batchSummary = String(
            format: "Intended solution, 100 seeds: %.0f%% wins · lives p50 %.0f/%d · rout share %.1f%%",
            r.winRate * 100, r.livesPercentile(50), blueprint.lives, r.routShare * 100
        )
    }

    private func attachObserver() {
        let collector = Collector(session: self)
        sim.addObserver(collector)
    }

    private final class Collector: SimulationObserver {
        weak var session: SimSession?

        init(session: SimSession) {
            self.session = session
        }

        func handle(_ event: SimEvent, atTime time: Double) {
            MainActor.assumeIsolated {
                guard let s = session else { return }
                switch event {
                case let .waveStarted(index):
                    s.banner = "Wave \(index + 1) of \(s.level.waves.count)"
                    s.bannerUntil = time + 3.0
                case let .towerFired(slot, target):
                    guard let tower = s.sim.towers[slot] else { return }
                    s.flashes.append(Flash(
                        from: s.level.towerSlots[slot].position,
                        to: target,
                        towerTypeIndex: tower.typeIndex,
                        until: time + 0.18
                    ))
                default:
                    break
                }
            }
        }
    }
}
