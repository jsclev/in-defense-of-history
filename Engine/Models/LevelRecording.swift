import Foundation
import CoreGraphics

/// Every production driver must choose its recording destination explicitly.
/// Isolated encyclopedia scenes and unit fixtures are not level playthroughs.
public enum BattleRecording {
    case database(LevelRunDAO, LevelRunSource)
    case preview
}

enum LevelRecordingCodec {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        try autoreleasepool {
            let encoder = PropertyListEncoder(); encoder.outputFormat = .binary
            return try (encoder.encode(value) as NSData).compressed(using: .lz4) as Data
        }
    }
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try autoreleasepool {
            try PropertyListDecoder().decode(type, from: (data as NSData).decompressed(using: .lz4) as Data)
        }
    }
    static func json<T: Encodable>(_ value: T) throws -> String {
        try autoreleasepool {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            return String(decoding: try encoder.encode(value), as: UTF8.self)
        }
    }
}

/// The values actually used by this run, derived from the DAO-loaded content.
/// A replay remains faithful even after balancing edits or experiment changes.
struct LevelReplaySetup: Codable {
    struct Tower: Codable {
        let id: UUID
        let kind: TowerKind
        let level: Int
        let branch: Int
        let name: String
        let tuning: TowerLevel
    }
    struct RoadElement: Codable {
        let type: Int32
        let points: [CGPoint]
    }
    let level: LevelInfo
    let virtualCanvas: VirtualCanvas
    /// Absent only in recordings made before HUD capture was introduced.
    let hudLayout: HudLayoutConfig?
    let towers: [Tower]
    let enemies: [EnemyType]
    let difficulty: Difficulty
    let selectedMetaUpgrades: [MetaUpgrade]
    let heroes: [Hero]
    let heroCombat: [UUID: HeroCombatStats]
    let reinforcementConfig: ReinforcementConfig
    let seed: UInt64
    let startingMoney: Int
    let heroesEnabled: Bool
    let road: [RoadElement]
    let ticksPerSecond: Int
    let playSpeed: PlaySpeed

    @MainActor init(engine: BattleEngine, seed: UInt64, heroesEnabled: Bool) {
        let content = engine.content
        level = content.level; virtualCanvas = content.virtualCanvas
        hudLayout = content.hudLayout
        towers = content.arsenal.towers.flatMap { definition in
            definition.tiers.map { tier in
                Tower(id: tier.id, kind: definition.kind, level: tier.level, branch: tier.branch,
                    name: tier.details.name, tuning: tier.tuning)
            }
        }
        enemies = content.enemies; difficulty = content.difficulty
        heroes = content.deployments.map(\.hero); heroCombat = content.heroCombat
        reinforcementConfig = content.reinforcementConfig
        selectedMetaUpgrades = content.playerUpgrades.loadout.selected.sorted { $0.rawValue < $1.rawValue }
        self.seed = seed; startingMoney = engine.startingMoney; self.heroesEnabled = heroesEnabled
        ticksPerSecond = SimClock.ticksPerSecond
        playSpeed = engine.initialPlaySpeed
        var elements: [RoadElement] = []
        engine.roadSurfacePath.applyWithBlock { pointer in
            let element = pointer.pointee
            let count: Int
            switch element.type {
            case .moveToPoint, .addLineToPoint: count = 1
            case .addQuadCurveToPoint: count = 2
            case .addCurveToPoint: count = 3
            case .closeSubpath: count = 0
            @unknown default: preconditionFailure("Unsupported road path element")
            }
            elements.append(RoadElement(type: element.type.rawValue, points: (0..<count).map { element.points[$0] }))
        }
        road = elements
    }

    func roadSurface() throws -> CGPath {
        let path = CGMutablePath()
        for element in road {
            guard let type = CGPathElementType(rawValue: element.type) else { throw DbError.Db(message: "level_run.setup: invalid road element") }
            switch (type, element.points.count) {
            case (.moveToPoint, 1): path.move(to: element.points[0])
            case (.addLineToPoint, 1): path.addLine(to: element.points[0])
            case (.addQuadCurveToPoint, 2): path.addQuadCurve(to: element.points[1], control: element.points[0])
            case (.addCurveToPoint, 3): path.addCurve(to: element.points[2], control1: element.points[0], control2: element.points[1])
            case (.closeSubpath, 0): path.closeSubpath()
            default: throw DbError.Db(message: "level_run.setup: malformed road element")
            }
        }
        return path
    }
}

/// Resolved animation and metrics, not instructions to simulate combat again.
struct LevelReplayFrame: Codable {
    struct Hero: Codable, Identifiable {
        let id: Int
        let assetName: String
        let baseAssetName: String
        let position: CGPoint
        let hp: Double
        let maxHP: Double
        let isSelected: Bool
    }
    let tick: Int64
    let money: Int
    let lives: Int
    let wave: Int
    let outcome: Outcome?
    let paused: Bool
    let speed: Double
    let presentation: BattlePresentation
    let towers: [PlacedTower]
    let towerTuning: [Int: TowerLevel]
    let militia: [BattleEngine.MilitiaSoldier]
    let heroes: [Hero]
    let impacts: [BattleEngine.ArtilleryImpact]
    let obstacles: [EngineerObstacleField]
    let slowingTowerSlots: Set<Int>
    let rallies: [Int: CGPoint]
    let damageBySlot: [Int: Double]
    let targetingSecondsBySlot: [Int: Double]
    let shotsBySlot: [Int: Int]
    let selectedSlot: Int?
    let selectedTower: Int?
    let selectedHero: Int?
    /// Older recordings remain playable without inventing missing UI history.
    let hud: LevelHUDState?

