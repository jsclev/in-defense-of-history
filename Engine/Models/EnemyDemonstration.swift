import Foundation
import CoreGraphics

@MainActor final class EnemyDemonstrationCatalog {
    private let db: Db
    // Keep only the selected encounter: browsing the whole roster must not
    // retain the entire roster's complete battles on a phone.
    private var current: (UUID, TowerDemonstration)?

    init(db: Db) { self.db = db }

    func recording(enemyID: UUID) throws -> TowerDemonstration {
        if let current, current.0 == enemyID { return current.1 }
        let demo = try TowerDemonstration(db: db, enemyID: enemyID)
        current = (enemyID, demo)
        return demo
    }
}

extension TowerDemonstration {
    /// Enemy studies use exactly the tower encyclopedia's recording format
    /// and production scene renderer. Only the staged opponent changes.
    init(db: Db, enemyID: UUID) throws {
        if enemyID == Foe.queensRanger.id {
            try self.init(rangerIn: db)
        } else {
            try self.init(standardEnemyIn: db, enemyID: enemyID)
        }
    }

    private init(standardEnemyIn db: Db, enemyID: UUID) throws {
        let roster = try DesignRoster(enemyTypes: db.enemyTypeDao.getAll())
        guard let subject = roster.enemyTypes.first(where: { $0.id == enemyID }) else {
            throw DbError.Db(message: "enemy_type[\(enemyID)]: missing demonstration subject")
        }
        let settings = try db.encyclopediaDemoDao.get()
        let record = try db.levelInfoDao.getBy(id: settings.contextLevelID)
        let canvas = try db.virtualCanvasDao.get()
        virtualCanvas = canvas
        lesson = .blocking
        isMortarStudy = false
        usesEncounterFraming = true
        let center = CGPoint(x: canvas.playAreaRect.midX, y: canvas.playAreaRect.midY)
        func world(_ x: Double, _ y: Double) -> Point { Point(center.x + x, center.y + y) }
        let callsReserves = subject.reinforcementCallRules != nil
        let ralliesEscort = (subject.bossRules?.rallyRadius ?? 0) > 0
        if callsReserves {
            // A broad horseshoe gives the real signal time to finish before
            // the commander reaches the blocking post on its return leg.
            road = Self.curve(from: world(-360, -145), through: world(-100, -195),
                              world(230, -170), to: world(325, -65))
                + Self.curve(from: world(325, -65), through: world(435, 75),
                             world(230, 185), to: world(60, 155)).dropFirst()
                + Self.curve(from: world(60, 155), through: world(-70, 130),
                             world(-195, 120), to: world(-330, 130)).dropFirst()
        } else {
            road = Self.curve(from: world(-260, -85), through: world(-100, -150),
                              world(10, -125), to: world(110, -65))
                + Self.curve(from: world(110, -65), through: world(210, -5),
                             world(225, 90), to: world(360, 80)).dropFirst()
        }
        roadWidth = canvas.pathWidth * 0.55
        bounds = callsReserves
            ? CGRect(x: center.x - 425, y: center.y - 245, width: 880, height: 475)
            : CGRect(x: center.x - 330, y: center.y - 190, width: 720, height: 360)
        let geometry: [String: Any] = ["type": "FeatureCollection", "features": [
            ["type": "Feature", "properties": ["category": "gameplay", "kind": "enemy_path", "widthPx": roadWidth],
             "geometry": ["type": "LineString", "coordinates": road.map { [$0.x, $0.y] }]]
        ]]
        let movement = try HeroMovementArea(geoJSON: JSONSerialization.data(withJSONObject: geometry),
                                           defaultPathWidth: canvas.pathWidth)
        var spawns = [SpawnEntry(enemyTypeID: enemyID,
            count: 1, interval: 1.8, delay: 0, pathIndex: 0)]
        if ralliesEscort {
            // Real regulars take normal artillery morale damage beside Howe;
            // their ordinary morale bars expose his actual recovery effect.
            spawns.append(SpawnEntry(enemyTypeID: Foe.redcoatRegular.id,
                count: 2, interval: 0.6, delay: 0.4, pathIndex: 0))
        }
        let waves = [Wave(startTime: 0, spawns: spawns,
            callButtonDelay: 0, autoStartCountdown: 0, earlyCallBonus: 0)]
        let slots = [
            TowerSlot(id: UUID(uuidString: "ec1c2000-0000-4000-8000-000000000001")!, position: callsReserves ? world(230, 10) : world(-90, 10)),
            TowerSlot(id: UUID(uuidString: "ec1c2000-0000-4000-8000-000000000002")!, position: callsReserves ? world(-100, 0) : world(100, 60)),
            TowerSlot(id: UUID(uuidString: "ec1c2000-0000-4000-8000-000000000003")!, position: callsReserves ? world(65, -10) : world(-235, 20))
        ]
        let level = LevelInfo(id: record.id, name: record.name, campaign: record.campaign,
            startedAt: record.startedAt, endedAt: record.endedAt, startingMoney: settings.startingMoney,
            numStartingLives: record.numStartingLives, numWaves: waves.count, playArea: record.playArea,
            mapImageName: record.mapImageName, paths: [Path(points: road)], towerSlots: slots, waves: waves)
        let draft = BattleDraft(level: level, heroes: try LevelHeroConfiguration(heroCount: 0, spawns: []),
            movementArea: movement, callButtons: [CallWaveButtonPosition(position: road[0])], exits: [road.last!])
        let content = try BattleContent(db: db, levelID: settings.contextLevelID, draft: draft)
        let game = try BattleEngine(recording: .preview, content: content, heroesEnabled: false,
            startingMoneyOverride: nil, seed: 1776, onVictory: { _, _ in 0 })
        game.publishesPresentation = true
        startingMoney = game.startingMoney
        func require(_ result: BuildResult, _ command: String) throws {
            guard result == .ok else {
                throw DbError.Db(message: "enemy_type[\(enemyID)] demonstration \(command): \(result)")
            }
        }
        try require(game.perform(.build(slot: 0, kind: .areaOfEffect)), "artillery build")
        try require(game.perform(.build(slot: 1, kind: .melee)), "infantry build")
        // An ordinary officer needs a chance to signal before concentrated
        // fire kills it. One real cannon, then a late blocking post, supplies
        // that encounter without changing its HP, movement or call timing.
        if !callsReserves || subject.bossRules != nil {
            try require(game.perform(.build(slot: 2, kind: .ranged)), "ranged build")
        }
        try require(game.perform(.rally(slot: 1, point: callsReserves ? world(-80, 132) : world(60, -90))), "infantry rally")
        game.advance(ticks: SimClock.ticksPerSecond * 8, interpolation: 0)
        guard let built = game.towerSnapshots.first(where: { $0.slot == 0 }) else {
            throw DbError.Db(message: "enemy_type[\(enemyID)]: demonstration purchase produced no tower")
        }
        tower = built
        supportingTowers = game.towerSnapshots.filter { $0.slot != 0 }
        supportedFireRates = Dictionary(uniqueKeysWithValues: game.placedTowers.map { ($0.slotIndex, game.rateOfFire(for: $0)) })
        var killed = Set<Int>()
        var spawnedTypes: [Int: UUID] = [:]
        var removed: [Int: EnemyFate] = [:]
        game.onEvent = { event, _ in
            switch event {
            case let .enemySpawned(id, type): spawnedTypes[id] = type
            case let .enemyRemoved(id, _, fate):
                removed[id] = fate
                if fate == .killed { killed.insert(id) }
            default: break
            }
        }
        try require(game.perform(.startWave), "wave start")
        var recording: [Frame] = []
        // This is a recording safety bound, never a rule or artificial ending.
        // An unfinished encounter is an error, not a fake victory or frozen loop.
        for _ in 0..<(SimClock.ticksPerSecond * 180) {
            game.advance(ticks: 1, interpolation: 0)
            recording.append(Frame(seconds: game.elapsedTime, presentation: game.presentation,
                shots: game.shotsBySlot[0, default: 0], shotsBySlot: game.shotsBySlot,
                killed: killed, towers: game.placedTowers, soldiers: game.militia,
                heroes: game.heroes, heroPoses: game.heroPoses,
                impacts: game.artilleryImpacts, obstacles: game.engineerObstacleFields,
                blocked: game.blockedWalkerIDs, blockingPairs: [:], damageBySlot: game.damageTotalBySlot,
                slowed: game.engineerObstacleFeedback.walkerIDs, healing: [], rallies: game.rallyPointsBySlot,
                waveIncome: 0, money: game.money))
            if game.outcome != nil { break }
        }
        guard game.outcome != nil else {
            throw DbError.Db(message: "enemy_type[\(enemyID)]: demonstration did not finish within 180 seconds")
        }
        frames = recording
        outcome = game.outcome
        escaped = game.escapedEnemyCount
        enemyStudy = EnemyStudy(subjectTypeID: enemyID, spawnedTypes: spawnedTypes, removed: removed)
    }
}
