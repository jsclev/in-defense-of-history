import Foundation

/// Storage only. V5 state tracks contain the Float observations captured by the
/// recorder; historical tracks and exact clocks retain Double. Counts and
/// references are bounded by the bytes still available.
struct BattleEventBytes {
    private(set) var data = Data()
    private var offset = 0
    init(_ data: Data = Data()) { self.data = data }
    var remaining: Int { data.count - offset }

    mutating func put<T: FixedWidthInteger>(_ value: T) {
        var little = value.littleEndian
        withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }
    mutating func putCount(_ value: Int) throws {
        guard let count = UInt32(exactly: value) else { throw Self.invalid("count overflow") }
        put(count)
    }
    mutating func putNumbers(_ values: [Double]) {
        #if _endian(little)
        values.withUnsafeBytes { data.append(contentsOf: $0) }
        #else
        for value in values { put(value.bitPattern) }
        #endif
    }
    mutating func putFloatNumbers(_ values: [Double]) throws {
        let floats = values.map(Float.init)
        guard zip(values, floats).allSatisfy({ $0.bitPattern == Double($1).bitPattern }) else {
            throw Self.invalid("state track was not captured as Float")
        }
        #if _endian(little)
        floats.withUnsafeBytes { data.append(contentsOf: $0) }
        #else
        for value in floats { put(value.bitPattern) }
        #endif
    }
    mutating func putString(_ value: String) throws {
        try putCount(value.utf8.count)
        data.append(contentsOf: value.utf8)
    }
    mutating func string() throws -> String {
        let length = try count(minimumBytes: 1)
        guard let value = String(data: data.subdata(in: offset..<(offset + length)), encoding: .utf8) else {
            throw Self.invalid("invalid UTF-8 string")
        }
        offset += length
        return value
    }
    mutating func get<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
        guard remaining >= MemoryLayout<T>.size else { throw Self.invalid("truncated binary track") }
        let value = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: T.self) }
        offset += MemoryLayout<T>.size
        return T(littleEndian: value)
    }
    mutating func count(minimumBytes: Int) throws -> Int {
        let count = Int(try get(UInt32.self))
        guard count <= remaining / minimumBytes else { throw Self.invalid("invalid binary count") }
        return count
    }
    func finish() throws {
        guard remaining == 0 else { throw Self.invalid("trailing binary data") }
    }
    static func invalid(_ message: String) -> DbError { .Db(message: "battle events v2: \(message)") }
}

extension BattleEventNumbers {
    func packed(float32: Bool = false) throws -> Data {
        var bytes = BattleEventBytes()
        try bytes.putCount(segments.count)
        for segment in segments {
            bytes.put(segment.tick); try bytes.putCount(segment.count)
            try bytes.putCount(segment.values.count)
            if float32 { try bytes.putFloatNumbers(segment.values) }
            else { bytes.putNumbers(segment.values) }
            bytes.put(UInt8(segment.increments == nil ? 0 : 1))
            if let increments = segment.increments {
                guard increments.count == segment.values.count else {
                    throw BattleEventBytes.invalid("numeric increment width differs")
                }
                if float32 { try bytes.putFloatNumbers(increments) }
                else { bytes.putNumbers(increments) }
            }
        }
        return bytes.data
    }
    static func unpack(_ data: Data, float32: Bool = false) throws -> Self {
        var bytes = BattleEventBytes(data), segments: [Segment] = []
        let count = try bytes.count(minimumBytes: 17)
        for _ in 0..<count {
            let tick = try bytes.get(Int64.self), length = Int(try bytes.get(UInt32.self))
            let scalarBytes = float32 ? 4 : 8
            let width = try bytes.count(minimumBytes: scalarBytes)
            var values: [Double] = []
            values.reserveCapacity(width)
            for _ in 0..<width {
                values.append(float32 ? Double(Float(bitPattern: try bytes.get(UInt32.self)))
                                      : Double(bitPattern: try bytes.get(UInt64.self)))
            }
            let flag = try bytes.get(UInt8.self)
            guard flag <= 1 else { throw BattleEventBytes.invalid("invalid increment flag") }
            var increments: [Double]?
            if flag == 1 {
                guard width <= bytes.remaining / scalarBytes else { throw BattleEventBytes.invalid("truncated increments") }
                var deltas: [Double] = []
                deltas.reserveCapacity(width)
                for _ in 0..<width {
                    deltas.append(float32 ? Double(Float(bitPattern: try bytes.get(UInt32.self)))
                                          : Double(bitPattern: try bytes.get(UInt64.self)))
                }
                increments = deltas
            }
            segments.append(Segment(tick: tick, count: length, values: values, increments: increments))
        }
        try bytes.finish()
        return Self(segments: segments)
    }
}

