import Foundation
import CoreGraphics

/// Caches isolated, read-only encounters. No replay writes campaign progress.
@MainActor final class TowerDemonstrationCatalog {
    private let db: Db
    private var recordings: [UUID: TowerDemonstration] = [:]

    init(db: Db) { self.db = db }

    func recording(kind: TowerKind, tier: DesignArsenal.Tier) throws -> TowerDemonstration {
        if let recording = recordings[tier.id] { return recording }
        let recording = try TowerDemonstration(db: db, kind: kind, level: tier.level, branch: tier.branch)
        recordings[tier.id] = recording
        return recording
    }
}

/// A staged input script and a recording of complete production-engine ticks.
/// Purchases, placement validation, combat, movement, auras and income all run
/// through the same handlers as play. Only composition and playback are staged.
@MainActor struct TowerDemonstration {
    enum Lesson: String {
        case singleTargets, blast, grapeshot, piercing, blocking, slowing
        case demolition, income, attackSupport, healing
    }

    struct Frame {
        let seconds: Double
        let presentation: BattlePresentation
        var enemies: [BattleEngine.Walker] { presentation.walkers }
        var projectiles: [BattleEngine.Projectile] { presentation.projectiles }
        let shots: Int
        let shotsBySlot: [Int: Int]
        let killed: Set<Int>
        let towers: [PlacedTower]
        let soldiers: [BattleEngine.MilitiaSoldier]
        let impacts: [BattleEngine.ArtilleryImpact]
        let obstacles: [EngineerObstacleField]
        let blocked: Set<Int>
        let blockingPairs: [Int: Int]
        let damageBySlot: [Int: Double]
        let slowed: Set<Int>
        let healing: Set<Int>
        let rallies: [Int: CGPoint]
        let waveIncome: Int
        let money: Int
    }

    let virtualCanvas: VirtualCanvas
    let lesson: Lesson
    let frames: [Frame]
    let tower: BattleTowerSnapshot
    let supportingTowers: [BattleTowerSnapshot]
    let road: [Point]
    let bounds: CGRect
    let roadWidth: Double
    let outcome: Outcome?
    let escaped: Int
    let startingMoney: Int
    let supportedFireRates: [Int: Double]
    let isMortarStudy: Bool
    let usesEncounterFraming: Bool

    /// One recorded engine tick per normal-speed game tick. Restart as soon
    /// as the encounter finishes, without appending frozen frames.
    var loopDuration: Double { Double(frames.count) * SimClock.dt }

