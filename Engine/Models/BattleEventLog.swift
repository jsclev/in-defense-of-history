import Foundation
import CoreGraphics

struct BattleEventUnitKey: Hashable {
    let hero: Bool
    let id: Int
}

/// Timestamped changes to simulation data. No frame, sprite, pose, or renderer
/// is visited by this writer. Playback alone resolves the recorded data to art.
struct BattleEventChanges<Value: Codable & Equatable>: Codable {
    struct Change: Codable { let tick: Int64; let value: Value }
    var changes: [Change] = []

    mutating func append(_ value: Value, at tick: Int64) {
        if changes.last?.value != value { changes.append(Change(tick: tick, value: value)) }
    }
    func value(at tick: Int64) throws -> Value {
        guard let change = changes.last(where: { $0.tick <= tick }) else {
            throw DbError.Db(message: "battle events: missing initial state at tick \(tick)")
        }
        return change.value
    }
    func validate(first: Int64, last: Int64) throws {
        guard changes.first?.tick == first, changes.allSatisfy({ $0.tick >= first && $0.tick <= last }),
              zip(changes, changes.dropFirst()).allSatisfy({ $0.tick < $1.tick }) else {
            throw DbError.Db(message: "battle events: missing or unordered state changes in ticks \(first)...\(last)")
        }
    }
}

/// Observed numeric changes, packed into exact runs of repeated increments.
/// This never predicts movement or applies combat rules. A changed increment,
/// bend, spawn, hit, or stop starts a new timestamped segment.
struct BattleEventNumbers: Codable {
    struct Segment: Codable {
        let tick: Int64
        var count: Int
        let values: [Double]
        var increments: [Double]?
    }
    private(set) var segments: [Segment] = []
    private var previous: [Double] = []

    enum CodingKeys: CodingKey { case segments }
    init() {}
    init(segments: [Segment]) { self.segments = segments }
    init(from decoder: Decoder) throws {
        segments = try decoder.container(keyedBy: CodingKeys.self).decode([Segment].self, forKey: .segments)
    }
    /// Round the observed replay state once. Combat continues using its original
    /// values. Segment increments must also fit Float and reproduce each rounded
    /// observation exactly; otherwise a new segment starts at that tick.
    mutating func appendFloat32(_ values: [Double], at tick: Int64) throws {
        let rounded = try values.map { value -> Double in
            let stored = Float(value)
            guard !value.isNaN, !value.isFinite || stored.isFinite else {
                throw DbError.Db(message: "battle events: value outside Float range at tick \(tick)")
            }
            return Double(stored)
        }
        append(rounded, at: tick, float32Increments: true)
    }

    mutating func append(_ values: [Double], at tick: Int64, float32Increments: Bool = false) {
        if let last = segments.last, last.tick + Int64(last.count) == tick, previous.count == values.count {
            let index = segments.count - 1
            if let increments = last.increments,
               zip(zip(previous, increments), values).allSatisfy({ ($0.0.0 + $0.0.1).bitPattern == $0.1.bitPattern }) {
                segments[index].count += 1; previous = values; return
            }
            if last.increments == nil, zip(previous, values).allSatisfy({ $0.bitPattern == $1.bitPattern }) {
                segments[index].count += 1; previous = values; return
            }
            if last.count == 1 {
                let increments = zip(values, previous).map { value, previous -> Double in
                    if value.bitPattern == previous.bitPattern { return 0 }
                    let difference = value - previous
                    return float32Increments ? Double(Float(difference)) : difference
                }
                if increments.allSatisfy(\.isFinite),
                   zip(zip(previous, increments), values).allSatisfy({ ($0.0.0 + $0.0.1).bitPattern == $0.1.bitPattern }) {
                    segments[index].increments = increments; segments[index].count = 2; previous = values; return
                }
            }
        }
        segments.append(Segment(tick: tick, count: 1, values: values, increments: nil))
        previous = values
    }
    func values(at tick: Int64) throws -> [Double] {
        guard let segment = segments.last(where: { $0.tick <= tick }), segment.tick >= 0, segment.count > 0,
              tick - segment.tick < Int64(segment.count) else {
            throw DbError.Db(message: "battle events: missing numeric state at tick \(tick)")
        }
        var values = segment.values
        if let increments = segment.increments {
            guard increments.count == values.count, increments.allSatisfy(\.isFinite) else {
                throw DbError.Db(message: "battle events: malformed numeric change")
            }
            // Repeated addition preserves the actual recorded rounding.
            for _ in segment.tick..<tick {
                for i in values.indices { values[i] += increments[i] }
            }
        }
        return values
    }
    func validate(first: Int64, last: Int64) throws {
        var next = first
        for segment in segments {
            guard segment.tick == next, segment.count > 0, segment.count <= 256,
                  Int64(segment.count) <= last - next + 1,
                  segment.values.allSatisfy({ !$0.isNaN }),
                  segment.increments.map({ $0.count == segment.values.count && $0.allSatisfy(\.isFinite) }) != false else {
                throw DbError.Db(message: "battle events: missing or malformed numeric segment at tick \(next)")
            }
            next += Int64(segment.count)
        }
        guard next == last + 1 else { throw DbError.Db(message: "battle events: truncated numeric changes at tick \(next)") }
    }
}