private struct BattleEventCatalog<Value: Codable & Equatable>: Codable {
    var values: [Value] = []
    private var latest: [Int: Int] = [:]
    enum CodingKeys: CodingKey { case values }

    mutating func reference(_ value: Value, id: Int) -> Int {
        if let index = latest[id], values[index] == value { return index }
        let index = values.count
        values.append(value); latest[id] = index
        return index
    }
    func value(_ reference: UInt32) throws -> Value {
        guard values.indices.contains(Int(reference)) else { throw BattleEventBytes.invalid("missing entity definition") }
        return values[Int(reference)]
    }
}

private struct BattleEventEntities<Value: Codable & Equatable>: Codable {
    private var catalog = BattleEventCatalog<Value>()
    private let track: Data

    init(_ changes: BattleEventChanges<[Value]>, id: (Value) -> Int) throws {
        var bytes = BattleEventBytes()
        try bytes.putCount(changes.changes.count)
        for change in changes.changes {
            bytes.put(change.tick); try bytes.putCount(change.value.count)
            for value in change.value { try bytes.putCount(catalog.reference(value, id: id(value))) }
        }
        track = bytes.data
    }
    func unpack() throws -> BattleEventChanges<[Value]> {
        var bytes = BattleEventBytes(track), result = BattleEventChanges<[Value]>()
        let count = try bytes.count(minimumBytes: 12)
        for _ in 0..<count {
            let tick = try bytes.get(Int64.self), width = try bytes.count(minimumBytes: 4)
            var values: [Value] = []
            values.reserveCapacity(width)
            for _ in 0..<width { values.append(try catalog.value(bytes.get(UInt32.self))) }
            // Preserve stored change boundaries for validation, including
            // redundant/corrupt changes; append() would silently coalesce them.
            result.changes.append(.init(tick: tick, value: values))
        }
        try bytes.finish()
        return result
    }
}

/// Tower identity/upgrades, gun aim, volley preparation and charge preparation
/// change independently. Rotating one gun writes only its changed aim record.
private struct BattleEventTowers: Codable {
    private var definitions = BattleEventCatalog<PlacedTower>()
    private var aims = BattleEventCatalog<ArtilleryAim>()
    private var volleys = BattleEventCatalog<PreparedMetaVolley?>()
    private var charges = BattleEventCatalog<DemolitionCharge?>()
    private let track: Data