    @MainActor init(_ engine: BattleEngine) {
        tick = engine.timer.tick; money = engine.money; lives = engine.lives
        wave = engine.waveSchedule.nextWaveIndex; outcome = engine.outcome
        paused = engine.isPaused; speed = engine.speedMultiplier
        presentation = engine.presentation; towers = engine.placedTowers
        towerTuning = Dictionary(uniqueKeysWithValues: engine.placedTowers.map { ($0.slotIndex, engine.towerLevel(for: $0)!) })
        militia = engine.militia; impacts = engine.artilleryImpacts
        heroes = engine.heroPosts.enumerated().compactMap { index, post in
            guard post.unit.state != .dead else { return nil }
            guard let pose = engine.heroPoses[index] else { preconditionFailure("Missing recorded hero pose") }
            let sample = pose.sample(alpha: 1)
            return Hero(id: index, assetName: sample.assetName, baseAssetName: post.assetName,
                position: CGPoint(x: sample.position.x, y: sample.position.y), hp: post.unit.hp,
                maxHP: post.combat.hp, isSelected: engine.selectedHeroIndex == index)
        }
        obstacles = engine.engineerObstacleFields; slowingTowerSlots = engine.engineerObstacleFeedback.towerSlots
        rallies = engine.rallyPointsBySlot; damageBySlot = engine.damageTotalBySlot
        targetingSecondsBySlot = engine.targetingSecondsBySlot; shotsBySlot = engine.shotsBySlot
        selectedSlot = engine.selectedSlotIndex; selectedTower = engine.selectedTowerSlotIndex
        selectedHero = engine.selectedHeroIndex
        hud = LevelHUDState(engine: engine)
    }
}

final class LevelRunRecorder {
    let dao: LevelRunDAO
    let id: UUID
    private(set) var sequence: Int64 = -1
    private var pending: [ReplayTimelineEvent] = []
    private var timeline = ReplayTimelineBuilder()
    private var pendingFrame: LevelReplayFrame?
    private var bufferedRows: [PendingLevelAction] = []
    private var bufferedBytes = 0
    private(set) var finished = false
    private var lastTick: Int64 = 0

    init(dao: LevelRunDAO, source: LevelRunSource, setup: LevelReplaySetup) throws {
        self.dao = dao
        id = try dao.begin(levelID: setup.level.id, source: source, playSpeed: setup.playSpeed, setup: LevelRecordingCodec.encode(setup))
    }
    func action(tick: Int64, category: String, name: String, payload: [String: String]) throws {
        guard !finished else { throw DbError.Db(message: "level_run[\(id)]: action after completion") }
        guard tick >= lastTick else { throw DbError.Db(message: "level_run[\(id)]: action time went backwards") }
        lastTick = tick
        let json = try LevelRecordingCodec.json(payload)
        // Publish the run's existence immediately. Subsequent events are packed
        // with their virtual-time tracks, rather than one SQL row per event.
        if sequence == -1, category == "lifecycle", name == "started" {
            try dao.append(runID: id, after: sequence,
                actions: [PendingLevelAction(tick: tick, category: category, name: name, payload: json)])
            sequence = 0
        } else {
            pending.append(ReplayTimelineEvent(tick: tick, category: category, name: name, payload: json))
        }
    }
    func frame(_ frame: LevelReplayFrame) throws {
        guard !finished else { return }
        guard frame.tick >= lastTick else { throw DbError.Db(message: "level_run[\(id)]: frame time went backwards") }
        if let previous = pendingFrame, previous.tick != frame.tick {
            try timeline.append(previous)
            if timeline.isFull || pending.count >= 512 { try flush() }
        }
        lastTick = frame.tick
        // Inputs can change the same tick repeatedly. Preserve every input,
        // but encode only its final visible pose, as playback has always done.
        pendingFrame = frame
    }
    deinit {
        if !finished {
            do { try finish(status: .abandoned, tick: lastTick, result: nil) }
            catch { fatalError("Cannot finalize abandoned level run \(id): \(error)") }
        }
    }
    private func flush() throws {
        guard let end = timeline.lastTick else { return }
        let count = pending.prefix { $0.tick <= end }.count
        let block = try timeline.finish(events: Array(pending.prefix(count)))
        let row = PendingLevelAction(tick: end, category: "presentation", name: LevelReplayTimeline.rowName,
                                    payload: "{}", presentation: try LevelRecordingCodec.encode(block))
        bufferedRows.append(row); bufferedBytes += row.presentation?.count ?? 0
        // Keep transactions short and memory bounded, but amortize their cost
        // over several complete blocks. Every terminal path drains this batch.
        if bufferedRows.count >= 4 || bufferedBytes >= 512 * 1024 { try persist() }
        pending.removeFirst(count)
        timeline = ReplayTimelineBuilder()
    }
    private func persist() throws {
        guard !bufferedRows.isEmpty else { return }
        try dao.append(runID: id, after: sequence, actions: bufferedRows)
        sequence += Int64(bufferedRows.count)
        bufferedRows.removeAll(keepingCapacity: true); bufferedBytes = 0
    }
    func finish(status: LevelRunStatus, tick: Int64, result: SimulationResult?) throws {
        guard !finished else { return }
        try action(tick: tick, category: "lifecycle", name: status.rawValue, payload: [:])
        if let frame = pendingFrame { try timeline.append(frame); pendingFrame = nil }
        try flush()
        try persist()
        guard pending.isEmpty else { throw DbError.Db(message: "level_run[\(id)]: unrecorded final events") }
        try dao.finish(id: id, status: status, resultJSON: result.map { try LevelRecordingCodec.json($0) })
        finished = true
    }
}
