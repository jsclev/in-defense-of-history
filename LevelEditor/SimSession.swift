import Foundation
import Observation

@MainActor
@Observable
final class SimSession {
    private let runDAO: LevelRunDAO
    let blueprint: LevelBlueprint
    let content: BattleContent
    var level: LevelInfo { content.level }
    var virtualCanvas: VirtualCanvas { content.virtualCanvas }
    var arsenal: DesignArsenal { content.arsenal }
    private(set) var sim: GameSimulation
    private var commander: ScriptedBuildOrder

    var seed: UInt64 = 1776
    var speed: Double {
        get { sim.playSpeed.factor }
        set {
            do { sim.setPlaySpeed(try PlaySpeed(newValue)) }
            catch { fail(error) }
        }
    }
    var paused = false {
        didSet {
            lastDate = nil
            if paused { sim.pause() } else { sim.resume() }
        }
    }
    var autopilot = false { didSet { sim.recordDriverControl("editorAutopilot", value: String(autopilot)) } }
    var selectedSlot: Int? { didSet { sim.recordDriverControl("editorSelectSlot", value: selectedSlot.map(String.init) ?? "none") } }
    private(set) var banner: String?
    private(set) var bannerUntil: Double = 0
    private(set) var frame: Int = 0
    private(set) var deniedUntil: Double = 0
    private(set) var batchSummary: String?
    private(set) var recording: [MapDraft.BuildStep] = []

    struct Flash {
        var from: Point
        var to: Point
        var kind: TowerKind
        var until: Double
    }
    private(set) var flashes: [Flash] = []
    private var accumulator = 0.0
    private var lastDate: Date?

    init(draft: MapDraft, db: Db, virtualCanvas: VirtualCanvas) throws {
        runDAO = db.levelRunDao
        let levelID = try db.levelInfoDao.getIdForEditorDocument(named: draft.name)
        let record = try db.levelInfoDao.getBy(id: levelID)
        let arsenal = try db.towerTypeDao.getDesignArsenal()
        blueprint = try draft.makeBlueprint(virtualCanvas: virtualCanvas, arsenal: arsenal)
        let geometry = try GeoJSONExport(virtualCanvas: virtualCanvas).data(for: draft)
        guard let routes = try LevelGeoJSONDAO.enemyRoutes(from: geometry), !routes.isEmpty else {
            throw DbError.Db(message: "Playtest requires authored enemy routes, just like the game.")
        }
        let preview = blueprint.makeLevel()
        var level = LevelInfo(id: levelID, name: record.name, campaign: record.campaign,
            startedAt: record.startedAt, endedAt: record.endedAt, startingMoney: record.startingMoney,
            numStartingLives: record.numStartingLives, numWaves: preview.numWaves, playArea: preview.playArea,
            mapImageName: record.mapImageName, paths: preview.paths, towerSlots: preview.towerSlots, waves: preview.waves)
        level.paths = routes.map { Path(points: $0.points) }
        level.waves = try draft.waves.map { wave in
            Wave(startTime: 0, spawns: try wave.lines.map { line in
                guard let foe = Foe(rawValue: line.foe) else {
                    throw DbError.Db(message: "Unknown enemy key '\(line.foe)'")
                }
                return SpawnEntry(enemyTypeID: foe.id, count: line.count, interval: line.every,
                                  delay: line.delay, pathIndex: line.road)
            }, callButtonDelay: wave.callButtonDelay, autoStartCountdown: wave.autoStartCountdown,
                 earlyCallBonus: wave.earlyCallBonus)
        }
        let input = BattleDraft(level: level,
            heroes: try LevelGeoJSONDAO.heroConfiguration(from: geometry),
            movementArea: try HeroMovementArea(geoJSON: geometry, defaultPathWidth: virtualCanvas.pathWidth),
            callButtons: try LevelGeoJSONDAO.callWaveButtons(from: geometry), exits: draft.exits)
        content = try BattleContent(db: db, levelID: levelID, draft: input)
        sim = try GameSimulation(recording: .database(runDAO, .editor), content: content, playSpeed: content.playSpeeds.editor, startingMoney: nil, heroesEnabled: true, seed: 1776)
        commander = blueprint.scriptedSolution(arsenal: arsenal)
        attachObserver()
    }