    init(_ changes: BattleEventChanges<[PlacedTower]>) throws {
        var bytes = BattleEventBytes()
        try bytes.putCount(changes.changes.count)
        for change in changes.changes {
            bytes.put(change.tick); try bytes.putCount(change.value.count)
            for tower in change.value {
                var definition = tower
                // Storage templates only; all removed values have required
                // references below and are restored before playback sees them.
                definition.artilleryAim = ArtilleryAim(heading: 0, firingTolerance: tower.artilleryAim.firingTolerance)
                definition.preparedVolley = nil; definition.demolitionCharge = nil
                try bytes.putCount(definitions.reference(definition, id: tower.id))
                try bytes.putCount(aims.reference(tower.artilleryAim, id: tower.id))
                try bytes.putCount(volleys.reference(tower.preparedVolley, id: tower.id))
                try bytes.putCount(charges.reference(tower.demolitionCharge, id: tower.id))
            }
        }
        track = bytes.data
    }
    func unpack() throws -> BattleEventChanges<[PlacedTower]> {
        var bytes = BattleEventBytes(track), result = BattleEventChanges<[PlacedTower]>()
        let count = try bytes.count(minimumBytes: 12)
        for _ in 0..<count {
            let tick = try bytes.get(Int64.self), width = try bytes.count(minimumBytes: 16)
            var towers: [PlacedTower] = []
            towers.reserveCapacity(width)
            for _ in 0..<width {
                var tower = try definitions.value(bytes.get(UInt32.self))
                tower.artilleryAim = try aims.value(bytes.get(UInt32.self))
                tower.preparedVolley = try volleys.value(bytes.get(UInt32.self))
                tower.demolitionCharge = try charges.value(bytes.get(UInt32.self))
                towers.append(tower)
            }
            result.changes.append(.init(tick: tick, value: towers))
        }
        try bytes.finish()
        return result
    }
}

private struct BattleEventStatuses: Codable {
    private var headers = BattleEventCatalog<BattleEventStatus>()
    private let track: Data

    init(_ changes: BattleEventChanges<BattleEventStatus>) throws {
        var bytes = BattleEventBytes()
        try bytes.putCount(changes.changes.count)
        for change in changes.changes {
            let value = change.value
            let header = value.statistics(damage: [:], targeting: [:], shots: [:])
            bytes.put(change.tick); try bytes.putCount(headers.reference(header, id: 0))
            for dictionary in [value.damage, value.targeting] {
                try bytes.putCount(dictionary.count)
                for key in dictionary.keys.sorted() { bytes.put(Int64(key)); bytes.put(dictionary[key]!.bitPattern) }
            }
            try bytes.putCount(value.shots.count)
            for key in value.shots.keys.sorted() { bytes.put(Int64(key)); bytes.put(Int64(value.shots[key]!)) }
        }
        track = bytes.data
    }
    func unpack() throws -> BattleEventChanges<BattleEventStatus> {
        var bytes = BattleEventBytes(track), result = BattleEventChanges<BattleEventStatus>()
        let count = try bytes.count(minimumBytes: 24)
        for _ in 0..<count {
            let tick = try bytes.get(Int64.self), header = try headers.value(bytes.get(UInt32.self))
            var dictionaries: [[Int: Double]] = []
            for _ in 0..<2 {
                let count = try bytes.count(minimumBytes: 16)
                var values: [Int: Double] = [:]
                for _ in 0..<count {
                    let key = Int(try bytes.get(Int64.self)), value = Double(bitPattern: try bytes.get(UInt64.self))
                    guard values.updateValue(value, forKey: key) == nil else { throw BattleEventBytes.invalid("duplicate statistics key") }
                }
                dictionaries.append(values)
            }
            let count = try bytes.count(minimumBytes: 16)
            var shots: [Int: Int] = [:]
            for _ in 0..<count {
                let key = Int(try bytes.get(Int64.self)), value = Int(try bytes.get(Int64.self))
                guard shots.updateValue(value, forKey: key) == nil else { throw BattleEventBytes.invalid("duplicate shots key") }
            }
            result.changes.append(.init(tick: tick, value: header.statistics(damage: dictionaries[0], targeting: dictionaries[1], shots: shots)))
        }
        try bytes.finish()
        return result
    }
}

private extension BattleEventStatus {
    func statistics(damage: [Int: Double], targeting: [Int: Double], shots: [Int: Int]) -> Self {
        Self(money: money, lives: lives, wave: wave, outcome: outcome, paused: paused, speed: speed,
             selectedSlot: selectedSlot, selectedTower: selectedTower, selectedHero: selectedHero,
             rallies: rallies, slowingSlots: slowingSlots, damage: damage, targeting: targeting, shots: shots)
    }
}