    init(db: Db, kind: TowerKind, level tierLevel: Int, branch: Int) throws {
        let settings = try db.encyclopediaDemoDao.get()
        let record = try db.levelInfoDao.getBy(id: settings.contextLevelID)
        let arsenal = try db.towerTypeDao.getDesignArsenal()
        guard let family = arsenal.towers.first(where: { $0.kind == kind }),
              let tier = family.tiers.first(where: { $0.level == tierLevel && $0.branch == branch }) else {
            throw DbError.Db(message: "tower[\(kind),\(tierLevel),\(branch)]: missing demonstration content")
        }
        let tuning = tier.tuning
        isMortarStudy = tier.history.guide?.style == .mortarStudy
        switch tuning.attackMode {
        case .direct: lesson = .singleTargets
        case .shell: lesson = .blast
        case .grapeshot: lesson = .grapeshot
        case .solidShot: lesson = .piercing
        case .melee: lesson = .blocking
        case .obstacles: lesson = .slowing
        case .demolition: lesson = .demolition
        case .none:
            if tuning.support.healPerSecond > 0 { lesson = .healing }
            else if tuning.support.attackSpeedMultiplier > 1 { lesson = .attackSupport }
            else if tuning.support.incomePerWave > 0 { lesson = .income }
            else { throw DbError.Db(message: "tower[\(tier.id)]: no demonstrable authored capability") }
        }
        usesEncounterFraming = isMortarStudy || lesson == .piercing
        let canvas = try db.virtualCanvasDao.get()
        virtualCanvas = canvas
        let center = CGPoint(x: canvas.playAreaRect.midX, y: canvas.playAreaRect.midY)
        func world(_ x: Double, _ y: Double) -> Point { Point(center.x + x, center.y + y) }
        let mainPosition: Point
        let helperPosition: Point
        var site = world(-40, -115)
        var count = 2
        var interval = 1.3
        // Keep the opponent's real stats identical throughout the encyclopedia.
        // Stage formations and placements to teach roles; never make the enemy
        // tougher to compensate for a stronger tower.
        let enemyID = Foe.loyalistMilitia.id
        var duration = 30.0
        var offsets = [Point(-200, -115), Point(540, -115)]
        switch lesson {
        case .singleTargets:
            mainPosition = world(0, 0); helperPosition = world(220, 20)
            // Every ranged tier uses this exact bend, placement and arrival
            // schedule, beginning at the basic tower's range. Stronger hits
            // remove more of the same enemy's HP without a long approach.
            interval = 2.6
            offsets = [Point(-335, -100), Point(-305, -125), Point(-130, -165),
                Point(50, -165), Point(180, -130), Point(235, -55), Point(235, 35),
                Point(185, 105), Point(300, 145), Point(460, 145)]
        case .blast, .grapeshot:
            mainPosition = world(15, 0); helperPosition = world(250, 40)
            offsets = [Point(-235, -115), Point(-100, -165), Point(120, -140),
                Point(220, -60), Point(220, 40), Point(160, 50), Point(300, 50), Point(540, 50)]
            count = 6; interval = 0.65; duration = 16
            if isMortarStudy {
                // A column followed by separated arrivals: identical real
                // enemies make the shared blast and firing pauses observable.
                offsets = [Point(-270, -110), Point(-100, -145), Point(130, -130),
                    Point(240, -70), Point(260, 0), Point(380, 0)]
                count = 4; interval = 0.3; duration = 45
            }
        case .piercing:
            // Hold the column across a shallow valley, with the battery on
            // the verge firing along it. Solid shot continues through ranks;
            // the road then flows into a broad bend with a matching tangent.
            mainPosition = world(360, -155 + arsenal.combatRules.enemyBodyOffsetY)
            helperPosition = world(0, 20)
            site = world(70, -140)
            offsets = Self.curve(from: Point(360 - tuning.range + 50, -115),
                through: Point(50, -150), Point(120, -145), to: Point(195, -20))
            offsets += Self.curve(from: Point(195, -20), through: Point(270, 105),
                Point(360, 155), to: Point(540, 110)).dropFirst()
            count = 6; interval = 0.1; duration = 30
        case .blocking:
            mainPosition = world(-140, 0); helperPosition = world(80, 0)
            count = 3; interval = 1; duration = 24
        case .slowing:
            mainPosition = world(-140, 0); helperPosition = world(140, 30)
            count = 3; interval = 1.4; duration = 26
        case .demolition:
            mainPosition = world(-140, 0); helperPosition = world(200, 30)
            offsets[0] = Point(-170, -115)
            count = 4; interval = 0.85; duration = 24
        case .income:
            mainPosition = world(-170, 0); helperPosition = world(30, 0)
            offsets = [Point(-170, -115), Point(-80, -140), Point(80, -140),
                Point(190, -115), Point(230, -20), Point(190, 40), Point(300, 40), Point(540, 40)]
            duration = 16
        case .attackSupport:
            mainPosition = world(-100, 0); helperPosition = world(90, 0)
            offsets[0] = Point(-120, -115)
            count = 3; interval = 1.1; duration = 20
        case .healing:
            mainPosition = world(-160, 0); helperPosition = world(40, 0)
            offsets[0] = Point(-160, -115)
            count = 2; interval = 1.2; duration = 25
        }
        road = offsets.map { world($0.x, $0.y) }
        roadWidth = canvas.pathWidth * 0.55
        let geometry: [String: Any] = ["type": "FeatureCollection", "features": [
            ["type": "Feature", "properties": ["category": "gameplay", "kind": "enemy_path", "widthPx": roadWidth],
             "geometry": ["type": "LineString", "coordinates": road.map { [$0.x, $0.y] }]]
        ]]
        let movement = try HeroMovementArea(geoJSON: JSONSerialization.data(withJSONObject: geometry),
                                           defaultPathWidth: canvas.pathWidth)
        var spawns = [SpawnEntry(enemyTypeID: enemyID,
            count: count, interval: interval, delay: 0, pathIndex: 0)]
        if isMortarStudy {
            spawns.append(SpawnEntry(enemyTypeID: enemyID, count: 2, interval: 3.2, delay: 7, pathIndex: 0))
        }
        var waves = [Wave(startTime: 0, spawns: spawns,
            callButtonDelay: 0, autoStartCountdown: 0, earlyCallBonus: 0)]
        if lesson == .demolition || lesson == .healing {
            // Keep combat running after the first group, so preparation and
            // recovery are recorded from real ticks instead of a frozen win.
            waves.append(Wave(startTime: 120, spawns: [SpawnEntry(enemyTypeID: enemyID,
                count: 1, interval: 1, delay: 0, pathIndex: 0)],
                callButtonDelay: 120, autoStartCountdown: 30, earlyCallBonus: 0))
        }
        var slots = [TowerSlot(id: UUID(uuidString: "ec1c1000-0000-4000-8000-000000000001")!, position: mainPosition),
                     TowerSlot(id: UUID(uuidString: "ec1c1000-0000-4000-8000-000000000002")!, position: helperPosition)]
        if lesson == .piercing {
            slots.append(TowerSlot(id: UUID(uuidString: "ec1c1000-0000-4000-8000-000000000003")!,
                                   position: world(150, 70)))
        }
        let level = LevelInfo(id: record.id, name: record.name, campaign: record.campaign,
            startedAt: record.startedAt, endedAt: record.endedAt, startingMoney: settings.startingMoney,
            numStartingLives: record.numStartingLives, numWaves: waves.count, playArea: record.playArea,
            mapImageName: record.mapImageName, paths: [Path(points: road)],
            towerSlots: slots,
            waves: waves)
        let draft = BattleDraft(level: level, heroes: try LevelHeroConfiguration(heroCount: 0, spawns: []),
            movementArea: movement, callButtons: [CallWaveButtonPosition(position: road[0])], exits: [road.last!])
        let content = try BattleContent(db: db, levelID: settings.contextLevelID, draft: draft)
        let game = try BattleEngine(recording: .preview, content: content, heroesEnabled: false,
            startingMoneyOverride: nil, seed: 1776, onVictory: { _, _ in 0 })
        game.publishesPresentation = true
        startingMoney = game.startingMoney
        func require(_ result: BuildResult, _ command: String) throws {
            guard result == .ok else {
                throw DbError.Db(message: "tower[\(kind),\(tierLevel),\(branch)] demonstration \(command): \(result)")
            }
        }
        try require(game.perform(.build(slot: 0, kind: kind)), "build")
        if tierLevel > 1 {
            for level in 2...tierLevel {
                try require(game.perform(.upgrade(slot: 0, branch: level == tierLevel ? branch : 1)), "upgrade \(level)")
            }
        }
        let needsRanged = [Lesson.blocking, .slowing, .attackSupport].contains(lesson)
        if needsRanged { try require(game.perform(.build(slot: 1, kind: .ranged)), "supporting ranged build") }
        if lesson == .attackSupport {
            for _ in 0..<2 {
                try require(game.perform(.upgrade(slot: 1, branch: 1)), "supporting rifle upgrade")
            }
        }
        if lesson == .healing {
            try require(game.perform(.build(slot: 1, kind: .melee)), "supporting infantry build")
            try require(game.perform(.rally(slot: 1, point: site)), "infantry rally")
        }
        if lesson == .piercing {
            for slot in 1...2 {
                try require(game.perform(.build(slot: slot, kind: .melee)), "supporting infantry build")
                try require(game.perform(.rally(slot: slot, point: site)), "shared infantry rally")
            }
            // Let ordinary movement put both squads in position before the
            // viewer arrives. The first wave still waits for the player call.
            game.advance(ticks: SimClock.ticksPerSecond * 8, interpolation: 0)
        }
        guard let built = game.towerSnapshots.first(where: { $0.slot == 0 }) else {
            throw DbError.Db(message: "tower[\(tier.id)]: demonstration purchase produced no tower")
        }
        tower = built
        // Fit the range horizontally, allowing only a small edge margin. The
        // first three ranged examples share a camera so their range and damage
        // differences remain comparable. Specialty towers frame their own reach.
        let framingRadius: Double
        if lesson == .singleTargets && tierLevel <= 3 {
            framingRadius = family.tiers.filter { $0.level <= 3 }.map(\.tuning.range).max()!
        } else if let melee = built.tuning.meleeUnit {
            framingRadius = melee.rallyPointRadius
        } else {
            framingRadius = built.tuning.range
        }
        if lesson == .piercing {
            bounds = CGRect(x: center.x - 125, y: center.y - 210, width: 680, height: 380)
        } else if isMortarStudy {
            // Frame the action and its consequences. The full reach need not
            // shrink this encounter; its exact value belongs on page two.
            bounds = CGRect(x: mainPosition.x - 340, y: center.y - 170, width: 680, height: 360)
        } else if framingRadius > 0 {
            bounds = CGRect(x: mainPosition.x - framingRadius - 20, y: center.y - 170,
                            width: (framingRadius + 20) * 2, height: 360)
        } else {
            // Income towers have no range; keep the funded emplacement in view.
            bounds = CGRect(x: mainPosition.x - 270, y: center.y - 170,
                            width: helperPosition.x - mainPosition.x + 440, height: 360)
        }
        var killed = Set<Int>()
        game.onEvent = { event, _ in
            if case let .enemyRemoved(id, _, .killed) = event { killed.insert(id) }
        }
        var recording: [Frame] = []
        var income = 0
        var chargeHasDetonated = false
        var previousHP: [Int: Double] = [:]
        func capture() -> Frame {
            let healed = Set(game.militia.filter { soldier in
                guard let previous = previousHP[soldier.id] else { return false }
                return soldier.hp > previous + 0.001
            }.map(\.id))
            previousHP = Dictionary(uniqueKeysWithValues: game.militia.map { ($0.id, $0.hp) })
            return Frame(seconds: game.elapsedTime, presentation: game.presentation, shots: game.shotsBySlot[0, default: 0],
                shotsBySlot: game.shotsBySlot, killed: killed, towers: game.placedTowers,
                soldiers: game.militia, impacts: game.artilleryImpacts, obstacles: game.engineerObstacleFields,
                blocked: game.blockedWalkerIDs,
                blockingPairs: Dictionary(uniqueKeysWithValues: game.garrisonsBySlot.flatMap { slot, garrison in
                    garrison.units.enumerated().compactMap { index, unit in
                        unit.state == .fighting ? (slot * 8 + index, unit.targetSpawnID) : nil
                    }
                }),
                damageBySlot: game.damageTotalBySlot,
                slowed: game.engineerObstacleFeedback.walkerIDs,
                healing: healed, rallies: game.rallyPointsBySlot, waveIncome: income, money: game.money)
        }
        game.advance(ticks: 0, interpolation: 0)
        let beforeCall = game.money
        try require(game.perform(.startWave), "wave start")
        income = game.money - beforeCall
        for tick in 0..<Int(Double(SimClock.ticksPerSecond) * duration) {
            if tick == 20 {
                switch lesson {
                case .blocking: try require(game.perform(.rally(slot: 0, point: site)), "rally")
                case .slowing: try require(game.perform(.placeObstacles(slot: 0, point: site)), "obstacle placement")
                case .demolition: try require(game.perform(.placeDemolition(slot: 0, point: site)), "charge placement")
                default: break
                }
            }
            if lesson == .income && tick == SimClock.ticksPerSecond * 2 {
                try require(game.perform(.build(slot: 1, kind: .ranged)), "income-supported build")
            }
            game.advance(ticks: 1, interpolation: 0)
            recording.append(capture())
            if lesson == .demolition, let charge = game.placedTowers.first?.demolitionCharge {
                if !charge.isReady { chargeHasDetonated = true }
                else if chargeHasDetonated { break }
            }
            if game.outcome != nil { break }
        }
        frames = recording
        supportingTowers = game.towerSnapshots.filter { $0.slot != 0 }
        supportedFireRates = Dictionary(uniqueKeysWithValues: game.placedTowers.map { ($0.slotIndex, game.rateOfFire(for: $0)) })
        outcome = game.outcome
        escaped = game.escapedEnemyCount
    }