    func restart() {
        do {
            sim.finishRecording(status: .abandoned)
            sim = try GameSimulation(recording: .database(runDAO, .editor), content: content, playSpeed: content.playSpeeds.editor, startingMoney: nil, heroesEnabled: true, seed: seed)
            commander = blueprint.scriptedSolution(arsenal: arsenal)
            attachObserver()
            accumulator = 0; lastDate = nil; flashes = []; banner = nil
            selectedSlot = nil; batchSummary = nil; recording = []; paused = false
            frame += 1
        } catch { fail(error) }
    }

    func advance(to date: Date) {
        guard !paused, sim.outcome == nil else { lastDate = date; return }
        defer { frame += 1 }
        guard let last = lastDate else { lastDate = date; return }
        accumulator += max(0, date.timeIntervalSince(last)) * Double(SimClock.ticksPerSecond) * speed
        lastDate = date
        let steps = Int(min(accumulator, Double(SimClock.ticksPerSecond * 8)))
        accumulator -= Double(steps)
        do {
            for _ in 0..<steps where sim.outcome == nil {
                if autopilot { try commander.tick(sim: sim) }
                sim.step()
            }
        } catch { fail(error) }
        flashes.removeAll { $0.until < sim.time }
        if banner != nil, sim.time > bannerUntil, !paused { banner = nil }
    }

    func build(_ kind: TowerKind, at slot: Int) {
        let result = sim.perform(.build(slot: slot, kind: kind))
        if result == .needGold { deniedUntil = sim.time + 0.7 }
        if result == .ok {
            recording.append(.init(at: recordTime, kind: "place", emplacement: kind.rawValue, slot: slot))
        }
        frame += 1
    }

    func upgrade(slot: Int, branch: Int) {
        let result = sim.perform(.upgrade(slot: slot, branch: branch))
        if result == .needGold { deniedUntil = sim.time + 0.7 }
        if result == .ok {
            recording.append(.init(at: recordTime, kind: "upgrade", emplacement: nil, slot: slot))
        }
        frame += 1
    }

    private var recordTime: Double { (sim.time * 2).rounded() / 2 }
    var currentWave: Int { sim.currentWave }
    var goldDenied: Bool { sim.time < deniedUntil }
    func tower(at slot: Int) -> BattleTowerSnapshot? { sim.towers.first { $0.slot == slot } }

    func runQuickBatch() {
        do {
            var results: [SimulationResult] = []
            for index in 0..<100 {
                let trial = try GameSimulation(recording: .database(runDAO, .editor), content: content, startingMoney: nil,
                                               heroesEnabled: true, seed: seed &+ UInt64(index))
                results.append(try trial.run(steps: blueprint.scriptedSolution(arsenal: arsenal).steps, maxSeconds: 1800))
            }
            let report = BatchReport(results: results)
            batchSummary = String(format: "Intended solution, 100 seeds: %.0f%% wins · lives p50 %.0f/%d",
                                  report.winRate * 100, report.livesPercentile(50), level.numStartingLives)
        } catch { fail(error) }
    }

    private func fail(_ error: Error) { paused = true; banner = "Playtest stopped: \(error)" }
    private func attachObserver() { sim.addObserver(Collector(session: self)) }

    private final class Collector: SimulationObserver {
        weak var session: SimSession?
        init(session: SimSession) { self.session = session }
        func handle(_ event: SimEvent, atTime time: Double) {
            MainActor.assumeIsolated {
                guard let s = session else { return }
                switch event {
                case let .waveStarted(index):
                    s.banner = "Wave \(index + 1) of \(s.level.waves.count)"
                    s.bannerUntil = time + 3
                case let .towerFired(slot, target):
                    guard let tower = s.tower(at: slot) else { return }
                    s.flashes.append(Flash(from: tower.position, to: target, kind: tower.kind, until: time + 0.18))
                default: break
                }
            }
        }
    }
}