struct BattleEventUnit: Codable, Equatable {
    let id: Int
    let hero: Bool
    let baseAsset: String
    let maxHP: Double
    /// Absent in historical recordings, which did not record melee swings.
    var attackInterval: Double? = nil
}

struct BattleEventStatus: Codable, Equatable {
    let money: Int
    let lives: Int
    let wave: Int
    let outcome: Outcome?
    let paused: Bool
    let speed: Double
    let selectedSlot: Int?
    let selectedTower: Int?
    let selectedHero: Int?
    let rallies: [Int: CGPoint]
    let slowingSlots: Set<Int>
    let damage: [Int: Double]
    let targeting: [Int: Double]
    let shots: [Int: Int]
}

/// Engine decisions that affect controls; labels, animation and geometry are
/// resolved during playback, never by the search recorder.
struct BattleEventControls: Codable, Equatable {
    let heroes: [UUID]
    let availableHeroes: [UUID]
    let selectedHero: UUID?
    let canReinforce: Bool
    let placingReinforcements: Bool
    let activationTicks: [LevelHUDControl: Int64]
    let wavePositions: [Point]
    let wave: Int
    let nextWave: Int
    let countdown: Int?
    let waveSelection: CallWaveButtonSelection
}

/// Immutable observed tuning, shared by captures until a purchase or authored
/// tuning change. The encoded copy belongs to this recorder, never a content
/// catalog. Each stored block still contains everything needed to decode it.
final class BattleEventTuningSnapshot {
    let values: [Int: TowerLevel]
    private var encoded: Data?

    init(_ values: [Int: TowerLevel]) { self.values = values }

    func data() throws -> Data {
        if let encoded { return encoded }
        let encoder = PropertyListEncoder(); encoder.outputFormat = .binary
        let data = try encoder.encode(values)
        encoded = data
        return data
    }
}

final class BattleEventCaptureCache {
    private struct TowerInput: Equatable {
        let slot: Int
        let kind: TowerKind
        let level: Int
        let branch: Int
        let upgrades: TowerUpgradeProgress
        init(_ tower: PlacedTower) {
            slot = tower.slotIndex; kind = tower.kind; level = tower.level
            branch = tower.branch; upgrades = tower.upgrades
        }
    }
    private weak var owner: BattleEngine?
    private var revision: UInt64?
    private var inputs: [TowerInput] = []
    private var snapshot: BattleEventTuningSnapshot?

    @MainActor func tuning(_ engine: BattleEngine) -> BattleEventTuningSnapshot {
        let next = engine.placedTowers.map(TowerInput.init)
        if owner === engine, revision == engine.recordingTowerTuningRevision,
           inputs == next, let snapshot { return snapshot }
        let values = Dictionary(uniqueKeysWithValues: engine.placedTowers.map {
            ($0.slotIndex, engine.towerLevel(for: $0)!)
        })
        let result = BattleEventTuningSnapshot(values)
        owner = engine; revision = engine.recordingTowerTuningRevision
        inputs = next; snapshot = result
        return result
    }
}