/// Version 2 keeps a small Codable directory for definitions and low-frequency
/// events. The high-volume numeric and reference tracks bypass generic Codable
/// containers entirely. Each block is self-contained and remains lossless.
struct BattleEventStorage: Codable {
    private let version: Int
    private let firstTick: Int64
    private let lastTick: Int64
    private let actions: [ReplayTimelineEvent]
    private let enemies: BattleEventEntities<BattleEngine.Walker>
    private let enemyNumbers: Data
    private let projectiles: BattleEventEntities<BattleEngine.Projectile>
    private let projectileNumbers: Data
    private let units: BattleEventChanges<[BattleEventUnit]>
    private let unitNumbers: Data
    private let towers: BattleEventTowers
    private let tuning: BattleEventChanges<[Int: TowerLevel]>
    private let impacts: BattleEventChanges<[BattleEngine.ArtilleryImpact]>
    private let obstacles: BattleEventChanges<[EngineerObstacleField]>
    private let status: BattleEventStatuses
    private let controls: BattleEventChanges<BattleEventControls>
    private let clockNumbers: Data

    init(_ block: BattleEventBlock) throws {
        version = 2; firstTick = block.firstTick; lastTick = block.lastTick; actions = block.actions
        enemies = try BattleEventEntities(block.enemies, id: { $0.id }); enemyNumbers = try block.enemyNumbers.packed()
        projectiles = try BattleEventEntities(block.projectiles, id: { $0.id }); projectileNumbers = try block.projectileNumbers.packed()
        units = block.units; unitNumbers = try block.unitNumbers.packed()
        towers = try BattleEventTowers(block.towers); tuning = block.tuning
        impacts = block.impacts; obstacles = block.obstacles
        status = try BattleEventStatuses(block.status); controls = block.controls; clockNumbers = try block.clockNumbers.packed()
    }
    func unpack() throws -> BattleEventBlock {
        guard version == 2 else { throw BattleEventBytes.invalid("unsupported storage version \(version)") }
        guard firstTick >= 0, lastTick >= firstTick, lastTick < Int64.max, lastTick - firstTick < 256 else {
            throw BattleEventBytes.invalid("invalid block bounds")
        }
        var block = BattleEventBlock(firstTick: firstTick)
        block.lastTick = lastTick; block.actions = actions
        block.enemies = try enemies.unpack(); block.enemyNumbers = try .unpack(enemyNumbers)
        block.projectiles = try projectiles.unpack(); block.projectileNumbers = try .unpack(projectileNumbers)
        block.units = units; block.unitNumbers = try .unpack(unitNumbers)
        block.towers = try towers.unpack(); block.tuning = tuning
        block.impacts = impacts; block.obstacles = obstacles
        block.status = try status.unpack(); block.controls = controls; block.clockNumbers = try .unpack(clockNumbers)
        return block
    }
}

/// Preserve the existing event strings verbatim while avoiding a generic keyed
/// encoder for every action. Lengths are checked before allocation or reads.
struct BattleEventActions {
    static func pack(_ actions: [ReplayTimelineEvent]) throws -> Data {
        var bytes = BattleEventBytes()
        try bytes.putCount(actions.count)
        for action in actions {
            bytes.put(action.tick)
            try bytes.putString(action.category); try bytes.putString(action.name)
            try bytes.putString(action.payload)
        }
        return bytes.data
    }
    static func unpack(_ data: Data) throws -> [ReplayTimelineEvent] {
        var bytes = BattleEventBytes(data), actions: [ReplayTimelineEvent] = []
        let count = try bytes.count(minimumBytes: 20)
        actions.reserveCapacity(count)
        for _ in 0..<count {
            actions.append(ReplayTimelineEvent(tick: try bytes.get(Int64.self),
                category: try bytes.string(), name: try bytes.string(), payload: try bytes.string()))
        }
        try bytes.finish()
        return actions
    }
}

private struct BattleEventPackedTuning: Codable {
    struct Change: Codable {
        let tick: Int64
        let value: Data
    }
    let changes: [Change]

