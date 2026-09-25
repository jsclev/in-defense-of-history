import Foundation
import CoreGraphics

@MainActor final class EnemyDemonstrationCatalog {
    private let db: Db
    // Keep only the selected encounter: browsing the whole roster must not
    // retain fourteen complete battles on a phone.
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
        let roster = try DesignRoster(enemyTypes: db.enemyTypeDao.getAll())
        guard roster.enemyTypes.contains(where: { $0.id == enemyID }) else {
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
        road = Self.curve(from: world(-260, -85), through: world(-100, -150),
                          world(10, -125), to: world(110, -65))
            + Self.curve(from: world(110, -65), through: world(210, -5),
                         world(225, 90), to: world(360, 80)).dropFirst()
        roadWidth = canvas.pathWidth * 0.55
        bounds = CGRect(x: center.x - 330, y: center.y - 190, width: 720, height: 360)
        let geometry: [String: Any] = ["type": "FeatureCollection", "features": [
            ["type": "Feature", "properties": ["category": "gameplay", "kind": "enemy_path", "widthPx": roadWidth],
             "geometry": ["type": "LineString", "coordinates": road.map { [$0.x, $0.y] }]]
        ]]
        let movement = try HeroMovementArea(geoJSON: JSONSerialization.data(withJSONObject: geometry),
                                           defaultPathWidth: canvas.pathWidth)
        let waves = [Wave(startTime: 0, spawns: [SpawnEntry(enemyTypeID: enemyID,
            count: 1, interval: 1.8, delay: 0, pathIndex: 0)],
            callButtonDelay: 0, autoStartCountdown: 0, earlyCallBonus: 0)]
        let slots = [
            TowerSlot(id: UUID(uuidString: "ec1c2000-0000-4000-8000-000000000001")!, position: world(-90, 10)),
            TowerSlot(id: UUID(uuidString: "ec1c2000-0000-4000-8000-000000000002")!, position: world(100, 60)),
            TowerSlot(id: UUID(uuidString: "ec1c2000-0000-4000-8000-000000000003")!, position: world(-235, 20))
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
        try require(game.perform(.build(slot: 2, kind: .ranged)), "ranged build")
        try require(game.perform(.rally(slot: 1, point: world(60, -90))), "infantry rally")
        game.advance(ticks: SimClock.ticksPerSecond * 8, interpolation: 0)
        guard let built = game.towerSnapshots.first(where: { $0.slot == 0 }) else {
            throw DbError.Db(message: "enemy_type[\(enemyID)]: demonstration purchase produced no tower")
        }
        tower = built
        supportingTowers = game.towerSnapshots.filter { $0.slot != 0 }
        supportedFireRates = Dictionary(uniqueKeysWithValues: game.placedTowers.map { ($0.slotIndex, game.rateOfFire(for: $0)) })
        var killed = Set<Int>()
        game.onEvent = { event, _ in
            if case let .enemyRemoved(id, _, .killed) = event { killed.insert(id) }
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
    }
}