/// Copies only resolved simulation values. Numeric fields are separated from
/// entity definitions so static content is not encoded once per entity per tick.
struct BattleEventState {
    let tick: Int64
    let enemies: [BattleEngine.Walker]
    let enemyNumbers: [Double]
    let projectiles: [BattleEngine.Projectile]
    let projectileNumbers: [Double]
    let units: [BattleEventUnit]
    let unitNumbers: [Double]
    let towers: [PlacedTower]
    let tuningSnapshot: BattleEventTuningSnapshot
    var tuning: [Int: TowerLevel] { tuningSnapshot.values }
    let impacts: [BattleEngine.ArtilleryImpact]
    let obstacles: [EngineerObstacleField]
    let status: BattleEventStatus
    let controls: BattleEventControls
    let clockNumbers: [Double]

    @MainActor init(_ engine: BattleEngine, cache: BattleEventCaptureCache = BattleEventCaptureCache()) {
        tick = engine.timer.tick
        var enemyValues: [Double] = []
        enemyValues.reserveCapacity(engine.walkers.count * 8)
        enemies = engine.walkers.map { original in
            var value = original
            enemyValues += [value.hp, value.position.x, value.position.y, value.pathDistance,
                value.morale.value, value.morale.impactAge, value.morale.valueBeforeImpact, value.morale.flinchDirection]
            // These are storage templates, never game content or fallbacks.
            // The decoder requires all eight observed values for every entity.
            value.hp = 0; value.position = .zero; value.pathDistance = 0
            value.morale.restoreRecordedValues(value: 0, age: 0, before: 0, direction: 0)
            return value
        }
        enemyNumbers = enemyValues
        var projectileValues: [Double] = []
        projectileValues.reserveCapacity(engine.projectiles.count * 5)
        projectiles = engine.projectiles.map { original in
            var value = original
            projectileValues += [value.position.x, value.position.y, value.heading,
                value.grapeshot.map { Double($0.remainingDistance) } ?? 0,
                value.solidShot.map { Double($0.remainingDistance) } ?? 0]
            value.position = .zero; value.heading = 0
            value.grapeshot?.remainingDistance = 0
            value.solidShot?.restoreRecordedDistance(0)
            return value
        }
        projectileNumbers = projectileValues
        var unitDefinitions: [BattleEventUnit] = [], unitValues: [Double] = []
        let unitCount = engine.garrisonsBySlot.values.reduce(engine.heroPosts.count) { $0 + $1.units.count }
        unitDefinitions.reserveCapacity(unitCount); unitValues.reserveCapacity(unitCount * 8)
        func unit(id: Int, hero: Bool, asset: String, unit: MilitiaUnit, maxHP: Double,
                  respawned: Bool, attackInterval: Double? = nil) {
            let key = BattleEventUnitKey(hero: hero, id: id)
            let target = engine.recordedFacingTargets[key]
            unitDefinitions.append(BattleEventUnit(id: id, hero: hero, baseAsset: asset,
                                                   maxHP: maxHP, attackInterval: attackInterval))
            unitValues += [unit.position.x, unit.position.y, unit.hp, target == nil ? 0 : 1,
                           target?.x ?? 0, target?.y ?? 0, respawned ? 1 : 0,
                           Double(unit.swingTicksLeft)]
        }
        for slot in engine.garrisonsBySlot.keys.sorted() {
            guard let garrison = engine.garrisonsBySlot[slot],
                  let resolved = engine.garrisonMelee(slot: slot, garrison: garrison) else { continue }
            for (index, soldier) in garrison.units.enumerated() where soldier.state != .dead {
                let id = slot * 8 + index
                unit(id: id, hero: false, asset: MeleeUnitFamily(garrisonSlot: slot).rawValue,
                     unit: soldier, maxHP: resolved.stats.hp,
                     respawned: engine.militiaRespawnedIDs.contains(id),
                     attackInterval: resolved.stats.attackInterval)
            }
        }
        for (id, post) in engine.heroPosts.enumerated() where post.unit.state != .dead {
            unit(id: id, hero: true, asset: post.assetName, unit: post.unit, maxHP: post.combat.hp,
                 respawned: engine.heroRespawnedIDs.contains(id))
        }
        units = unitDefinitions; unitNumbers = unitValues
        towers = engine.placedTowers
        tuningSnapshot = cache.tuning(engine)
        impacts = engine.artilleryImpacts
        obstacles = engine.engineerObstacleFields
        status = BattleEventStatus(money: engine.money, lives: engine.lives, wave: engine.waveSchedule.nextWaveIndex,
            outcome: engine.outcome, paused: engine.isPaused, speed: engine.speedMultiplier,
            selectedSlot: engine.selectedSlotIndex, selectedTower: engine.selectedTowerSlotIndex,
            selectedHero: engine.selectedHeroIndex, rallies: engine.rallyPointsBySlot,
            slowingSlots: engine.engineerObstacleFeedback.towerSlots, damage: engine.damageTotalBySlot,
            targeting: engine.targetingSecondsBySlot, shots: engine.shotsBySlot)
        let hudHeroes = engine.hudHeroes
        controls = BattleEventControls(heroes: hudHeroes.map(\.id), availableHeroes: hudHeroes.compactMap {
                engine.hudHeroIndex(for: $0.id) == nil ? nil : $0.id
            }, selectedHero: engine.selectedHeroIndex.map { engine.heroPosts[$0].hero.id },
            canReinforce: engine.canCallReinforcements, placingReinforcements: engine.isPlacingReinforcements,
            activationTicks: engine.hudActivationTicks,
            wavePositions: engine.awaitingWaveStart ? engine.callWaveButtonPositions : [],
            wave: engine.currentWaveNumber, nextWave: engine.nextWaveNumber,
            countdown: engine.waveCountdownSeconds, waveSelection: engine.callWaveSelection)
        clockNumbers = [Double(engine.lastMilitiaTick), engine.reinforcementCooldown.remainingSeconds,
                        engine.reinforcementCooldown.remainingFraction]
    }
}