    init(_ block: BattleEventBlock) throws {
        changes = try block.tuning.changes.map { change in
            let value = try block.encodedTuning(at: change.tick, value: change.value)
            return Change(tick: change.tick, value: value)
        }
    }
    func unpack(resolve: ((String) throws -> Data)? = nil) throws -> BattleEventChanges<[Int: TowerLevel]> {
        var result = BattleEventChanges<[Int: TowerLevel]>()
        let decoder = PropertyListDecoder()
        result.changes = try changes.map { change in
            .init(tick: change.tick, value: try decoder.decode([Int: TowerLevel].self,
                from: resolve.map { try $0(String(decoding: change.value, as: UTF8.self)) } ?? change.value))
        }
        return result
    }
}

/// V3 retains self-contained blocks and the exact V2 numeric/entity tracks.
/// V5 stores observed enemy, projectile and unit numeric tracks as Float32.
/// Immutable tuning is encoded once per observed configuration, then copied
/// into each block. Playback never consults a current database or reapplies rules.
struct BattleEventPackedStorage: Codable {
    private let version: Int
    private let firstTick: Int64
    private let lastTick: Int64
    private let actions: Data
    private let enemies: BattleEventEntities<BattleEngine.Walker>
    private let enemyNumbers: Data
    private let projectiles: BattleEventEntities<BattleEngine.Projectile>
    private let projectileNumbers: Data
    private let units: BattleEventChanges<[BattleEventUnit]>
    private let unitNumbers: Data
    private let towers: BattleEventTowers
    private let tuning: BattleEventPackedTuning
    private let impacts: BattleEventChanges<[BattleEngine.ArtilleryImpact]>
    private let obstacles: BattleEventChanges<[EngineerObstacleField]>
    private let status: BattleEventStatuses
    private let controls: BattleEventChanges<BattleEventControls>
    private let clockNumbers: Data

    init(_ block: BattleEventBlock, floatStates: Bool = false) throws {
        version = floatStates ? 5 : 3; firstTick = block.firstTick; lastTick = block.lastTick
        actions = try BattleEventActions.pack(block.actions)
        enemies = try BattleEventEntities(block.enemies, id: { $0.id })
        enemyNumbers = try block.enemyNumbers.packed(float32: floatStates)
        projectiles = try BattleEventEntities(block.projectiles, id: { $0.id })
        projectileNumbers = try block.projectileNumbers.packed(float32: floatStates)
        units = block.units; unitNumbers = try block.unitNumbers.packed(float32: floatStates)
        towers = try BattleEventTowers(block.towers); tuning = try BattleEventPackedTuning(block)
        impacts = block.impacts; obstacles = block.obstacles
        status = try BattleEventStatuses(block.status); controls = block.controls; clockNumbers = try block.clockNumbers.packed()
    }
    func unpack(version expectedVersion: Int? = nil, resolve: ((String) throws -> Data)? = nil) throws -> BattleEventBlock {
        guard (version == 3 || version == 5 || (version == 4 && resolve != nil)),
              expectedVersion == nil || expectedVersion == version else {
            throw BattleEventBytes.invalid("unsupported or mismatched storage version \(version)")
        }
        guard firstTick >= 0, lastTick >= firstTick, lastTick < Int64.max, lastTick - firstTick < 256 else {
            throw BattleEventBytes.invalid("invalid block bounds")
        }
        var block = BattleEventBlock(firstTick: firstTick)
        block.lastTick = lastTick; block.actions = try BattleEventActions.unpack(actions)
        block.enemies = try enemies.unpack(); block.enemyNumbers = try .unpack(enemyNumbers, float32: version == 5)
        block.projectiles = try projectiles.unpack(); block.projectileNumbers = try .unpack(projectileNumbers, float32: version == 5)
        block.units = units; block.unitNumbers = try .unpack(unitNumbers, float32: version == 5)
        block.towers = try towers.unpack(); block.tuning = try tuning.unpack(resolve: version == 4 ? resolve : nil)
        block.impacts = impacts; block.obstacles = obstacles
        block.status = try status.unpack(); block.controls = controls; block.clockNumbers = try .unpack(clockNumbers)
        return block
    }
}
