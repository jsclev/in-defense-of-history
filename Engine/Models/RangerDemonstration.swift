import Foundation
import CoreGraphics

extension TowerDemonstration {
    /// Three observable beats: ranged damage, concealed passage through infantry,
    /// then a separated encounter at Washington's station and final firing post.
    /// Only placements and player orders are staged; all units keep DAO tuning.
    init(rangerIn db: Db) throws {
        let settings = try db.encyclopediaDemoDao.get()
        let record = try db.levelInfoDao.getBy(id: settings.contextLevelID)
        let canvas = try db.virtualCanvasDao.get()
        virtualCanvas = canvas
        lesson = .blocking
        isMortarStudy = false
        usesEncounterFraming = true
        let center = Point(canvas.playAreaRect.midX, canvas.playAreaRect.midY)
        func world(_ x: Double, _ y: Double) -> Point { Point(center.x + x, center.y + y) }
        road = Self.curve(from: world(-330, -90), through: world(-200, -90),
                          world(-60, -120), to: world(60, -85))
            + Self.curve(from: world(60, -85), through: world(180, -50),
                         world(300, 20), to: world(380, 10)).dropFirst()
        roadWidth = canvas.pathWidth * 0.55
        bounds = CGRect(x: center.x - 400, y: center.y - 185, width: 880, height: 380)
        let path = Path(points: road)
        let geometry: [String: Any] = ["type": "FeatureCollection", "features": [
            ["type": "Feature", "properties": ["category": "gameplay", "kind": "enemy_path", "widthPx": roadWidth],
             "geometry": ["type": "LineString", "coordinates": road.map { [$0.x, $0.y] }]]
        ]]
        let movement = try HeroMovementArea(geoJSON: JSONSerialization.data(withJSONObject: geometry),
                                           defaultPathWidth: canvas.pathWidth)
        let slots = [world(-275, 40), world(-80, 50), world(245, 65)].enumerated().map { index, position in
            TowerSlot(id: UUID(uuidString: "ec1c3000-0000-4000-8000-00000000000\(index + 1)")!, position: position)
        }
        let waves = [Wave(startTime: 0, spawns: [SpawnEntry(enemyTypeID: Foe.queensRanger.id,
            count: 1, interval: 1.8, delay: 0, pathIndex: 0)],
            callButtonDelay: 0, autoStartCountdown: 0, earlyCallBonus: 0)]
        let level = LevelInfo(id: record.id, name: record.name, campaign: record.campaign,
            startedAt: record.startedAt, endedAt: record.endedAt, startingMoney: settings.startingMoney,
            numStartingLives: record.numStartingLives, numWaves: waves.count, playArea: record.playArea,
            mapImageName: record.mapImageName, paths: [path], towerSlots: slots, waves: waves)
        let draft = BattleDraft(level: level, heroes: try LevelHeroConfiguration(heroCount: 0, spawns: []),
            movementArea: movement, callButtons: [CallWaveButtonPosition(position: road[0])], exits: [road.last!])
        let base = try BattleContent(db: db, levelID: settings.contextLevelID, draft: draft)
        let washingtonID = UUID(uuidString: "fac6c094-9cbc-474a-975e-8d2a170e07da")!
        guard let washington = try db.heroDao.getAll().first(where: { $0.id == washingtonID }) else {
            throw DbError.Db(message: "hero[\(washingtonID)]: missing Ranger demonstration hero")
        }
        let heroStart = path.point(atDistance: path.nearestDistance(to: world(265, 10)))
        let selection = try HeroSelection(heroes: [washington])
        let deployment = HeroDeployment(hero: washington,
            spawn: HeroSpawn(role: .primary, featureID: "ranger-demo-washington", position: heroStart))
        let content = try BattleContent(level: level, playSpeeds: base.playSpeeds, virtualCanvas: canvas,
            hudLayout: base.hudLayout, arsenal: base.arsenal, enemies: base.enemies, unlocks: base.unlocks,
            reinforcementConfig: base.reinforcementConfig, chosenHeroes: selection, deployments: [deployment],
            heroCombat: [washingtonID: db.heroDao.getCombatStats(heroID: washingtonID)],
            heroAI: base.heroAI, heroControls: base.heroControls, movementArea: movement,
            callButtons: base.callButtons, exits: base.exits, difficulty: base.difficulty,
            playerUpgrades: base.playerUpgrades)
        let game = try BattleEngine(recording: .preview, content: content, heroesEnabled: true,
            startingMoneyOverride: nil, seed: 1776, onVictory: { _, _ in 0 })
        game.publishesPresentation = true
        startingMoney = game.startingMoney
        func require(_ result: BuildResult, _ command: String) throws {
            guard result == .ok else { throw DbError.Db(message: "Ranger demonstration \(command): \(result)") }
        }
        try require(game.perform(.setHeroAI(id: washingtonID, enabled: false)), "manual hero control")
        for (slot, kind) in [(0, TowerKind.ranged), (1, .melee), (2, .ranged)] {
            try require(game.perform(.build(slot: slot, kind: kind)), "tower \(slot)")
        }
        let rally = path.point(atDistance: path.nearestDistance(to: world(-80, -100)))
        try require(game.perform(.rally(slot: 1, point: rally)), "infantry rally")
        game.dismissMenu()
        game.advance(ticks: SimClock.ticksPerSecond * 8, interpolation: 0)
        guard let built = game.towerSnapshots.first(where: { $0.slot == 0 }) else {
            throw DbError.Db(message: "Ranger demonstration: missing opening ranged tower")
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
        guard game.outcome != nil else { throw DbError.Db(message: "Ranger demonstration did not finish within 180 seconds") }
        frames = recording
        outcome = game.outcome
        escaped = game.escapedEnemyCount
        enemyStudy = EnemyStudy(subjectTypeID: Foe.queensRanger.id, spawnedTypes: spawnedTypes, removed: removed)
    }
}