/// Self-contained, bounded batches of actions and state-change events. Stored
/// as event rows, with no presentation rows or per-tick frame snapshots.
struct BattleEventBlock: Codable {
    static let rowName = "battle-events-v5"
    static let preciseRowName = "battle-events-v3"
    static let sharedRowName = "battle-events-v4"
    static let packedLegacyRowName = "battle-events-v2"
    static let legacyRowName = "battle-events-v1"
    static func supports(_ name: String) -> Bool {
        name == sharedRowName || name == rowName || name == preciseRowName || name == packedLegacyRowName || name == legacyRowName
    }
    let firstTick: Int64
    var lastTick: Int64
    var actions: [ReplayTimelineEvent] = []
    var enemies = BattleEventChanges<[BattleEngine.Walker]>()
    var enemyNumbers = BattleEventNumbers()
    var projectiles = BattleEventChanges<[BattleEngine.Projectile]>()
    var projectileNumbers = BattleEventNumbers()
    var units = BattleEventChanges<[BattleEventUnit]>()
    var unitNumbers = BattleEventNumbers()
    var towers = BattleEventChanges<[PlacedTower]>()
    var tuning = BattleEventChanges<[Int: TowerLevel]>() {
        didSet { tuningSnapshots.removeAll(keepingCapacity: true); lastTuningSnapshot = nil }
    }
    var impacts = BattleEventChanges<[BattleEngine.ArtilleryImpact]>()
    var obstacles = BattleEventChanges<[EngineerObstacleField]>()
    var status = BattleEventChanges<BattleEventStatus>()
    var controls = BattleEventChanges<BattleEventControls>()
    var clockNumbers = BattleEventNumbers()
    // Encoding memoization is not persisted in v1 blocks and owns no game data.
    private var lastTuningSnapshot: BattleEventTuningSnapshot?
    private var tuningSnapshots: [Int64: BattleEventTuningSnapshot] = [:]
    private enum CodingKeys: CodingKey {
        case firstTick, lastTick, actions, enemies, enemyNumbers, projectiles, projectileNumbers
        case units, unitNumbers, towers, tuning, impacts, obstacles, status, controls, clockNumbers
    }

    func encodedTuning(at tick: Int64, value: [Int: TowerLevel]) throws -> Data {
        // A decoded or explicitly edited block may not have capture metadata.
        // Encode its supplied values directly; never consult current content.
        if let snapshot = tuningSnapshots[tick] { return try snapshot.data() }
        return try BattleEventTuningSnapshot(value).data()
    }