    /// Author geometry once: these samples supply both the visible road and
    /// the production engine route. Never smooth only the drawing.
    static func curve(from start: Point, through first: Point, _ second: Point,
                              to end: Point) -> [Point] {
        (0...96).map { index in
            let t = Double(index) / 96, u = 1 - t
            return Point(u * u * u * start.x + 3 * u * u * t * first.x
                         + 3 * u * t * t * second.x + t * t * t * end.x,
                         u * u * u * start.y + 3 * u * u * t * first.y
                         + 3 * u * t * t * second.y + t * t * t * end.y)
        }
    }

    private func tickPosition(at elapsed: Double) -> Double {
        max(0, elapsed).truncatingRemainder(dividingBy: loopDuration) * Double(SimClock.ticksPerSecond)
    }

    func frameIndex(at elapsed: Double) -> Int {
        min(frames.count - 1, Int(tickPosition(at: elapsed)))
    }

    func interpolation(at elapsed: Double) -> Double {
        let tick = tickPosition(at: elapsed)
        return tick - floor(tick)
    }
}

/// A width-fitted camera: narrow encyclopedia panels must not add empty side
/// gutters just to include the top and bottom of the range ellipse.
struct DemonstrationProjection {
    let projection: LevelMapProjection
    let sprites: MapSpriteScale

    init(bounds: CGRect, size: CGSize, virtualCanvas: VirtualCanvas) {
        let fittedHeight = bounds.height * size.width / bounds.width
        let fitRect = CGRect(x: 0, y: (size.height - fittedHeight) / 2,
                             width: size.width, height: fittedHeight)
        projection = LevelMapProjection(playArea: bounds, fitRect: fitRect, virtualCanvas: virtualCanvas)
        sprites = MapSpriteScale(playArea: bounds, viewSize: fitRect.size)
    }

    var scale: CGFloat { projection.scale }
    func point(_ p: CGPoint) -> CGPoint { projection.viewPoint(p) }
    func point(_ p: Point) -> CGPoint { point(CGPoint(x: p.x, y: p.y)) }
    var towerHeight: CGFloat { max(48, 158 * scale) }
    var unitHeight: CGFloat { sprites.points(MapSpriteSizing.walker) }
}
