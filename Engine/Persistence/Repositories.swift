//// Repositories.swift
//// The data access layer. Hand-rolled binds (no reflection, no Codable rows)
//// on cached prepared statements, with bulk writes inside single transactions.
//// Traits travel as JSON in one column; path polylines as packed float64 blobs.
//
//import Foundation
//
//// MARK: - Point blob packing
//
///// Packs [Point] as little-endian float64 pairs. 16 bytes per point, lossless,
///// and ~4x smaller / far faster than JSON for long polylines.
//public enum PointBlob {
//    public static func pack(_ points: [Point]) -> Data {
//        var data = Data(capacity: points.count * 16)
//        for p in points {
//            var x = p.x.bitPattern.littleEndian
//            var y = p.y.bitPattern.littleEndian
//            withUnsafeBytes(of: &x) { data.append(contentsOf: $0) }
//            withUnsafeBytes(of: &y) { data.append(contentsOf: $0) }
//        }
//        return data
//    }
//
//    public static func unpack(_ data: Data) -> [Point] {
//        let count = data.count / 16
//        guard count > 0 else { return [] }
//        var points: [Point] = []
//        points.reserveCapacity(count)
//        data.withUnsafeBytes { raw in
//            for i in 0..<count {
//                let off = i * 16
//                let xBits = UInt64(littleEndian: raw.loadUnaligned(fromByteOffset: off, as: UInt64.self))
//                let yBits = UInt64(littleEndian: raw.loadUnaligned(fromByteOffset: off + 8, as: UInt64.self))
//                points.append(Point(Double(bitPattern: xBits), Double(bitPattern: yBits)))
//            }
//        }
//        return points
//    }
//}
//
//// MARK: - Content repository
//
//public final class ContentRepository {
//    private let db: SQLiteDatabase
//    private let encoder = JSONEncoder()
//    private let decoder = JSONDecoder()
//
//    public init(db: SQLiteDatabase) {
//        self.db = db
//        encoder.outputFormatting = [.sortedKeys]  // stable diffs in the DB
//    }
//
//    public enum RepositoryError: Error, CustomStringConvertible {
//        case levelNotFound(String)
//        case corruptTraits(enemyID: String)
//
//        public var description: String {
//            switch self {
//            case .levelNotFound(let id): return "Level '\(id)' not found"
//            case .corruptTraits(let id): return "Enemy '\(id)' has unreadable traits JSON"
//            }
//        }
//    }
//
//    // MARK: Enemy types
//
//    public func save(_ enemy: EnemyType) throws {
//        let traitsJSON = String(
//            data: try encoder.encode(enemy.traits),
//            encoding: .utf8
//        ) ?? "[]"
//        try db.run("""
//        INSERT OR REPLACE INTO enemy_types
//        (id, name, max_hp, speed, cover, discipline, hardiness,
//         damage_min, damage_max, gold, lives_cost, break_band_lo, break_band_hi, traits)
//        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
//        """, [
//            .text(enemy.id.uuidString), .text(enemy.name),
//            .real(enemy.stats.maxHP), .real(enemy.stats.speed),
//            .real(enemy.stats.cover), .real(enemy.stats.discipline),
//            .real(enemy.stats.hardiness),
//            .real(enemy.stats.damageMin), .real(enemy.stats.damageMax),
//            .integer(enemy.stats.gold), .integer(enemy.stats.livesCost),
//            .real(enemy.stats.breakBand.lowerBound),
//            .real(enemy.stats.breakBand.upperBound),
//            .text(traitsJSON),
//        ])
//    }
//
//    public func loadEnemyTypes() throws -> [EnemyType] {
//        var out: [EnemyType] = []
//        var badTraitsID: String? = nil
//        try db.query("""
//        SELECT id, name, max_hp, speed, cover, discipline, hardiness,
//               damage_min, damage_max, gold, lives_cost,
//               break_band_lo, break_band_hi, traits
//        FROM enemy_types ORDER BY id;
//        """) { r in
//            guard let id = UUID(uuidString: r.text(0)) else {
//                throw DbError.Db(message: "Unable to create UUID")
//            }
//            
//            let traitsJSON = r.text(13)
//            let traits: [Trait]
//            if let data = traitsJSON.data(using: .utf8),
//               let decoded = try? self.decoder.decode([Trait].self, from: data) {
//                traits = decoded
//            } else {
//                badTraitsID = id.uuidString
//                traits = []
//            }
//            let stats = EnemyStats(
//                maxHP: r.double(2),
//                speed: r.double(3),
//                cover: r.double(4),
//                discipline: r.double(5),
//                hardiness: r.double(6),
//                damageMin: r.double(7),
//                damageMax: r.double(8),
//                gold: Int(r.int(9)),
//                livesCost: Int(r.int(10)),
//                breakBand: r.double(11)...r.double(12)
//            )
//            out.append(EnemyType(id: id, name: r.text(1), stats: stats, traits: traits))
//        }
//        if let bad = badTraitsID {
//            throw RepositoryError.corruptTraits(enemyID: bad)
//        }
//        return out
//    }
//
//    // MARK: Tower types
//
//    public func save(_ tower: TowerType) throws {
//        try db.transaction {
//            try db.run(
//                "INSERT OR REPLACE INTO tower_types (id, name) VALUES (?, ?);",
//                [.text(tower.id.uuidString), .text(tower.name)]
//            )
//            try db.run(
//                "DELETE FROM tower_levels WHERE tower_id = ?;",
//                [.text(tower.id.uuidString)]
//            )
//            for (i, lvl) in tower.levels.enumerated() {
//                try db.run("""
//                INSERT INTO tower_levels
//                (tower_id, level, cost, range, fire_interval,
//                 shot_min, shot_max, terror_min, terror_max,
//                 aoe_radius, contagion_chance, targeting)
//                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
//                """, [
//                    .text(tower.id.uuidString), .integer(i),
//                    .integer(lvl.cost), .real(lvl.range), .real(lvl.fireInterval),
//                    .real(lvl.shotMin), .real(lvl.shotMax),
//                    .real(lvl.terrorMin), .real(lvl.terrorMax),
//                    .real(lvl.aoeRadius), .real(lvl.contagionChance),
//                    .text(lvl.targeting.rawValue),
//                ])
//            }
//        }
//    }
//
//    public func loadTowerTypes() throws -> [TowerType] {
//        var names: [UUID: String] = [:]
//        try db.query("SELECT id, name FROM tower_types;") { r in
//            guard let id = UUID(uuidString: r.text(0)) else {
//                throw DbError.Db(message: "Unable to create UUID")
//            }
//            
//            names[id] = r.text(1)
//        }
//        var levelsByTower: [UUID: [(Int, TowerLevel)]] = [:]
//        try db.query("""
//        SELECT tower_id, level, cost, range, fire_interval,
//               shot_min, shot_max, terror_min, terror_max,
//               aoe_radius, contagion_chance, targeting
//        FROM tower_levels ORDER BY tower_id, level;
//        """) { r in
//            guard let towerId = UUID(uuidString: r.text(0)) else {
//                throw DbError.Db(message: "Unable to create UUID")
//            }
//            
//            let lvl = TowerLevel(
//                cost: Int(r.int(2)),
//                range: r.double(3),
//                fireInterval: r.double(4),
//                shotMin: r.double(5),
//                shotMax: r.double(6),
//                terrorMin: r.double(7),
//                terrorMax: r.double(8),
//                aoeRadius: r.double(9),
//                contagionChance: r.double(10),
//                targeting: Targeting(rawValue: r.text(11)) ?? .first
//            )
//            
//            levelsByTower[towerId, default: []].append((Int(r.int(1)), lvl))
//        }
//        return names.map { id, name in
//            let levels = (levelsByTower[id] ?? [])
//                .sorted { $0.0 < $1.0 }
//                .map { $0.1 }
//            return TowerType(id: id, name: name, levels: levels)
//        }.sorted { $0.id < $1.id }
//    }
//
//    // MARK: Levels
//
//    public func save(_ level: LevelInfo) throws {
//        try db.transaction {
//            // ON DELETE CASCADE clears children.
//            try db.run("DELETE FROM levels WHERE id = ?;", [.text(level.id.uuidString)])
//            try db.run(
//                "INSERT INTO levels (id, name, starting_gold, lives) VALUES (?, ?, ?, ?);",
//                [.text(level.id.uuidString), .text(level.name),
//                 .integer(level.startingMoney), .integer(level.numStartingLives)]
//            )
//            for (i, path) in level.paths.enumerated() {
//                try db.run(
//                    "INSERT INTO level_paths (level_id, path_index, points) VALUES (?, ?, ?);",
//                    [.text(level.id.uuidString), .integer(i), .blob(PointBlob.pack(path.points))]
//                )
//            }
//            for slot in level.towerSlots {
//                try db.run(
//                    "INSERT INTO tower_slots (level_id, slot_index, x, y) VALUES (?, ?, ?, ?);",
//                    [.text(level.id.uuidString), .integer(slot.index),
//                     .real(slot.position.x), .real(slot.position.y)]
//                )
//            }
//            for (wi, wave) in level.waves.enumerated() {
//                try db.run(
//                    "INSERT INTO waves (level_id, wave_index, start_time) VALUES (?, ?, ?);",
//                    [.text(level.id.uuidString), .integer(wi), .real(wave.startTime)]
//                )
//                for (si, spawn) in wave.spawns.enumerated() {
//                    try db.run("""
//                    INSERT INTO wave_spawns
//                    (level_id, wave_index, spawn_index, enemy_type_id, count, interval, delay, path_index)
//                    VALUES (?, ?, ?, ?, ?, ?, ?, ?);
//                    """, [
//                        .text(level.id.uuidString), .integer(wi), .integer(si),
//                        .text(spawn.enemyTypeID.uuidString), .integer(spawn.count),
//                        .real(spawn.interval), .real(spawn.delay),
//                        .integer(spawn.pathIndex),
//                    ])
//                }
//            }
//        }
//    }
//
//    public func loadLevel(optionalId: UUID?) throws -> LevelInfo {
//        guard let id = optionalId else {
//            throw RepositoryError.levelNotFound("<unknown>")
//        }
//        
//        var header: (id: UUID, name: String, gold: Int, lives: Int)? = nil
//        try db.query(
//            "SELECT name, starting_gold, lives FROM levels WHERE id = ?;",
//            [.text(id.uuidString)]
//        ) { r in
//            guard let id = UUID(uuidString: r.text(0)) else {
//                throw DbError.Db(message: "Unable to create UUID")
//            }
//            
//            header = (id, r.text(0), Int(r.int(1)), Int(r.int(2)))
//        }
//        guard let header else { throw RepositoryError.levelNotFound(id.uuidString) }
//
//        var paths: [Path] = []
//        try db.query(
//            "SELECT points FROM level_paths WHERE level_id = ? ORDER BY path_index;",
//            [.text(id.uuidString)]
//        ) { r in
//            paths.append(Path(points: PointBlob.unpack(r.blob(0))))
//        }
//
//        var towerSlots: [TowerSlot] = []
//        try db.query(
//            "SELECT slot_index, x, y FROM tower_slots WHERE level_id = ? ORDER BY slot_index;",
//            [.text(id.uuidString)]
//        ) { r in
//            towerSlots.append(TowerSlot(
//                index: Int(r.int(0)),
//                position: Point(r.double(1), r.double(2))
//            ))
//        }
//
//        var waveStarts: [(Int, Double)] = []
//        try db.query(
//            "SELECT wave_index, start_time FROM waves WHERE level_id = ? ORDER BY wave_index;",
//            [.text(id.uuidString)]
//        ) { r in
//            waveStarts.append((Int(r.int(0)), r.double(1)))
//        }
//        var spawnsByWave: [Int: [SpawnEntry]] = [:]
//        try db.query("""
//        SELECT wave_index, enemy_type_id, count, interval, delay, path_index
//        FROM wave_spawns WHERE level_id = ?
//        ORDER BY wave_index, spawn_index;
//        """, [.text(id.uuidString)]) { r in
//            guard let enemyTypeId = UUID(uuidString: r.text(1)) else {
//                throw DbError.Db(message: "Unable to create UUID")
//            }
//            
//            spawnsByWave[Int(r.int(0)), default: []].append(SpawnEntry(
//                enemyTypeID: enemyTypeId,
//                count: Int(r.int(2)),
//                interval: r.double(3),
//                delay: r.double(4),
//                pathIndex: Int(r.int(5))
//            ))
//        }
//        let waves = waveStarts.map { wi, start in
//            Wave(startTime: start, spawns: spawnsByWave[wi] ?? [])
//        }
//        
//        return LevelInfo(
//            id: header.id,
//            name: header.name,
//            campaign: Campaign(id: UUID(), name: "campaign"),
//            startedAt: Date.now,
//            endedAt: Date.now,
//            startingMoney: header.gold,
//            numStartingLives: header.lives,
//            paths: paths,
//            towerSlots: towerSlots,
//            waves: waves
//        )
//    }
//
//    public func loadLevelIDs() throws -> [String] {
//        var ids: [String] = []
//        try db.query("SELECT id FROM levels ORDER BY id;") { r in
//            ids.append(r.text(0))
//        }
//        return ids
//    }
//
//    // MARK: Catalog
//
//    public func loadCatalog() throws -> ContentCatalog {
//        ContentCatalog(
//            enemyTypes: try loadEnemyTypes(),
//            towerTypes: try loadTowerTypes()
//        )
//    }
//
//    public func isEmpty() throws -> Bool {
//        (try db.scalarInt("SELECT COUNT(*) FROM enemy_types;") ?? 0) == 0
//    }
//}