    init(firstTick: Int64) { self.firstTick = firstTick; lastTick = firstTick - 1 }
    mutating func append(_ state: BattleEventState) throws {
        guard state.tick == lastTick + 1 else {
            throw DbError.Db(message: "battle events: missing tick after \(lastTick)")
        }
        let t = state.tick
        enemies.append(state.enemies, at: t); try enemyNumbers.appendFloat32(state.enemyNumbers, at: t)
        projectiles.append(state.projectiles, at: t); try projectileNumbers.appendFloat32(state.projectileNumbers, at: t)
        units.append(state.units, at: t); try unitNumbers.appendFloat32(state.unitNumbers, at: t)
        towers.append(state.towers, at: t)
        if lastTuningSnapshot !== state.tuningSnapshot {
            let count = tuning.changes.count
            tuning.append(state.tuning, at: t)
            if tuning.changes.count != count { tuningSnapshots[t] = state.tuningSnapshot }
            lastTuningSnapshot = state.tuningSnapshot
        }
        impacts.append(state.impacts, at: t); obstacles.append(state.obstacles, at: t)
        status.append(state.status, at: t); controls.append(state.controls, at: t)
        clockNumbers.append(state.clockNumbers, at: t); lastTick = t
    }
    func compressedData() throws -> Data {
        try LevelRecordingCodec.encode(BattleEventPackedStorage(self, floatStates: true))
    }
    /// Compatibility with historical JSON-wrapped compressed batches.
    struct Envelope: Codable { let data: Data }
    func json() throws -> String {
        try LevelRecordingCodec.json(Envelope(data: compressedData()))
    }
    static func decode(_ row: LevelActionRecord, resolve: ((String) throws -> Data)? = nil) throws -> Self {
        guard row.category == "event", row.presentation == nil else {
            throw DbError.Db(message: "level_action[\(row.runID),\(row.sequence)]: invalid battle event row")
        }
        if let data = row.eventData {
            guard [rowName, preciseRowName, sharedRowName].contains(row.name), row.payloadJSON == "{}" else {
                throw DbError.Db(message: "level_action[\(row.runID),\(row.sequence)]: invalid event_data encoding or conflicting JSON payload")
            }
            return try decode(data, encoding: row.name, resolve: resolve)
        }
        return try decode(row.payloadJSON, encoding: row.name)
    }
    static func decode(_ json: String, encoding: String = rowName) throws -> Self {
        let envelope = try JSONDecoder().decode(Envelope.self, from: Data(json.utf8))
        return try decode(envelope.data, encoding: encoding)
    }
    static func decode(_ data: Data, encoding: String = rowName, resolve: ((String) throws -> Data)? = nil) throws -> Self {
        let block: Self
        switch encoding {
        case sharedRowName:
            guard let resolve else { throw DbError.Db(message: "battle events v4: shared content resolver is missing") }
            block = try LevelRecordingCodec.decode(BattleEventPackedStorage.self, from: data).unpack(version: 4, resolve: resolve)
        case rowName: block = try LevelRecordingCodec.decode(BattleEventPackedStorage.self, from: data).unpack(version: 5)
        case preciseRowName: block = try LevelRecordingCodec.decode(BattleEventPackedStorage.self, from: data).unpack(version: 3)
        case packedLegacyRowName: block = try LevelRecordingCodec.decode(BattleEventStorage.self, from: data).unpack()
        case legacyRowName: block = try LevelRecordingCodec.decode(Self.self, from: data)
        default: throw DbError.Db(message: "battle events: unsupported encoding \(encoding)")
        }
        guard block.firstTick >= 0, block.lastTick >= block.firstTick,
              block.lastTick < Int64.max, block.lastTick - block.firstTick < 256 else {
            throw DbError.Db(message: "battle events: invalid block bounds")
        }
        let first = block.firstTick, last = block.lastTick
        try block.enemies.validate(first: first, last: last); try block.enemyNumbers.validate(first: first, last: last)
        try block.projectiles.validate(first: first, last: last); try block.projectileNumbers.validate(first: first, last: last)
        try block.units.validate(first: first, last: last); try block.unitNumbers.validate(first: first, last: last)
        try block.towers.validate(first: first, last: last); try block.tuning.validate(first: first, last: last)
        try block.impacts.validate(first: first, last: last); try block.obstacles.validate(first: first, last: last)
        try block.status.validate(first: first, last: last); try block.controls.validate(first: first, last: last)
        try block.clockNumbers.validate(first: first, last: last)
        return block
    }
}
