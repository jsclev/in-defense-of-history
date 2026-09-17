import Foundation
import CoreGraphics
import Combine
import QuartzCore
import UIKit
import CoreHaptics

struct PlacedTower: Identifiable {
    let slotIndex: Int
    let kind: TowerKind
    let position: CGPoint
    var level: Int = 1
    var branch: Int = 1
    var artilleryAim = ArtilleryAim()
    var artilleryFacing: ArtilleryFacing { artilleryAim.facing }
    var demolitionCharge: DemolitionCharge?
    var engineerObstaclePosition: CGPoint?

    var id: Int { slotIndex }
}

@MainActor
public final class LevelRunner: NSObject, ObservableObject {
    private static let normalTickDuration: Duration = .seconds(1) / SimClock.ticksPerSecond
    private(set) var mapImageName: String

    private(set) var mapArt: LevelMapArt
    private(set) var playArea: CGRect

    var slotSize: CGSize { virtualCanvas.towerSlotSize }
    private(set) var startingMoney = 0

    @Published private(set) var money = 0

    private(set) var startingLives = 0

    @Published private(set) var lives = 0

    @Published private(set) var escapedEnemyCount = 0

    @Published private(set) var isDefeated = false

    @Published private(set) var isCleared = false

    @Published private(set) var awaitingWaveStart = false

    @Published private(set) var waveCountdownSeconds: Int?

    private(set) var towerCosts: [TowerKind: [Int: [Int: Int]]] = [:]
    private(set) var towerMenuDetails: [TowerKind: [Int: [Int: TowerMenuDetails]]] = [:]

    func towerName(for kind: TowerKind, atLevel level: Int, branch: Int = 1) -> String {
        guard let details = menuDetails(for: kind, atLevel: level, branch: branch) else {
            preconditionFailure("Missing authored tower text for \(kind), level \(level), branch \(branch)")
        }
        return details.name
    }

    func menuDetails(for kind: TowerKind, atLevel level: Int, branch: Int = 1) -> TowerMenuDetails? {
        towerMenuDetails[kind]?[level]?[branch]
    }

    func buildCost(for kind: TowerKind) -> Int? {
        guard let cost = towerCosts[kind]?[1]?[1] else {
            fatalError("Missing database build cost for \(kind)")
        }
        return cost
    }

    func upgradeCost(for kind: TowerKind, to level: Int, branch: Int = 1) -> Int? {
        guard let cost = towerCosts[kind]?[level]?[branch] else {
            fatalError("Missing database upgrade cost for \(kind), level \(level), branch \(branch)")
        }
        return cost
    }

    @Published private(set) var towerUnlocks: [TowerKind: Int] = [:]

    private(set) var chosenHeroes: HeroSelection?
    private(set) var heroSelection: HeroSelection?
    private var heroImageAspectRatios: [UUID: CGFloat] = [:]

    var primaryHero: Hero? { heroSelection?.primary }
    var secondaryHero: Hero? { heroSelection?.secondary }

    var availableTowerKinds: Set<TowerKind> { Set(towerUnlocks.filter { $0.value > 0 }.keys) }

    private(set) var slotPositions: [CGPoint] = []

    private(set) var exitPositions: [CGPoint] = []

    private static let projectileHitRadiusInImagePixels: CGFloat = 10

    private(set) var towerLevels: [TowerKind: [Int: [Int: TowerLevel]]] = [:]

    func towerLevel(for tower: PlacedTower) -> TowerLevel? {
        guard let tuning = towerLevels[tower.kind]?[tower.level]?[tower.branch] else {
            fatalError("Missing database tower attributes: \(tower.kind), level \(tower.level), branch \(tower.branch)")
        }
        return tuning
    }

    func attackRange(for tower: PlacedTower) -> CGFloat? {
        towerLevel(for: tower)?.attackRange.radius
    }

    func hasAttackRange(_ tower: PlacedTower) -> Bool {
        tower.kind.projectileAssetName != nil && (attackRange(for: tower) ?? 0) > 0
    }

    private func fireCooldownTicks(for tower: PlacedTower) -> Int64 {
        guard let interval = towerLevel(for: tower)?.fireInterval, interval > 0
        else { return .max }
        return max(1, Int64((interval * Double(SimClock.ticksPerSecond)).rounded()))
    }

    func rateOfFire(for tower: PlacedTower) -> Double {
        guard let interval = towerLevel(for: tower)?.fireInterval, interval > 0
        else { return 0 }
        return 1 / interval
    }

    private var distinctTowerRanges: [CGFloat] {
        let ranges = towerLevels.values.flatMap { levels in
            levels.values.flatMap { $0.values.map { CGFloat($0.range) } }
        }
        return Array(Set(ranges)).sorted()
    }

    private var damageTotalBySlot: [Int: Double] = [:]
    private var targetingSecondsBySlot: [Int: Double] = [:]
    private var lastStatsTick: Int64 = 0

    @Published private(set) var totalDamageBySlot: [Int: Double] = [:]

    @Published private(set) var targetingTimeBySlot: [Int: Double] = [:]

    private func refreshTowerStatsIfDue() {
        guard timer.tick - lastStatsTick >= Int64(SimClock.ticksPerSecond) else { return }
        lastStatsTick = timer.tick
        totalDamageBySlot = damageTotalBySlot
        targetingTimeBySlot = targetingSecondsBySlot
    }

    private var pathHalfWidthInImagePixels: CGFloat { virtualCanvas.pathWidth / 2 }

    private var laneAreaBySlot: [Int: [Int: Double]] = [:]

    private static let laneCell: CGFloat = 4

    private static func rangeKey(_ range: CGFloat) -> Int { Int(range.rounded()) }

    func pathAreaInRange(for tower: PlacedTower) -> Double {
        guard let range = towerLevel(for: tower)?.range else { return 0 }
        return laneAreaBySlot[tower.slotIndex]?[Self.rangeKey(CGFloat(range))] ?? 0
    }

    private func precomputeLaneCoverage() {
        let cell = Self.laneCell
        let w = pathHalfWidthInImagePixels
        let cols = Int((virtualCanvas.size.width / cell).rounded(.up)) + 1
        let rows = Int((virtualCanvas.size.height / cell).rounded(.up)) + 1
        var lane = [Bool](repeating: false, count: cols * rows)

        for path in paths {
            let pts = path.points
            guard pts.count > 1 else { continue }
            for i in 0..<(pts.count - 1) {
                let a = pts[i], b = pts[i + 1]
                let x0 = Int((min(a.x, b.x) - w) / cell), x1 = Int((max(a.x, b.x) + w) / cell)
                let y0 = Int((min(a.y, b.y) - w) / cell), y1 = Int((max(a.y, b.y) + w) / cell)
                for gy in max(0, y0)...max(0, min(rows - 1, y1)) {
                    for gx in max(0, x0)...max(0, min(cols - 1, x1)) {
                        let idx = gy * cols + gx
                        if lane[idx] { continue }
                        let centre = Point((Double(gx) + 0.5) * cell, (Double(gy) + 0.5) * cell)
                        if centre.distance(toSegment: a, b) <= w { lane[idx] = true }
                    }
                }
            }
        }

        let cellArea = Double(cell * cell)
        let ranges = distinctTowerRanges
        for (slot, c) in slotPositions.enumerated() {
            var byRange: [Int: Double] = [:]
            for r in ranges {
                let reach = TowerAttackRange(Double(r))
                let key = Self.rangeKey(r)
                let gx0 = max(0, Int((c.x - r) / cell)), gx1 = min(cols - 1, Int((c.x + r) / cell))
                let gy0 = max(0, Int((c.y - r) / cell)), gy1 = min(rows - 1, Int((c.y + r) / cell))
                guard gx0 <= gx1, gy0 <= gy1 else { byRange[key] = 0; continue }
                var covered = 0.0
                for gy in gy0...gy1 {
                    for gx in gx0...gx1 where lane[gy * cols + gx] {
                        let px = (CGFloat(gx) + 0.5) * cell, py = (CGFloat(gy) + 0.5) * cell
                        if reach.contains(CGPoint(x: px, y: py), from: c) { covered += cellArea }
                    }
                }
                byRange[key] = covered
            }
            laneAreaBySlot[slot] = byRange
        }
    }

    struct Projectile: Identifiable {
        let id: Int
        let kind: TowerKind
        var position: CGPoint
        var heading: CGFloat
        let damage: Double
        let targetID: Int

        let slotIndex: Int

        let speed: CGFloat
        let splashRadius: CGFloat

        var impactPoint: CGPoint? = nil

        var firingBoundary: TowerAttackRange? = nil
        var firingOrigin: CGPoint? = nil
        var moraleStrike: ArtilleryMoraleStrike? = nil
        var grapeshot: GrapeshotFlight? = nil
        var solidShot: SolidShotFlight? = nil
    }

    struct Walker: Identifiable {
        let id: Int
        let assetName: String
        let speed: Double
        let maxHP: Double
        var hp: Double
        let bounty: Int
        let damageMin: Double
        let damageMax: Double
        let cover: Double
        let blockImmune: Bool
        let spawnTick: Int64
        let pathIndex: Int
        var discipline: Double = 0
        var moraleResponse = EnemyMoraleResponse()
        var morale = EnemyMorale()
        var position: CGPoint = .zero
        var pathDistance: Double = 0
        var meleeDamageRange: ClosedRange<Double> {
            let multiplier = moraleResponse.damageMultiplier(morale: morale.value)
            return (damageMin * multiplier)...(damageMax * multiplier)
        }
    }

    struct MilitiaSoldier: Identifiable {
        let id: Int
        let assetName: String
        var position: CGPoint
        var hp: Double
        var maxHP: Double
    }

    struct HeroSoldier: Identifiable {
        let id: Int
        let assetName: String
        let baseAssetName: String
        let imageAspectRatio: CGFloat
        var position: CGPoint
        var hp: Double
        var maxHP: Double
        var isSelected: Bool
    }

    private struct HeroPost {
        let hero: Hero
        let assetName: String
        let combat: HeroCombatStats
        var unit: MilitiaUnit
        var movement: HeroMovement
        var enemySwingTicks: [Int: Int] = [:]
    }

    private struct MilitiaGarrison {
        var rallyPoint: Point
        var units: [MilitiaUnit]
        var enemySwingTicks: [Int: Int] = [:]
        var stats: MeleeUnitStats? = nil
        var anchor: Point? = nil
    }

    private struct WalkPose {
        var facing: UnitFacing
        var walkPhase: Double
        var isWalking: Bool
    }

    @Published private(set) var projectiles: [Projectile] = []
    struct ArtilleryImpact: Identifiable {
        let id: Int
        let position: CGPoint
        let radius: CGFloat
        var isDemolition = false
        var age: Double = 0
        var duration: Double { isDemolition ? DemolitionExplosion.duration : 0.78 }
    }
    @Published private(set) var artilleryImpacts: [ArtilleryImpact] = []
    private var nextProjectileID = 0
    private var grapeshotHits: [Int: Set<Int>] = [:]
    private var nextFireTickBySlot: [Int: Int64] = [:]
    private var lastStepGameTicks: Double = 0

    @Published private(set) var placedTowers: [PlacedTower] = []

    @Published private(set) var selectedSlotIndex: Int?

    @Published private(set) var selectedTowerSlotIndex: Int?

    @Published private(set) var rallyPointsBySlot: [Int: CGPoint] = [:]

    @Published private(set) var isPlacingRallyPoint = false
    @Published private(set) var isPlacingDemolition = false
    @Published private(set) var isPlacingEngineerObstacles = false

    var engineerObstacleFields: [EngineerObstacleField] {
        placedTowers.compactMap { tower in
            guard let position = tower.engineerObstaclePosition,
                  let stats = towerLevel(for: tower)?.engineerObstacles else { return nil }
            return EngineerObstacleField(position: position, stats: stats)
        }
    }

    func beginEngineerObstaclePlacement() {
        guard let slot = selectedTowerSlotIndex, let tower = placedTower(atSlot: slot),
              towerLevel(for: tower)?.engineerObstacles != nil else { return }
        isPlacingRallyPoint = false
        isPlacingDemolition = false
        armedUpgradeBranch = nil
        isPlacingEngineerObstacles = true
    }

    func placeEngineerObstacles(at requested: CGPoint) {
        guard isPlacingEngineerObstacles, let slot = selectedTowerSlotIndex,
              let index = placedTowers.firstIndex(where: { $0.slotIndex == slot }),
              let tuning = towerLevel(for: placedTowers[index]), tuning.engineerObstacles != nil else { return }
        let origin = placedTowers[index].position
        if tuning.attackRange.contains(requested, from: origin),
           let site = tuning.attackRange.nearestPathPoint(to: requested, from: origin, paths: paths) {
            placedTowers[index].engineerObstaclePosition = site
        }
        dismissMenu()
    }

    func beginDemolitionPlacement() {
        guard let slot = selectedTowerSlotIndex,
              placedTower(atSlot: slot)?.demolitionCharge != nil else { return }
        isPlacingRallyPoint = false
        armedUpgradeBranch = nil
        isPlacingDemolition = true
    }

    func placeDemolition(at requested: CGPoint) {
        guard isPlacingDemolition, let slot = selectedTowerSlotIndex,
              let index = placedTowers.firstIndex(where: { $0.slotIndex == slot }),
              let tuning = towerLevel(for: placedTowers[index]) else { return }
        let origin = placedTowers[index].position
        guard tuning.attackRange.contains(requested, from: origin),
              let point = tuning.attackRange.nearestPathPoint(to: requested, from: origin, paths: paths)
        else {

            dismissMenu()
            return
        }
        placedTowers[index].demolitionCharge?.place(at: point)

        if placedTowers[index].demolitionCharge?.isReady == false {
            rallyFlagFlashCount += 1
            rallyFlagFlash = RallyFlagFlash(id: rallyFlagFlashCount, position: point)
        } else {
            rallyFlagFlash = nil
        }
        dismissMenu()
    }

    @discardableResult func detonateDemolition(atSlot slot: Int) -> Bool {
        guard isReady, !isDefeated, !isCleared,
              let index = placedTowers.firstIndex(where: { $0.slotIndex == slot }),
              var charge = placedTowers[index].demolitionCharge,
              let position = charge.position,
              let tuning = towerLevel(for: placedTowers[index]),
              tuning.attackRange.contains(position, from: placedTowers[index].position),
              charge.detonate() else { return false }
        placedTowers[index].demolitionCharge = charge
        let blast = Projectile(id: nextProjectileID, kind: .areaOfEffect, position: position,
            heading: 0, damage: Double.random(in: tuning.shotMinDamage...max(tuning.shotMinDamage, tuning.shotMaxDamage)),
            targetID: -1, slotIndex: slot, speed: 0, splashRadius: CGFloat(tuning.aoeRadius),
            impactPoint: position, moraleStrike: ArtilleryMoraleStrike(tuning: tuning))
        nextProjectileID += 1
        applyImpact(blast, at: position, isDemolition: true)
        let playback = playGameplayHaptic(.demolitionExplosion)
        #if DEBUG
        if playback != .inactive {
            demolitionHapticStarts += 1
            lastDemolitionHapticPlayback = playback
        }
        #endif
        return true
    }

    private func advanceDemolitionCharges(seconds: Double) {
        guard seconds > 0, !isCleared, !isDefeated else { return }
        for index in placedTowers.indices {
            guard placedTowers[index].demolitionCharge?.isReady == false else { continue }
            placedTowers[index].demolitionCharge?.advance(seconds: seconds)
        }
    }

    private func detonateOutgoingDemolitionCharges(seconds: Double, nowTicks: Double) {
        guard seconds > 0, !paths.isEmpty, !isCleared, !isDefeated else { return }
        let fields = engineerObstacleFields
        for tower in placedTowers {
            guard let charge = tower.demolitionCharge, charge.isReady, charge.position != nil,
                  let tuning = towerLevel(for: tower) else { continue }
            let enemyAboutToExit = walkers.contains { walker in
                guard walker.hp > 0 else { return false }
                var morale = walker.morale
                let secondsAlive = max(0, nowTicks - Double(walker.spawnTick)) * SimClock.dt
                let slow = EngineerObstacleField.movementMultiplier(at: walker.position,
                    retreating: false, fields: fields)
                let travel = morale.advance(seconds: min(seconds, secondsAlive), baseSpeed: walker.speed * slow,
                    response: walker.moraleResponse, blocked: blockedWalkerIDs.contains(walker.id))
                let path = paths[min(max(walker.pathIndex, 0), paths.count - 1)]
                return charge.willEnemyExitBlast(on: path, from: walker.pathDistance,
                    advancingBy: travel, radius: tuning.aoeRadius, targetOffset: Self.enemyBodyOffset)
            }
            if enemyAboutToExit { detonateDemolition(atSlot: tower.slotIndex) }
        }
    }

    private func advanceWalkers(seconds: Double, nowTicks: Double) {
        guard seconds.isFinite, seconds > 0, !paths.isEmpty, !isCleared, !isDefeated else { return }
        var remaining = seconds
        let fields = engineerObstacleFields
        while remaining > 0, !isDefeated {
            let dt = min(remaining, SimClock.dt)
            let stepEndTicks = nowTicks - (remaining - dt) / SimClock.dt
            advanceDemolitionCharges(seconds: dt)
            detonateOutgoingDemolitionCharges(seconds: dt, nowTicks: stepEndTicks)
            var marching: [Walker] = []
            for var walker in walkers {
                let secondsAlive = max(0, stepEndTicks - Double(walker.spawnTick)) * SimClock.dt
                let slow = EngineerObstacleField.movementMultiplier(at: walker.position,
                    retreating: false, fields: fields)
                let travel = walker.morale.advance(seconds: min(dt, secondsAlive), baseSpeed: walker.speed * slow,
                    response: walker.moraleResponse, blocked: blockedWalkerIDs.contains(walker.id))
                let distance = walker.pathDistance + travel
                let path = paths[min(max(walker.pathIndex, 0), paths.count - 1)]
                if path.totalLength > 0, distance >= path.totalLength {
                    loseLife()
                    continue
                }
                let p = path.point(atDistance: distance)
                walker.position = CGPoint(x: p.x, y: p.y)
                walker.pathDistance = distance
                marching.append(walker)
            }
            walkers = marching
            remaining -= dt
        }
    }

    struct RallyFlagFlash: Equatable {
        let id: Int
        let position: CGPoint
    }

    @Published private(set) var rallyFlagFlash: RallyFlagFlash?

    private var rallyFlagFlashCount = 0

    func dismissRallyFlag(id: Int) {
        guard rallyFlagFlash?.id == id else { return }
        rallyFlagFlash = nil
    }

    func toggleRallyPlacement() {
        isPlacingRallyPoint.toggle()
        if isPlacingRallyPoint { armedUpgradeBranch = nil }
    }

    func placeRallyPoint(at point: CGPoint) {
        guard isPlacingRallyPoint, let slot = selectedTowerSlotIndex else { return }
        if let tower = placedTower(atSlot: slot),
           let melee = towerLevel(for: tower)?.meleeUnit,
           hypot(point.x - tower.position.x, point.y - tower.position.y)
               <= CGFloat(melee.rallyPointRadius) {
            setRallyPoint(slot: slot, to: point)
            if let placed = rallyPointsBySlot[slot] {
                rallyFlagFlashCount += 1
                rallyFlagFlash = RallyFlagFlash(id: rallyFlagFlashCount, position: placed)
            }
        }
        isPlacingRallyPoint = false
        selectedTowerSlotIndex = nil
    }

    func rallyPoint(forSlot slot: Int) -> CGPoint? { rallyPointsBySlot[slot] }

    func setRallyPoint(slot: Int, to point: CGPoint) {
        guard var g = garrisonsBySlot[slot],
              let tower = placedTower(atSlot: slot),
              let melee = towerLevel(for: tower)?.meleeUnit else { return }
        let towerPos = Point(Double(tower.position.x), Double(tower.position.y))
        g.rallyPoint = Simulation.rallyPoint(requested: Point(Double(point.x), Double(point.y)),
                                             towerPosition: towerPos,
                                             flagRange: melee.rallyPointRadius, paths: paths)
        garrisonsBySlot[slot] = g
        rallyPointsBySlot[slot] = CGPoint(x: g.rallyPoint.x, y: g.rallyPoint.y)
    }

    @Published private(set) var armedBuildKind: TowerKind?
    private let enemyEscapeFeedback = UINotificationFeedbackGenerator()
    private let demolitionFeedback = UIImpactFeedbackGenerator(style: .heavy)
    private var hapticEngine: CHHapticEngine?
    private var activeHapticPlayer: (any CHHapticPatternPlayer)?

    private var demolitionHapticPlayer: (any CHHapticAdvancedPatternPlayer)?
    private var hapticsActive = false
    private enum HapticPlayback: String { case inactive, coreHaptics, fallback }
    #if DEBUG
    private var demolitionHapticStarts = 0
    private var lastDemolitionHapticPlayback = HapticPlayback.inactive
    private var demolitionHapticCompleted: Bool?
    #endif

    @Published private(set) var armedUpgradeBranch: Int?

    @Published private(set) var walkers: [Walker] = []
    private var nextWalkerID = 0

    @Published private(set) var militia: [MilitiaSoldier] = []
    private var garrisonsBySlot: [Int: MilitiaGarrison] = [:]
    private var blockedWalkerIDs: Set<Int> = []
    private var lastMilitiaTick: Int64 = 0

    private var militiaPrevPositions: [Int: CGPoint] = [:]
    private var militiaRespawnedIDs: Set<Int> = []
    private var militiaPoses: [Int: WalkPose] = [:]
    private let meleeFormation = MeleeFormation()
    private static let reinforcementCount = 2
    private var nextReinforcementSlot = -1
    private var reinforcementSchedule: ReinforcementSchedule?
    @Published private(set) var reinforcementCooldown: ReinforcementCooldown = .ready
    @Published private(set) var isPlacingReinforcements = false

    var canCallReinforcements: Bool {
        isReady && !isDefeated && !isCleared && reinforcementStats != nil
            && reinforcementSchedule?.cooldown(at: timer.tick).isReady == true
    }

    @Published private(set) var heroes: [HeroSoldier] = []
    @Published private(set) var selectedHeroIndex: Int?
    private var heroPosts: [HeroPost] = []

    var hudHeroes: [Hero] {
        heroSelection?.heroes ?? []
    }

    func hudHeroIndex(for heroID: UUID) -> Int? {
        heroPosts.firstIndex { $0.hero.id == heroID && $0.unit.state != .dead }
    }
    private var heroRespawnedIDs: Set<Int> = []
    private var heroPoses: [Int: HeroWalkPose] = [:]

    private struct ScheduledSpawn {
        let tick: Int64
        let enemyTypeID: UUID
        let pathIndex: Int
    }

    private var pendingSpawns: [ScheduledSpawn] = []

    @Published private(set) var speedMultiplier = 1

    @Published private(set) var status: String = "Loading…"

    private(set) var isReady = false

    private var paths: [Path] = []

    private var callWaveButtons: [CallWaveButtonPosition] = []

    var callWaveButtonPositions: [Point] {
        let next = waveSchedule.nextWaveIndex
        guard waves.indices.contains(next) else { return [] }
        return CallWaveButtonPosition.visiblePositions(
            callWaveButtons, forPathIndices: Set(waves[next].spawns.map(\.pathIndex)))
    }

    private var levelName = ""
    private var enemyTypesByID: [UUID: EnemyType] = [:]
    private var waves: [Wave] = []
    private var waveIndex = 0
    private var waveSchedule = WaveStartSchedule()

    var waveCount: Int { waves.count }
    var currentWaveNumber: Int { min(waveIndex + 1, max(waves.count, 1)) }
    var nextWaveNumber: Int { waveSchedule.nextWaveIndex + 1 }

    private let timer = Timer(tickDuration: LevelRunner.normalTickDuration)
    private var displayLink: CADisplayLink?

    private let enemyHPMultiplier: Double

    private let db: Db
    private let virtualCanvas: VirtualCanvas
    private var runtimeCanvas: RuntimeCanvas
    private let hudLayoutConfig: HudLayoutConfig

    init(db: Db,
         virtualCanvas: VirtualCanvas,
         runtimeCanvas: RuntimeCanvas,
         hudLayoutConfig: HudLayoutConfig = .standard,
         levelInfoID: UUID?,
         mapImageName: String,
         enemyHPMultiplier: Double = 1.0) {
        self.db = db
        self.virtualCanvas = virtualCanvas
        self.runtimeCanvas = runtimeCanvas
        self.hudLayoutConfig = hudLayoutConfig.moving(.heroBar, to: .southWest)
        self.mapImageName = mapImageName
        self.mapArt = LevelMapArt(mapImageName: mapImageName)
        self.playArea = virtualCanvas.playAreaRect
        self.enemyHPMultiplier = enemyHPMultiplier
        super.init()
        load(levelInfoID: levelInfoID)
    }

    private func load(levelInfoID: UUID?) {
        guard let levelInfoID else {
            status = "This campaign node has no level_info id."
            return
        }
        guard Bundle.main.url(forResource: "in_defense_of_history", withExtension: "sqlite") != nil else {
            status = "in_defense_of_history.sqlite is not in the app bundle."
            return
        }

        do {
            reinforcementSchedule = ReinforcementSchedule(config: try db.reinforcementConfigDao.get())
            let level = try db.levelLoader.load(id: levelInfoID)
            let enemies = try db.enemyTypeDao.getAll()
            callWaveButtons = try db.levelGeoJSONDao.getCallWaveButtons(mapImageName: level.mapImageName)
            exitPositions = try db.levelGeoJSONDao.getExitPoints(mapImageName: level.mapImageName)
                .map { CGPoint(x: $0.position.x, y: $0.position.y) }

            let chosen = try HeroSelectionStore(dao: db.heroDao).load()
            chosenHeroes = chosen
            let heroConfiguration = try db.levelGeoJSONDao.getHeroConfiguration(mapImageName: level.mapImageName)
            let deployments = heroConfiguration.deployments(for: chosen)
            heroImageAspectRatios = try Dictionary(uniqueKeysWithValues: deployments.map { deployment in
                guard let name = deployment.hero.unitImageName, let image = UIImage(named: name),
                      image.size.width > 0, image.size.height > 0 else {
                    throw DbError.Db(message: "Missing sprite dimensions for \(deployment.hero.shortName)")
                }
                return (deployment.hero.id, image.size.width / image.size.height)
            })
            if deployments.isEmpty { heroSelection = nil }
            else { heroSelection = try HeroSelection(heroes: deployments.map(\.hero)) }

            let unlockRows = try db.towerUnlockDao.getUnlocksFor(levelInfoId: levelInfoID)
            towerUnlocks = Dictionary(uniqueKeysWithValues: unlockRows.compactMap { key, value in
                TowerKind(rawValue: key).map { ($0, value) }
            })

            levelName = level.name
            playArea = level.playArea
            if !level.mapImageName.isEmpty {
                mapImageName = level.mapImageName
                mapArt = LevelMapArt(mapImageName: level.mapImageName)
            }
            startingMoney = level.startingMoney
            money = level.startingMoney
            startingLives = level.numStartingLives
            lives = level.numStartingLives

            let costRows = try db.towerTypeDao.getCostsByLevel()
            towerCosts = Dictionary(uniqueKeysWithValues: costRows.compactMap { category, levels in
                TowerKind(categoryName: category).map { ($0, levels) }
            })

            let detailRows = try db.towerTypeDao.getMenuDetailsByLevel()
            towerMenuDetails = Dictionary(uniqueKeysWithValues: detailRows.compactMap { category, levels in
                TowerKind(categoryName: category).map { ($0, levels) }
            })
            for kind in TowerKind.allCases {
                guard menuDetails(for: kind, atLevel: 1) != nil else {
                    throw DbError.Db(message: "Missing authored base tower text for \(kind)")
                }
                guard let costs = towerCosts[kind] else {
                    throw DbError.Db(message: "Missing authored tower costs for \(kind)")
                }
                for (level, branches) in costs {
                    for branch in branches.keys where menuDetails(for: kind, atLevel: level, branch: branch) == nil {
                        throw DbError.Db(message: "Missing authored tower text for \(kind), level \(level), branch \(branch)")
                    }
                }
            }

            let tuningRows = try db.towerTypeDao.getTowerLevelsByBranch()
            towerLevels = Dictionary(uniqueKeysWithValues: tuningRows.compactMap { category, levels in
                TowerKind(categoryName: category).map { ($0, levels) }
            })
            slotPositions = level.towerSlots.map { CGPoint(x: $0.position.x, y: $0.position.y) }

            guard !level.paths.isEmpty else {
                status = "\(level.name): no path in the database."
                return
            }
            enemyTypesByID = Dictionary(uniqueKeysWithValues: enemies.map { ($0.id, $0) })
            waves = level.waves
            guard !waves.isEmpty else {
                status = "\(level.name): no waves in the database."
                return
            }

            paths = level.paths
            let movementArea = try db.levelGeoJSONDao.getHeroMovementArea(
                mapImageName: level.mapImageName, defaultPathWidth: virtualCanvas.pathWidth)
            heroPosts = try deployments.map { deployment in
                let hero = deployment.hero
                guard let assetName = hero.unitImageName else {
                    throw DbError.Db(message: "Missing unit image for \(hero.shortName)")
                }
                let combat = try db.heroDao.getCombatStats(heroID: hero.id)
                let position = deployment.spawn.position
                let movement = try HeroMovement(area: movementArea, spawn: position)
                return HeroPost(hero: hero, assetName: assetName, combat: combat,
                    unit: MilitiaUnit(position: position, hp: combat.hp),
                    movement: movement)
            }
            publishHeroes()
            precomputeLaneCoverage()
            waveSchedule = try WaveStartSchedule(waves: waves)
            isReady = true
            refreshWaveStartState()
            status = "\(levelName)  •  wave 1/\(waves.count) waiting  •  tap an entrance, then tap to confirm"
        } catch {
            fatalError("Database load failed: \(error)")
        }
    }

    func isSlotOccupied(_ index: Int) -> Bool {
        placedTowers.contains { $0.slotIndex == index }
    }

    func placedTower(atSlot index: Int) -> PlacedTower? {
        placedTowers.first { $0.slotIndex == index }
    }

    func maxLevel(for kind: TowerKind) -> Int {
        guard let maximum = towerUnlocks[kind] else {
            fatalError("Missing database tower unlock for \(kind)")
        }
        return maximum
    }

    func selectSlot(_ index: Int) {
        guard !isSlotOccupied(index) else { return }
        isPlacingReinforcements = false
        isPlacingDemolition = false
        isPlacingEngineerObstacles = false
        if selectedHeroIndex != nil {
            selectedHeroIndex = nil
            publishHeroes()
        }
        selectedTowerSlotIndex = nil
        armedBuildKind = nil
        armedUpgradeBranch = nil
        selectedSlotIndex = selectedSlotIndex == index ? nil : index
    }

    func selectPlacedTower(atSlot index: Int) {
        guard isSlotOccupied(index) else { return }
        isPlacingReinforcements = false
        isPlacingDemolition = false
        isPlacingEngineerObstacles = false
        if selectedHeroIndex != nil {
            selectedHeroIndex = nil
            publishHeroes()
        }
        selectedSlotIndex = nil
        armedBuildKind = nil
        armedUpgradeBranch = nil
        isPlacingRallyPoint = false
        selectedTowerSlotIndex = selectedTowerSlotIndex == index ? nil : index
    }

    func dismissMenu() {
        selectedSlotIndex = nil
        selectedTowerSlotIndex = nil
        armedBuildKind = nil
        armedUpgradeBranch = nil
        isPlacingRallyPoint = false
        isPlacingDemolition = false
        isPlacingEngineerObstacles = false
    }

    func tapBuildButton(_ kind: TowerKind) {
        guard selectedSlotIndex != nil, maxLevel(for: kind) >= 1 else { return }
        if armedBuildKind == kind {
            guard let cost = buildCost(for: kind), money >= cost else {
                dismissMenu()
                return
            }
            buildTower(kind)
        } else if armedBuildKind != nil {
            armedBuildKind = nil
        } else {
            armedBuildKind = kind
        }
    }

    func buildPreviewRadius(for kind: TowerKind) -> CGFloat? {
        guard let cost = buildCost(for: kind), money >= cost else { return nil }
        return towerLevels[kind]?[1]?[1].flatMap(Self.overlayRadius)
    }

    func rangeOverlayRadius(for tower: PlacedTower) -> CGFloat? {
        towerLevel(for: tower).flatMap(Self.overlayRadius)
    }

    func tapUpgradeButton(branch: Int) {
        guard let offer = upgradeOffers.first(where: { $0.branch == branch }) else { return }
        if armedUpgradeBranch == branch {
            guard money >= offer.cost else {
                dismissMenu()
                return
            }
            upgradeSelectedTower(branch: branch)
        } else {
            armedUpgradeBranch = branch
            isPlacingRallyPoint = false
        }
    }

    func upgradePreviewRadius(branch: Int) -> CGFloat? {
        guard let slotIndex = selectedTowerSlotIndex,
              let tower = placedTower(atSlot: slotIndex),
              let offer = upgradeOffers.first(where: { $0.branch == branch }),
              money >= offer.cost
        else { return nil }
        return towerLevels[tower.kind]?[offer.nextLevel]?[offer.branch]
            .flatMap(Self.overlayRadius)
    }

    private static func overlayRadius(for tuning: TowerLevel) -> CGFloat? {
        if let melee = tuning.meleeUnit { return CGFloat(melee.rallyPointRadius) }
        return tuning.attackRange.radius > 0 ? tuning.attackRange.radius : nil
    }

    func buildTower(_ kind: TowerKind) {
        guard let slotIndex = selectedSlotIndex,
              maxLevel(for: kind) >= 1,
              kind.assetName != nil,
              !isSlotOccupied(slotIndex),
              slotPositions.indices.contains(slotIndex),
              let cost = buildCost(for: kind),
              money >= cost
        else { return }
        money -= cost
        var tower = PlacedTower(
            slotIndex: slotIndex,
            kind: kind,
            position: slotPositions[slotIndex]
        )
        if let tuning = towerLevel(for: tower), tuning.engineerObstacles != nil {
            tower.engineerObstaclePosition = tuning.attackRange.nearestPathPoint(
                to: tower.position, from: tower.position, paths: paths)
        }
        placedTowers.append(tower)
        if let melee = towerLevel(for: tower)?.meleeUnit {
            let towerPos = Point(Double(tower.position.x), Double(tower.position.y))
            let rally = Simulation.defaultRallyPoint(
                towerPosition: towerPos,
                flagRange: melee.rallyPointRadius,
                paths: paths)
            rallyPointsBySlot[slotIndex] = CGPoint(x: rally.x, y: rally.y)
            garrisonsBySlot[slotIndex] = MilitiaGarrison(
                rallyPoint: rally,
                units: (0..<melee.soldierCount).map { index in
                    MilitiaUnit(position: meleeFormation.spawnPoint(
                        index: index, of: melee.soldierCount, building: towerPos),
                                hp: melee.hp)
                })
            publishMilitia()
        }
        selectedSlotIndex = nil
        armedBuildKind = nil
    }

    var upgradeOffers: [(nextLevel: Int, branch: Int, cost: Int)] {
        guard let slotIndex = selectedTowerSlotIndex,
              let tower = placedTower(atSlot: slotIndex) else { return [] }
        let next = tower.level + 1
        guard next <= maxLevel(for: tower.kind) else { return [] }
        guard let branches = towerCosts[tower.kind]?[next] else {
            fatalError("Missing database upgrade costs for \(tower.kind), level \(next)")
        }
        return branches.keys.sorted().compactMap { branch in
            if let tuning = towerLevels[tower.kind]?[next]?[branch],
               tuning.demolitionPreparationSeconds != nil,
               tuning.attackRange.nearestPathPoint(to: tower.position, from: tower.position, paths: paths) == nil {
                return nil
            }
            return branches[branch].map { (next, branch, $0) }
        }
    }

    func upgradeSelectedTower(branch: Int = 1) {
        guard let slotIndex = selectedTowerSlotIndex,
              let offer = upgradeOffers.first(where: { $0.branch == branch }),
              let arrayIndex = placedTowers.firstIndex(where: { $0.slotIndex == slotIndex }),
              money >= offer.cost
        else { return }
        money -= offer.cost
        placedTowers[arrayIndex].level = offer.nextLevel
        placedTowers[arrayIndex].branch = offer.branch
        if towerLevel(for: placedTowers[arrayIndex])?.engineerObstacles == nil {
            placedTowers[arrayIndex].engineerObstaclePosition = nil
        } else if placedTowers[arrayIndex].engineerObstaclePosition == nil,
                  let tuning = towerLevel(for: placedTowers[arrayIndex]) {
            let origin = placedTowers[arrayIndex].position
            placedTowers[arrayIndex].engineerObstaclePosition = tuning.attackRange.nearestPathPoint(
                to: origin, from: origin, paths: paths)
        }
        if let tuning = towerLevel(for: placedTowers[arrayIndex]),
           let preparation = tuning.demolitionPreparationSeconds {
            placedTowers[arrayIndex].demolitionCharge = DemolitionCharge(preparationSeconds: preparation)
        }
        if var g = garrisonsBySlot[slotIndex],
           let melee = towerLevel(for: placedTowers[arrayIndex])?.meleeUnit {

            for i in 0..<g.units.count where g.units[i].state != .dead {
                g.units[i].hp = melee.hp
            }
            garrisonsBySlot[slotIndex] = g
            publishMilitia()
        }
        selectedTowerSlotIndex = nil
        armedUpgradeBranch = nil
    }

    private func refreshWaveStartState() {
        let state = waveSchedule.state(at: timer.tick)
        let visible = !isDefeated && !isCleared && state.canCall
        if awaitingWaveStart != visible { awaitingWaveStart = visible }
        let seconds: Int?
        if visible, case .countingDown(let remaining) = state {
            seconds = remaining
        } else {
            seconds = nil
        }
        if waveCountdownSeconds != seconds { waveCountdownSeconds = seconds }
    }

    func startNextWave() {
        guard isReady, !isDefeated, !isCleared,
              let start = waveSchedule.startNextWave(at: timer.tick, manually: true)
        else { return }
        money += start.moneyBonus
        enterWave(start.index)
        refreshWaveStartState()
    }

    private func advanceWaveSchedule() {

        while let start = waveSchedule.startNextWave(at: timer.tick, manually: false) {
            enterWave(start.index)
        }
        refreshWaveStartState()
    }

    private func enterWave(_ index: Int) {
        guard waves.indices.contains(index) else { return }
        waveIndex = index
        let wave = waves[index]
        let base = timer.tick

        var scheduled: [ScheduledSpawn] = []
        for entry in wave.spawns {
            for i in 0..<entry.count {
                let seconds = entry.delay + Double(i) * entry.interval
                scheduled.append(ScheduledSpawn(
                    tick: base + Int64((seconds / SimClock.dt).rounded()),
                    enemyTypeID: entry.enemyTypeID,
                    pathIndex: entry.pathIndex))
            }
        }

        pendingSpawns.append(contentsOf: scheduled)
        pendingSpawns.sort { $0.tick < $1.tick }
        status = "\(levelName)  •  wave \(index + 1)/\(waves.count)  •  "
            + "\(scheduled.count) enemies"
    }

    func start() {
        guard isReady, (!isDefeated && !isCleared) || !artilleryImpacts.isEmpty,
              displayLink == nil else { return }
        timer.resync()
        lastStepGameTicks = Double(timer.tick) + timer.interpolationAlpha
        lastMilitiaTick = timer.tick

        refreshWaveStartState()
        hapticsActive = true
        startHapticEngine()
        let link = CADisplayLink(target: self, selector: #selector(handleFrame))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        stopSimulation()
        hapticsActive = false
        try? activeHapticPlayer?.stop(atTime: CHHapticTimeImmediate)
        activeHapticPlayer = nil
        try? demolitionHapticPlayer?.stop(atTime: CHHapticTimeImmediate)
        demolitionHapticPlayer = nil
        hapticEngine?.stop()
        hapticEngine = nil
    }

    private func stopSimulation() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func startHapticEngine() {
        guard hapticsActive, hapticEngine == nil,
              CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = try? CHHapticEngine() else { return }
        engine.isAutoShutdownEnabled = true
        engine.playsHapticsOnly = true
        engine.resetHandler = { [weak self, weak engine] in
            Task { @MainActor in
                guard let self, let engine, self.hapticsActive,
                      self.hapticEngine === engine else { return }
                self.activeHapticPlayer = nil
                self.demolitionHapticPlayer = nil
                try? engine.start()

            }
        }
        try? engine.start()
        hapticEngine = engine
    }

    func playEnemyEscapeHaptic(_ cue: EnemyEscapeHapticPolicy.Cue) {
        _ = playGameplayHaptic(cue == .defeat ? .defeat : .lifeLoss)
    }

    @discardableResult private func playGameplayHaptic(_ pattern: GameplayHapticPattern) -> HapticPlayback {
        guard hapticsActive else { return .inactive }
        if pattern == .demolitionExplosion {
            try? demolitionHapticPlayer?.stop(atTime: CHHapticTimeImmediate)
            demolitionHapticPlayer = nil
        } else {
            try? activeHapticPlayer?.stop(atTime: CHHapticTimeImmediate)
            activeHapticPlayer = nil
        }
        startHapticEngine()
        func fallback() -> HapticPlayback {
            if pattern == .demolitionExplosion {
                demolitionFeedback.impactOccurred(intensity: 1)
            } else {
                enemyEscapeFeedback.notificationOccurred(.error)
            }
            return .fallback
        }
        do {
            guard let engine = hapticEngine else { return fallback() }
            try engine.start()
            if pattern == .demolitionExplosion {
                let player = try engine.makeAdvancedPlayer(with: pattern.makePattern())
                #if DEBUG
                demolitionHapticCompleted = nil
                player.completionHandler = { [weak self] error in
                    let succeeded = error == nil
                    Task { @MainActor in self?.demolitionHapticCompleted = succeeded }
                }
                #endif
                try player.start(atTime: CHHapticTimeImmediate)
                demolitionHapticPlayer = player
            } else {
                let player = try engine.makePlayer(with: pattern.makePattern())
                try player.start(atTime: CHHapticTimeImmediate)
                activeHapticPlayer = player
            }
            return .coreHaptics
        } catch {

            return fallback()
        }
    }

    private func loseLife() {
        guard !isDefeated else { return }
        lives = max(0, lives - 1)
        escapedEnemyCount += 1
        guard lives == 0 else { return }
        isDefeated = true
        pendingSpawns.removeAll()
        refreshWaveStartState()

        if artilleryImpacts.isEmpty { stopSimulation() }
    }

    func speedUp() {
        timer.setTickDuration(timer.tickDuration / 2)
        speedMultiplier *= 2
    }

    @objc private func handleFrame() {
        step()
    }

    private func step() {
        guard !paths.isEmpty else { return }
        if isCleared || isDefeated {

            for _ in 0..<timer.dueTicks() { timer.advanceTick() }
            let nowTicks = Double(timer.tick) + timer.interpolationAlpha
            let gameDt = max(0, nowTicks - lastStepGameTicks) * SimClock.dt
            lastStepGameTicks = nowTicks
            advanceArtilleryImpacts(seconds: gameDt)
            if artilleryImpacts.isEmpty { stopSimulation() }
            return
        }

        for _ in 0..<timer.dueTicks() {
            timer.advanceTick()
            advanceWaveSchedule()
        }
        advanceReinforcements()
        refreshTowerStatsIfDue()

        while let next = pendingSpawns.first, timer.tick >= next.tick {
            pendingSpawns.removeFirst()
            guard let type = enemyTypesByID[next.enemyTypeID] else { continue }
            let stats = type.stats
            let maxHP = stats.maxHP * enemyHPMultiplier
            walkers.append(Walker(
                id: nextWalkerID,
                assetName: type.imageName,
                speed: stats.speed,
                maxHP: maxHP,
                hp: maxHP,
                bounty: stats.gold,
                damageMin: stats.damageMin,
                damageMax: stats.damageMax,
                cover: stats.cover,
                blockImmune: type.traits.contains(.rideDown),
                spawnTick: next.tick,
                pathIndex: next.pathIndex,
                discipline: stats.discipline,
                moraleResponse: stats.moraleResponse,
                position: {
                    let point = paths[min(max(next.pathIndex, 0), paths.count - 1)].point(atDistance: 0)
                    return CGPoint(x: point.x, y: point.y)
                }()
            ))
            nextWalkerID += 1
        }

        let alpha = timer.interpolationAlpha
        let nowTicks = Double(timer.tick) + alpha
        let frameDtTicks = max(0, nowTicks - lastStepGameTicks)
        lastStepGameTicks = nowTicks
        let gameDt = frameDtTicks * SimClock.dt
        advanceArtilleryImpacts(seconds: gameDt)
        advanceWalkers(seconds: gameDt, nowTicks: nowTicks)

        guard !isDefeated else { return }

        stepMilitia()
        if !garrisonsBySlot.isEmpty {
            publishMilitia(alpha: alpha)
        }
        if !heroPosts.isEmpty {
            publishHeroes(alpha: alpha)
        }

        if waveSchedule.allWavesStarted && pendingSpawns.isEmpty && walkers.isEmpty && !isCleared {
            isCleared = true
            refreshWaveStartState()
            status = "\(levelName)  •  all \(waves.count) waves cleared"
        }

        updateCombat(gameDt: gameDt)
    }

    private func stepMilitia() {
        guard timer.tick > lastMilitiaTick else { return }
        let dueTicks = min(Int(timer.tick - lastMilitiaTick), 8)
        lastMilitiaTick = timer.tick
        guard !garrisonsBySlot.isEmpty || !heroPosts.isEmpty else {
            blockedWalkerIDs.removeAll()
            return
        }
        for (id, post) in heroPosts.enumerated() where post.unit.state != .dead && heroPoses[id] == nil {
            heroPoses[id] = HeroWalkPose(baseAssetName: post.assetName, position: post.unit.position)
        }
        for _ in 0..<dueTicks {

            militiaPrevPositions = militiaPositionsById()
            militiaRespawnedIDs.removeAll()
            heroRespawnedIDs.removeAll()
            stepMilitiaTick()
            if !militiaRespawnedIDs.isEmpty {
                let now = militiaPositionsById()
                for id in militiaRespawnedIDs {
                    militiaPrevPositions[id] = now[id]
                }
            }
            updateMilitiaPoses()
            updateHeroPoses()
        }
    }

    private func updateMilitiaPoses() {
        let now = militiaPositionsById()
        let enemies = Dictionary(uniqueKeysWithValues: walkers.map { ($0.id, $0.position) })
        var combatTargets: [Int: CGPoint] = [:]
        for (slot, garrison) in garrisonsBySlot {
            for (index, unit) in garrison.units.enumerated() where unit.state == .fighting {
                combatTargets[slot * 8 + index] = enemies[unit.targetSpawnID]
            }
        }
        var poses: [Int: WalkPose] = [:]
        poses.reserveCapacity(now.count)
        for (id, cur) in now {
            let prev = militiaPrevPositions[id] ?? cur
            let dx = Double(cur.x - prev.x)
            let dy = Double(cur.y - prev.y)
            let moved = (dx * dx + dy * dy).squareRoot()
            var pose = militiaPoses[id]
                ?? WalkPose(facing: .south, walkPhase: 0, isWalking: false)
            pose.isWalking = moved > MeleeWalkCycle.walkingThreshold
            if pose.isWalking {
                pose.facing = UnitFacing(dx: dx, dy: dy)
                pose.walkPhase = (pose.walkPhase + moved)
                    .truncatingRemainder(dividingBy: MeleeWalkCycle.cycleDistance)
            } else if let target = combatTargets[id] {
                pose.facing = UnitFacing(dx: target.x - cur.x, dy: target.y - cur.y)
            }
            poses[id] = pose
        }
        militiaPoses = poses
    }

    private func updateHeroPoses() {
        var poses: [Int: HeroWalkPose] = [:]
        poses.reserveCapacity(heroPosts.count)
        for (id, post) in heroPosts.enumerated() where post.unit.state != .dead {
            var pose = (heroRespawnedIDs.contains(id) ? nil : heroPoses[id])
                ?? HeroWalkPose(baseAssetName: post.assetName, position: post.unit.position)
            pose.advance(to: post.unit.position)
            if post.unit.state == .fighting,
               let target = walkers.first(where: { $0.id == post.unit.targetSpawnID }) {
                pose.face(toward: Point(target.position.x, target.position.y))
            }
            poses[id] = pose
        }
        heroPoses = poses
    }

    private var reinforcementStats: MeleeUnitStats? {
        guard let levels = towerLevels[.melee] else { return nil }
        for level in levels.keys.sorted() {
            guard let branches = levels[level] else { continue }
            for branch in branches.keys.sorted() {
                if let melee = branches[branch]?.meleeUnit { return melee }
            }
        }
        return nil
    }

    private func garrisonMelee(slot: Int,
                               garrison: MilitiaGarrison) -> (stats: MeleeUnitStats,
                                                              anchor: Point)? {
        if let stats = garrison.stats, let anchor = garrison.anchor {
            return (stats, anchor)
        }
        guard let tower = placedTower(atSlot: slot),
              let stats = towerLevel(for: tower)?.meleeUnit else { return nil }
        return (stats, Point(Double(tower.position.x), Double(tower.position.y)))
    }

    @discardableResult
    func callReinforcements(at point: CGPoint) -> Bool {
        guard canCallReinforcements, let melee = reinforcementStats,
              reinforcementSchedule?.deploy(slot: nextReinforcementSlot, at: timer.tick) == true
        else { return false }
        let anchor = Point(Double(point.x), Double(point.y))
        garrisonsBySlot[nextReinforcementSlot] = MilitiaGarrison(
            rallyPoint: anchor,
            units: (0..<Self.reinforcementCount).map { index in
                MilitiaUnit(position: meleeFormation.spawnPoint(
                    index: index, of: Self.reinforcementCount, building: anchor),
                            hp: melee.hp)
            },
            stats: melee,
            anchor: anchor)
        nextReinforcementSlot -= 1
        isPlacingReinforcements = false
        reinforcementCooldown = reinforcementSchedule!.cooldown(at: timer.tick)
        publishMilitia()
        return true
    }

    func toggleReinforcementPlacement() {
        guard canCallReinforcements else { return }
        dismissMenu()
        if selectedHeroIndex != nil {
            selectedHeroIndex = nil
            publishHeroes()
        }
        isPlacingReinforcements.toggle()
    }

    func placeReinforcements(at point: CGPoint) {
        guard isPlacingReinforcements, isOnPath(point) else { return }
        callReinforcements(at: point)
    }

    private func advanceReinforcements() {
        guard let expired = reinforcementSchedule?.expire(at: timer.tick) else { return }
        let cooldown = reinforcementSchedule!.cooldown(at: timer.tick)
        if reinforcementCooldown != cooldown { reinforcementCooldown = cooldown }
        guard !expired.isEmpty else { return }
        for slot in expired {
            guard let garrison = garrisonsBySlot.removeValue(forKey: slot) else { continue }
            for index in garrison.units.indices {
                let id = slot * 8 + index
                militiaPrevPositions[id] = nil
                militiaPoses[id] = nil
                militiaRespawnedIDs.remove(id)
            }
            damageTotalBySlot[slot] = nil
        }

        let fightingUnits = garrisonsBySlot.values.flatMap(\.units) + heroPosts.map(\.unit)
        blockedWalkerIDs = Set(fightingUnits.filter { $0.state == .fighting && $0.targetSpawnID >= 0 }
            .map(\.targetSpawnID))

        publishMilitia()
    }

    private func militiaPositionsById() -> [Int: CGPoint] {
        var out: [Int: CGPoint] = [:]
        for (slot, g) in garrisonsBySlot {
            for (i, u) in g.units.enumerated() where u.state != .dead {
                out[slot * 8 + i] = CGPoint(x: u.position.x, y: u.position.y)
            }
        }
        return out
    }

    private func pathNearest(to target: Point) -> Path? {
        var nearest: Path?
        var nearestGap = Double.infinity
        for path in paths {
            let gap = path.point(atDistance: path.nearestDistance(to: target)).distance(to: target)
            if gap < nearestGap {
                nearestGap = gap
                nearest = path
            }
        }
        return nearest
    }

    private func marchWaypoint(from current: Point, to target: Point,
                               path: Path, targetAlong: Double) -> Point {
        let fallInRadius = meleeFormation.postSpread
        guard current.distance(to: target) > fallInRadius else { return target }
        let currentAlong = path.nearestDistance(to: current)
        let remaining = targetAlong - currentAlong
        guard abs(remaining) > fallInRadius else { return target }
        let lookahead = remaining > 0 ? fallInRadius : -fallInRadius
        return path.point(atDistance: currentAlong + lookahead)
    }

    private func stepMilitiaTick() {
        let dt = SimClock.dt

        var claimed: Set<Int> = []
        for post in heroPosts where post.unit.state != .dead && post.unit.targetSpawnID >= 0 {
            claimed.insert(post.unit.targetSpawnID)
        }
        for (_, g) in garrisonsBySlot.sorted(by: { $0.key < $1.key }) {
            for u in g.units where u.targetSpawnID >= 0 {
                claimed.insert(u.targetSpawnID)
            }
        }

        var indexByWalkerID: [Int: Int] = [:]
        for (i, w) in walkers.enumerated() {
            indexByWalkerID[w.id] = i
        }
        var killedIDs: Set<Int> = []

        blockedWalkerIDs.removeAll(keepingCapacity: true)

        for slot in garrisonsBySlot.keys.sorted() {
            guard var g = garrisonsBySlot[slot],
                  let resolved = garrisonMelee(slot: slot, garrison: g)
            else { continue }
            let melee = resolved.stats
            let towerPos = resolved.anchor
            let marchPath = pathNearest(to: g.rallyPoint)
            let marchTargetAlong = marchPath?.nearestDistance(to: g.rallyPoint)

            var free: [(spawnID: Int, position: Point)] = []
            for w in walkers where !w.blockImmune && !claimed.contains(w.id)
                && !killedIDs.contains(w.id) {
                free.append((w.id, Point(Double(w.position.x), Double(w.position.y))))
            }

            for ui in 0..<g.units.count {
                var unit = g.units[ui]
                var targetPos: Point? = nil
                if unit.targetSpawnID >= 0, !killedIDs.contains(unit.targetSpawnID),
                   let wi = indexByWalkerID[unit.targetSpawnID] {
                    targetPos = Point(Double(walkers[wi].position.x),
                                      Double(walkers[wi].position.y))
                }
                let context = MilitiaContext(
                    freeEnemies: free,
                    targetPosition: targetPos,
                    rallyPoint: meleeFormation.postPoint(index: ui, of: g.units.count,
                                                        rallyPoint: g.rallyPoint),
                    towerPosition: towerPos,
                    leashRadius: melee.leashRadius,
                    engageScanRadius: melee.engageScanRadius)
                if unit.swingTicksLeft > 0 { unit.swingTicksLeft -= 1 }

                switch MilitiaAI.decide(unit, context: context) {
                case .idle:
                    if unit.state == .returning { unit.state = .holding }
                case .countdownRespawn:
                    unit.respawnTicksLeft -= 1
                case .respawn:
                    unit = MilitiaUnit(position: meleeFormation.spawnPoint(
                        index: ui, of: g.units.count, building: towerPos), hp: melee.hp)
                    militiaRespawnedIDs.insert(slot * 8 + ui)
                case .heal:
                    unit.hp = min(melee.hp, unit.hp + melee.healPerSecond * dt)
                case let .move(toward):
                    let chasing = unit.state == .engaging || unit.state == .fighting
                    let waypoint: Point
                    if !chasing, let path = marchPath, let targetAlong = marchTargetAlong {
                        waypoint = marchWaypoint(from: unit.position, to: toward,
                                                 path: path, targetAlong: targetAlong)
                    } else {
                        waypoint = toward
                    }
                    let d = unit.position.distance(to: waypoint)
                    let step = MilitiaTunables.moveSpeed * dt
                    unit.position = d <= step ? waypoint
                        : Point.lerp(unit.position, waypoint, step / d)
                case let .engage(targetSpawnID):
                    unit.state = .engaging
                    unit.targetSpawnID = targetSpawnID
                    claimed.insert(targetSpawnID)
                    free.removeAll { $0.spawnID == targetSpawnID }
                case let .strike(targetSpawnID):
                    if unit.state == .engaging {
                        unit.combatSide = unit.position.x < (targetPos?.x ?? unit.position.x) ? -1 : 1
                        unit.state = .fighting
                        g.enemySwingTicks[targetSpawnID] =
                            Simulation.fireTicks(MilitiaTunables.enemySwingInterval)
                    }
                    if !killedIDs.contains(targetSpawnID),
                       let wi = indexByWalkerID[targetSpawnID] {
                        var w = walkers[wi]
                        let roll = Double.random(in: melee.damageRange)
                        let dealt = min(w.hp, roll * (1.0 - w.cover))
                        w.hp -= roll * (1.0 - w.cover)
                        damageTotalBySlot[slot, default: 0] += dealt
                        walkers[wi] = w
                        if w.hp <= 0 {
                            money += w.bounty
                            killedIDs.insert(targetSpawnID)
                            unit.state = .holding
                            unit.targetSpawnID = -1
                            g.enemySwingTicks[targetSpawnID] = nil
                        }
                    }
                    unit.swingTicksLeft = Simulation.fireTicks(melee.attackInterval)
                case .disengage:
                    if unit.targetSpawnID >= 0 {
                        claimed.remove(unit.targetSpawnID)
                        g.enemySwingTicks[unit.targetSpawnID] = nil
                    }
                    unit.state = .returning
                    unit.targetSpawnID = -1
                }

                if unit.state == .fighting, unit.targetSpawnID >= 0,
                   !killedIDs.contains(unit.targetSpawnID),
                   let wi = indexByWalkerID[unit.targetSpawnID] {
                    blockedWalkerIDs.insert(unit.targetSpawnID)
                    var swing = g.enemySwingTicks[unit.targetSpawnID]
                        ?? Simulation.fireTicks(MilitiaTunables.enemySwingInterval)
                    swing -= 1
                    if swing <= 0 {
                        let w = walkers[wi]
                        unit.hp -= Double.random(in: w.meleeDamageRange)
                            * (1.0 - melee.defenseRating)
                        swing = Simulation.fireTicks(MilitiaTunables.enemySwingInterval)
                        if unit.hp <= 0 {
                            claimed.remove(unit.targetSpawnID)
                            blockedWalkerIDs.remove(unit.targetSpawnID)
                            g.enemySwingTicks[unit.targetSpawnID] = nil
                            unit.state = .dead
                            unit.targetSpawnID = -1
                            unit.respawnTicksLeft =
                                Simulation.fireTicks(melee.respawnSeconds)
                        }
                    }
                    if unit.targetSpawnID >= 0 {
                        g.enemySwingTicks[unit.targetSpawnID] = swing
                    }
                }

                g.units[ui] = unit
            }
            garrisonsBySlot[slot] = g
        }

        stepHeroesTick(claimed: &claimed, killedIDs: &killedIDs,
                       indexByWalkerID: indexByWalkerID)

        if !killedIDs.isEmpty {
            walkers.removeAll { killedIDs.contains($0.id) }
        }
    }

    func updateRuntimeCanvas(_ canvas: RuntimeCanvas) {
        runtimeCanvas = canvas
    }

    private func stepHeroesTick(claimed: inout Set<Int>,
                                killedIDs: inout Set<Int>,
                                indexByWalkerID: [Int: Int]) {
        guard !heroPosts.isEmpty else { return }
        let dt = SimClock.dt

        for hi in 0..<heroPosts.count {
            var post = heroPosts[hi]
            let station = post.movement.station

            var free: [(spawnID: Int, position: Point)] = []
            for w in walkers where !w.blockImmune && !claimed.contains(w.id)
                && !killedIDs.contains(w.id) {
                free.append((w.id, Point(Double(w.position.x), Double(w.position.y))))
            }

            var targetPos: Point? = nil
            if post.unit.targetSpawnID >= 0, !killedIDs.contains(post.unit.targetSpawnID),
               let wi = indexByWalkerID[post.unit.targetSpawnID] {
                targetPos = Point(Double(walkers[wi].position.x),
                                  Double(walkers[wi].position.y))
            }

            let context = MilitiaContext(freeEnemies: free,
                                         targetPosition: targetPos,
                                         rallyPoint: station,
                                         towerPosition: station,
                                         leashRadius: MilitiaTunables.heroLeashRadius,
                                         engageScanRadius: MilitiaTunables.heroEngageScanRadius)
            if post.unit.swingTicksLeft > 0 { post.unit.swingTicksLeft -= 1 }

            switch post.movement.update(&post.unit, context: context,
                                        moveSpeed: post.combat.moveSpeed, deltaTime: dt) {
            case .idle:
                break
            case .countdownRespawn:
                post.unit.respawnTicksLeft -= 1
            case .respawn:
                post.movement.respawn(unit: &post.unit, hp: post.combat.hp)
                heroRespawnedIDs.insert(hi)
            case .heal:
                post.unit.hp = min(post.combat.hp,
                                   post.unit.hp + post.combat.healPerSecond * dt)
            case .move:
                break
            case let .engage(targetSpawnID):
                post.unit.state = .engaging
                post.unit.targetSpawnID = targetSpawnID
                claimed.insert(targetSpawnID)
            case let .strike(targetSpawnID):
                if post.unit.state == .engaging {
                    post.unit.combatSide = post.unit.position.x < (targetPos?.x ?? post.unit.position.x) ? -1 : 1
                    post.unit.state = .fighting
                    post.enemySwingTicks[targetSpawnID] =
                        Simulation.fireTicks(MilitiaTunables.enemySwingInterval)
                }
                if !killedIDs.contains(targetSpawnID),
                   let wi = indexByWalkerID[targetSpawnID] {
                    var w = walkers[wi]
                    let roll = Double.random(in: post.combat.damageRange)
                    w.hp -= roll * (1.0 - w.cover)
                    walkers[wi] = w
                    if w.hp <= 0 {
                        money += w.bounty
                        killedIDs.insert(targetSpawnID)
                        post.unit.state = .holding
                        post.unit.targetSpawnID = -1
                        post.enemySwingTicks[targetSpawnID] = nil
                    }
                }
                post.unit.swingTicksLeft = Simulation.fireTicks(post.combat.attackInterval)
            case .disengage:
                if post.unit.targetSpawnID >= 0 {
                    claimed.remove(post.unit.targetSpawnID)
                    post.enemySwingTicks[post.unit.targetSpawnID] = nil
                }
                post.unit.state = .returning
                post.unit.targetSpawnID = -1
            }

            if post.unit.state == .fighting, post.unit.targetSpawnID >= 0,
               !killedIDs.contains(post.unit.targetSpawnID),
               let wi = indexByWalkerID[post.unit.targetSpawnID] {
                blockedWalkerIDs.insert(post.unit.targetSpawnID)
                var swing = post.enemySwingTicks[post.unit.targetSpawnID]
                    ?? Simulation.fireTicks(MilitiaTunables.enemySwingInterval)
                swing -= 1
                if swing <= 0 {
                    let w = walkers[wi]
                    post.unit.hp -= Double.random(in: w.meleeDamageRange)
                        * (1.0 - post.combat.defenseRating)
                    swing = Simulation.fireTicks(MilitiaTunables.enemySwingInterval)
                    if post.unit.hp <= 0 {
                        claimed.remove(post.unit.targetSpawnID)
                        blockedWalkerIDs.remove(post.unit.targetSpawnID)
                        post.enemySwingTicks[post.unit.targetSpawnID] = nil
                        post.unit.state = .dead
                        post.unit.targetSpawnID = -1
                        post.unit.respawnTicksLeft =
                            Simulation.fireTicks(post.combat.respawnSeconds)
                        if selectedHeroIndex == hi { selectedHeroIndex = nil }
                    }
                }
                if post.unit.targetSpawnID >= 0 {
                    post.enemySwingTicks[post.unit.targetSpawnID] = swing
                }
            }

            heroPosts[hi] = post
        }
    }

    private func publishHeroes(alpha: Double = 1) {
        var out: [HeroSoldier] = []
        for (i, post) in heroPosts.enumerated() where post.unit.state != .dead {
            let pose = heroPoses[i]
                ?? HeroWalkPose(baseAssetName: post.assetName, position: post.unit.position)
            let sample = pose.sample(alpha: alpha)
            out.append(HeroSoldier(
                id: i,
                assetName: sample.assetName,
                baseAssetName: post.assetName,
                imageAspectRatio: heroImageAspectRatios[post.hero.id]!,
                position: CGPoint(x: sample.position.x, y: sample.position.y),
                hp: post.unit.hp,
                maxHP: post.combat.hp,
                isSelected: selectedHeroIndex == i))
        }
        heroes = out
    }

    func isOnPath(_ point: CGPoint) -> Bool {
        let target = Point(Double(point.x), Double(point.y))
        let reach = virtualCanvas.pathWidth / 2
        for path in paths {
            let nearest = path.point(atDistance: path.nearestDistance(to: target))
            if nearest.distance(to: target) <= reach { return true }
        }
        return false
    }

    func selectHero(_ index: Int) {
        guard heroPosts.indices.contains(index), heroPosts[index].unit.state != .dead else { return }
        dismissMenu()
        isPlacingReinforcements = false
        selectedHeroIndex = selectedHeroIndex == index ? nil : index
        publishHeroes()
    }

    func selectHero(heroID: UUID) {
        guard let index = hudHeroIndex(for: heroID) else { return }
        selectHero(index)
    }

    @discardableResult
    func commandSelectedHero(to point: CGPoint) -> Bool {
        guard let index = selectedHeroIndex, heroPosts.indices.contains(index) else { return false }
        var post = heroPosts[index]
        let previousTarget = post.unit.targetSpawnID
        guard post.movement.command(to: Point(point.x, point.y), unit: &post.unit) else { return false }
        if previousTarget >= 0 {
            post.enemySwingTicks[previousTarget] = nil
            blockedWalkerIDs.remove(previousTarget)
        }
        heroPosts[index] = post
        selectedHeroIndex = nil
        publishHeroes()
        return true
    }

    private func publishMilitia(alpha: Double = 1) {
        var out: [MilitiaSoldier] = []
        for slot in garrisonsBySlot.keys.sorted() {
            guard let g = garrisonsBySlot[slot],
                  let resolved = garrisonMelee(slot: slot, garrison: g)
            else { continue }
            let melee = resolved.stats
            for (i, u) in g.units.enumerated() where u.state != .dead {
                let id = slot * 8 + i
                let cur = CGPoint(x: u.position.x, y: u.position.y)
                let prev = militiaPrevPositions[id] ?? cur
                let pose = militiaPoses[id]
                    ?? WalkPose(facing: .south, walkPhase: 0, isWalking: false)
                let stepDistance = hypot(Double(cur.x - prev.x),
                                         Double(cur.y - prev.y))
                let renderedPhase = MeleeWalkCycle.interpolatedPhase(
                    currentPhase: pose.walkPhase,
                    stepDistance: stepDistance,
                    alpha: alpha,
                    cycleDistance: MeleeWalkCycle.cycleDistance)
                out.append(MilitiaSoldier(
                    id: id,
                    assetName: MeleeWalkCycle.assetName(facing: pose.facing,
                                                        walkPhase: renderedPhase,
                                                        isWalking: pose.isWalking),
                    position: CGPoint(x: prev.x + (cur.x - prev.x) * alpha,
                                      y: prev.y + (cur.y - prev.y) * alpha),
                    hp: u.hp,
                    maxHP: melee.hp))
            }
        }
        militia = out
    }

    private static let enemyBodyOffset = CGPoint(x: 0, y: -12)

    private func bodyPoint(_ walker: Walker) -> CGPoint {
        CGPoint(x: walker.position.x + Self.enemyBodyOffset.x,
                y: walker.position.y + Self.enemyBodyOffset.y)
    }

    private func updateCombat(gameDt: Double) {
        guard !walkers.isEmpty else {
            updateProjectiles(gameDt: gameDt)
            return
        }

        let candidates = targetCandidates()

        for towerIndex in placedTowers.indices {
            let tower = placedTowers[towerIndex]
            guard tower.kind.projectileAssetName != nil else { continue }
            guard let tuning = towerLevel(for: tower) else { continue }
            guard tuning.demolitionPreparationSeconds == nil else { continue }
            let origin = tower.position
            let solution = RangedTargetCommand(
                tower: TowerTargetingContext(
                    slotIndex: tower.slotIndex,
                    position: Point(Double(origin.x), Double(origin.y)),
                    range: tuning.range,
                    targeting: tuning.targeting),
                enemies: candidates,
                paths: paths
            ).execute()
            guard let solution, let leader = walkers.first(where: { $0.id == solution.id })
            else { continue }

            targetingSecondsBySlot[tower.slotIndex, default: 0] += gameDt

            let target = tower.kind == .areaOfEffect
                ? tuning.attackRange.clamped(bodyPoint(leader), from: origin)
                : bodyPoint(leader)
            var heading = atan2(target.y - origin.y, target.x - origin.x)
            var aligned = true
            if tower.kind == .areaOfEffect {
                var aim = tower.artilleryAim
                aligned = aim.track(from: origin, to: target,
                                    radiansPerSecond: ArtilleryHandling.turnRate(
                                        level: tower.level, branch: tower.branch),
                                    deltaTime: gameDt)
                placedTowers[towerIndex].artilleryAim = aim
                heading = CGFloat(aim.heading)
            }

            guard aligned,
                  timer.tick >= nextFireTickBySlot[tower.slotIndex, default: 0] else { continue }
            nextFireTickBySlot[tower.slotIndex] = timer.tick + fireCooldownTicks(for: tower)
            let minDamage = tuning.shotMinDamage
            let maxDamage = max(minDamage, tuning.shotMaxDamage)
            if tower.kind == .areaOfEffect,
               ArtilleryHandling.isSwivel(level: tower.level, branch: tower.branch) {
                let volleyID = nextProjectileID
                let damage = Double.random(in: minDamage...maxDamage)
                for offset in GrapeshotFlight.spread {
                    let pelletHeading = heading + CGFloat(offset)
                    projectiles.append(Projectile(
                        id: nextProjectileID, kind: tower.kind, position: origin,
                        heading: pelletHeading, damage: damage,
                        targetID: leader.id, slotIndex: tower.slotIndex,
                        speed: CGFloat(tuning.projectileSpeed), splashRadius: 0,
                        firingBoundary: tuning.attackRange, firingOrigin: origin,
                        moraleStrike: ArtilleryMoraleStrike(tuning: tuning),
                        grapeshot: GrapeshotFlight(volleyID: volleyID,
                            range: tuning.attackRange.travelDistance(heading: pelletHeading))))
                    nextProjectileID += 1
                }
                continue
            }
            if tower.kind == .areaOfEffect,
               ArtilleryHandling.isSiege(level: tower.level, branch: tower.branch) {
                projectiles.append(Projectile(
                    id: nextProjectileID, kind: tower.kind, position: origin,
                    heading: heading, damage: Double.random(in: minDamage...maxDamage),
                    targetID: leader.id, slotIndex: tower.slotIndex,
                    speed: CGFloat(tuning.projectileSpeed), splashRadius: 0,
                    firingBoundary: tuning.attackRange, firingOrigin: origin,
                    moraleStrike: ArtilleryMoraleStrike(tuning: tuning),
                    solidShot: SolidShotFlight(range: tuning.attackRange.travelDistance(heading: heading))))
                nextProjectileID += 1
                continue
            }
            projectiles.append(Projectile(
                id: nextProjectileID,
                kind: tower.kind,
                position: origin,
                heading: heading,
                damage: Double.random(in: minDamage...maxDamage),
                targetID: leader.id,
                slotIndex: tower.slotIndex,
                speed: CGFloat(tuning.projectileSpeed),
                splashRadius: CGFloat(tuning.aoeRadius),
                impactPoint: tower.kind == .areaOfEffect ? target : nil,
                moraleStrike: tower.kind == .areaOfEffect ? ArtilleryMoraleStrike(tuning: tuning) : nil
            ))
            nextProjectileID += 1
        }

        updateProjectiles(gameDt: gameDt)
    }

    private func updateProjectiles(gameDt: Double) {
        var survivors: [Projectile] = []
        for var projectile in projectiles {
            if var flight = projectile.solidShot {
                let start = projectile.position
                let end = flight.advance(from: start, heading: projectile.heading,
                                         speed: projectile.speed, seconds: gameDt)
                let targets = walkers.compactMap { walker -> (id: Int, position: CGPoint)? in
                    if let boundary = projectile.firingBoundary, let origin = projectile.firingOrigin,
                       !boundary.contains(walker.position, from: origin) { return nil }
                    return (walker.id, bodyPoint(walker))
                }
                for id in flight.contacts(from: start, to: end, targets: targets) {
                    if let index = walkers.firstIndex(where: { $0.id == id }),
                       let strike = projectile.moraleStrike {
                        var walker = walkers[index]
                        applyMorale(strike, to: &walker, at: bodyPoint(walker))
                        walkers[index] = walker
                    }
                    damageWalker(id: id, damage: projectile.damage, slotIndex: projectile.slotIndex)
                }
                projectile.position = end
                projectile.solidShot = flight
                if flight.remainingDistance > 0 { survivors.append(projectile) }
                continue
            }
            if var flight = projectile.grapeshot {
                let distance = min(flight.remainingDistance, projectile.speed * CGFloat(gameDt))
                let end = CGPoint(x: projectile.position.x + cos(projectile.heading) * distance,
                                  y: projectile.position.y + sin(projectile.heading) * distance)
                let hit = walkers.compactMap { walker -> (id: Int, fraction: CGFloat)? in
                    if let boundary = projectile.firingBoundary, let origin = projectile.firingOrigin,
                       !boundary.contains(walker.position, from: origin) { return nil }
                    guard !grapeshotHits[flight.volleyID, default: []].contains(walker.id),
                          let fraction = GrapeshotFlight.hitFraction(
                            from: projectile.position, to: end, target: bodyPoint(walker)) else { return nil }
                    return (walker.id, fraction)
                }.min { $0.fraction < $1.fraction }
                if let hit {
                    if let index = walkers.firstIndex(where: { $0.id == hit.id }),
                       let strike = projectile.moraleStrike {
                        let point = bodyPoint(walkers[index])
                        if grapeshotHits[flight.volleyID, default: []].isEmpty {
                            let impactPoint: CGPoint
                            if let boundary = projectile.firingBoundary, let origin = projectile.firingOrigin {
                                impactPoint = boundary.clamped(point, from: origin)
                            } else { impactPoint = point }
                            artilleryImpacts.append(ArtilleryImpact(id: flight.volleyID,
                                position: impactPoint, radius: 24))
                        }
                        var walker = walkers[index]
                        applyMorale(strike, to: &walker, at: point)
                        walkers[index] = walker
                    }
                    grapeshotHits[flight.volleyID, default: []].insert(hit.id)
                    damageWalker(id: hit.id, damage: projectile.damage, slotIndex: projectile.slotIndex)
                } else if flight.remainingDistance > distance {
                    flight.remainingDistance -= distance
                    projectile.position = end
                    projectile.grapeshot = flight
                    survivors.append(projectile)
                }
                continue
            }
            let stepLength = projectile.speed * CGFloat(gameDt)
            let aim: CGPoint
            if let impact = projectile.impactPoint {
                aim = impact
            } else if let target = walkers.first(where: { $0.id == projectile.targetID }) {
                aim = bodyPoint(target)
            } else { continue }
            let dx = aim.x - projectile.position.x
            let dy = aim.y - projectile.position.y
            let distance = hypot(dx, dy)
            if distance <= Self.projectileHitRadiusInImagePixels || distance <= stepLength {
                applyImpact(projectile, at: aim)
                continue
            }
            projectile.heading = atan2(dy, dx)
            projectile.position.x += dx / distance * stepLength
            projectile.position.y += dy / distance * stepLength
            survivors.append(projectile)
        }
        projectiles = survivors
        let liveVolleys = Set(survivors.compactMap { $0.grapeshot?.volleyID })
        grapeshotHits = grapeshotHits.filter { liveVolleys.contains($0.key) }
    }

    private func damageWalker(id: Int, damage: Double, slotIndex: Int) {
        guard let index = walkers.firstIndex(where: { $0.id == id }) else { return }
        damageTotalBySlot[slotIndex, default: 0] += min(walkers[index].hp, damage)
        walkers[index].hp -= damage
        if walkers[index].hp <= 0 {
            money += walkers[index].bounty
            walkers.remove(at: index)
        }
    }

    private func distanceFrom(_ point: CGPoint, to walker: Walker) -> CGFloat {
        let bp = bodyPoint(walker)
        return hypot(bp.x - point.x, bp.y - point.y)
    }

    private func targetCandidates() -> [TargetCandidate] {
        walkers.map { walker in
            TargetCandidate(id: walker.id,
                            position: Point(Double(walker.position.x),
                                            Double(walker.position.y)),
                            pathIndex: walker.pathIndex,
                            pathDistance: walker.pathDistance,
                            hp: walker.hp,
                            morale: walker.morale.value,
                            isBroken: false)
        }
    }

    private func advanceArtilleryImpacts(seconds: Double) {
        guard seconds.isFinite, seconds > 0 else { return }
        artilleryImpacts = artilleryImpacts.compactMap { impact in
            var next = impact
            next.age += seconds
            return next.age < next.duration ? next : nil
        }
    }

    private func applyImpact(_ projectile: Projectile, at point: CGPoint, isDemolition: Bool = false) {
        if projectile.kind == .areaOfEffect {
            artilleryImpacts.append(ArtilleryImpact(id: projectile.id, position: point,
                                                  radius: max(24, projectile.splashRadius),
                                                  isDemolition: isDemolition))
        }
        var remaining: [Walker] = []
        for var walker in walkers {
            let isHit: Bool
            if projectile.kind == .areaOfEffect {
                isHit = distanceFrom(point, to: walker) <= projectile.splashRadius
            } else {
                isHit = walker.id == projectile.targetID
            }
            if isHit {
                if let strike = projectile.moraleStrike {
                    applyMorale(strike, to: &walker, at: point)
                }
                let dealt = min(walker.hp, projectile.damage)
                walker.hp -= projectile.damage
                damageTotalBySlot[projectile.slotIndex, default: 0] += dealt
                if walker.hp <= 0 {
                    money += walker.bounty
                    continue
                }
            }
            remaining.append(walker)
        }
        walkers = remaining
    }

    private func applyMorale(_ strike: ArtilleryMoraleStrike, to walker: inout Walker,
                             at point: CGPoint) {
        let loss = strike.loss(distance: Double(distanceFrom(point, to: walker)),
                               discipline: walker.discipline)
        walker.morale.apply(loss: loss, direction: walker.position.x < point.x ? -1 : 1)
    }
}

#if DEBUG
extension LevelRunner {
    struct CombatReviewFrame {
        let seconds: Double
        let walkers: [Walker]
        let militia: [MilitiaSoldier]
    }

    func verifyMoraleCombatOnDevice() throws -> (checks: [String: Any], frames: [CombatReviewFrame]) {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "MoraleCombatReview", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        try require(isReady, status)
        guard let redcoat = enemyTypesByID.values.first(where: { $0.id == Foe.redcoatRegular.id }),
              var melee = towerLevels[.melee]?[1]?[1]?.meleeUnit,
              let heroTemplate = heroPosts.first else {
            throw NSError(domain: "MoraleCombatReview", code: 2)
        }
        try require(enemyTypesByID.values.allSatisfy { $0.stats.moraleResponse == EnemyMoraleResponse() },
                    "Enemy threshold data did not reach the runner")
        let origin = Point(Double(playArea.midX), Double(playArea.midY))
        melee.hp = 1000
        func enemy(_ id: Int, at point: Point, morale: Double, fixedDamage: Double = 12) -> Walker {
            var w = Walker(id: id, assetName: "redcoat_regular", speed: redcoat.stats.speed,
                maxHP: 90, hp: 90, bounty: 0, damageMin: fixedDamage, damageMax: fixedDamage,
                cover: 0, blockImmune: false, spawnTick: 0, pathIndex: 0,
                discipline: redcoat.stats.discipline, moraleResponse: redcoat.stats.moraleResponse,
                position: CGPoint(x: point.x, y: point.y))
            w.morale.apply(loss: 100 - morale, direction: 1)
            return w
        }
        func garrison(at point: Point, state: MilitiaUnit.State, target: Int) -> MilitiaGarrison {
            var unit = MilitiaUnit(position: Point(point.x + 80, point.y), hp: 1000)
            unit.state = state; unit.targetSpawnID = target; unit.swingTicksLeft = 1000
            return MilitiaGarrison(rallyPoint: point, units: [unit], enemySwingTicks: [target: 1],
                                   stats: melee, anchor: point)
        }
        heroPosts = []; placedTowers = []; projectiles = []; artilleryImpacts = []
        var militiaDamage: [Double] = []
        for morale in [40.001, 40.0] {
            walkers = [enemy(0, at: origin, morale: morale)]
            garrisonsBySlot = [0: garrison(at: origin, state: .fighting, target: 0)]
            stepMilitiaTick()
            militiaDamage.append(1000 - garrisonsBySlot[0]!.units[0].hp)
            try require(walkers.count == 1 && walkers[0].hp > 0 && blockedWalkerIDs.contains(0),
                        "A living blocked enemy disappeared")
        }
        try require(abs(militiaDamage[0] - 12) < 1e-8 && abs(militiaDamage[1] - 8) < 1e-8,
                    "Morale did not reduce enemy damage to militia by one third")
        var heroDamage: [Double] = []
        for morale in [40.001, 40.0] {
            var post = heroTemplate
            let target = post.unit.position
            post.unit.state = .fighting; post.unit.targetSpawnID = 0
            post.unit.hp = 1000; post.unit.swingTicksLeft = 1000; post.enemySwingTicks = [0: 1]
            heroPosts = [post]
            walkers = [enemy(0, at: target, morale: morale)]
            garrisonsBySlot = [0: garrison(at: target, state: .holding, target: -1)]
            stepMilitiaTick()
            heroDamage.append(1000 - heroPosts[0].unit.hp)
            try require(garrisonsBySlot[0]!.units[0].targetSpawnID == -1,
                        "Militia claimed an enemy already fighting a hero")
        }
        try require(heroDamage[0] > 0 && abs(heroDamage[1] / heroDamage[0] - 2.0 / 3.0) < 1e-8,
                    "Morale did not reduce enemy damage to heroes by one third")

        heroPosts = []; garrisonsBySlot = [:]; walkers = []; blockedWalkerIDs = []

        for index in 0..<6 {
            let point = Point(origin.x + Double(index % 3 - 1) * 300,
                              origin.y + (index < 3 ? 95 : -95))
            walkers.append(enemy(index, at: point, morale: index < 3 ? 100 : 35, fixedDamage: 6))
            var g = garrison(at: point, state: .engaging, target: index)
            g.units[0].position = Point(point.x, point.y + Double(index % 3 - 1) * 12)
            g.units[0].swingTicksLeft = 0
            garrisonsBySlot[index] = g
        }
        var frames: [CombatReviewFrame] = []
        for tick in 0...60 {
            militiaPrevPositions = militiaPositionsById()
            stepMilitiaTick()
            updateMilitiaPoses()
            publishMilitia(alpha: 1)
            try require(walkers.count == 6 && walkers.allSatisfy { $0.hp > 0 },
                        "Living enemy vanished during melee")
            try require(blockedWalkerIDs.count == 6, "Melee enemy lost its blocking state")
            if [0, 12, 24, 36, 60].contains(tick) {
                frames.append(CombatReviewFrame(seconds: Double(tick) * SimClock.dt,
                                               walkers: walkers, militia: militia))
            }
        }
        for index in 0..<6 {
            let friendly = garrisonsBySlot[index]!.units[0].position
            try require(abs(friendly.x - walkers[index].position.x) >= 75,
                        "Combatants still overlap after taking their stance")
        }
        return (["enemyTypes": enemyTypesByID.count, "threshold": 0.4,
                 "speedMultiplier": 2.0 / 3.0, "attackMultiplier": 2.0 / 3.0,
                 "militiaDamageAboveAndAtThreshold": militiaDamage,
                 "heroDamageAboveAndAtThreshold": heroDamage,
                 "livingMeleeEnemies": walkers.count, "blockedMeleeEnemies": blockedWalkerIDs.count,
                 "militiaCannotClaimHeroOpponent": true, "meleeSpacing": MilitiaTunables.combatSpacing], frames)
    }

    func verifyDemolitionHapticsOnDevice() async throws -> [String: Any] {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "DemolitionHapticsReview", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        defer { stop() }
        try require(CHHapticEngine.capabilitiesForHardware().supportsHaptics,
                    "This device does not support Core Haptics")
        let slot = try prepareDemolitionReview(stage: "preparing")
        demolitionHapticStarts = 0
        start()
        stopSimulation()
        try require(!detonateDemolition(atSlot: slot) && demolitionHapticStarts == 0,
                    "A preparing charge played a haptic")
        advanceDemolitionCharges(seconds: 8)
        let hp = walkers.map(\.hp)
        try require(detonateDemolition(atSlot: slot), "Ready charge did not detonate")
        try require(demolitionHapticStarts == 1 && lastDemolitionHapticPlayback == .coreHaptics,
                    "Detonation did not start the custom Core Haptics pattern")
        try require(walkers.map(\.hp) != hp && artilleryImpacts.count == 1,
                    "Haptic was disconnected from the actual explosion")
        try require(!detonateDemolition(atSlot: slot) && demolitionHapticStarts == 1,
                    "A duplicate tap replayed the haptic")
        let blastPlayer = demolitionHapticPlayer
        try require(blastPlayer != nil, "Explosion has no dedicated haptic player")
        try await Task.sleep(for: .milliseconds(80))
        playEnemyEscapeHaptic(.lifeLoss)
        try await Task.sleep(for: .milliseconds(80))
        playEnemyEscapeHaptic(.defeat)
        try require(demolitionHapticPlayer === blastPlayer && activeHapticPlayer != nil,
                    "Escape feedback replaced the explosion player")
        try await Task.sleep(for: .milliseconds(100))
        try require(demolitionHapticCompleted == nil,
                    "Escape feedback stopped the explosion before its rumble finished")
        try await Task.sleep(for: .milliseconds(650))
        try require(demolitionHapticCompleted == true, "Core Haptics did not finish successfully")
        try require(hapticEngine?.isMutedForHaptics == false, "The game haptic engine is muted")

        advanceDemolitionCharges(seconds: 8)
        try require(detonateDemolition(atSlot: slot) && demolitionHapticStarts == 2,
                    "A later detonation failed to play")
        stop()
        try require(activeHapticPlayer == nil && demolitionHapticPlayer == nil
                    && hapticEngine == nil && !hapticsActive,
                    "Leaving the level did not release the haptic player")
        try require(playGameplayHaptic(.demolitionExplosion) == .inactive && activeHapticPlayer == nil,
                    "An inactive level started feedback")

        start()
        stopSimulation()
        try require(demolitionHapticStarts == 2, "Resume replayed a stale explosion")
        advanceDemolitionCharges(seconds: 8)
        try require(detonateDemolition(atSlot: slot) && demolitionHapticStarts == 3
                    && lastDemolitionHapticPlayback == .coreHaptics,
                    "Haptics failed after level resume")
        try await Task.sleep(for: .milliseconds(650))
        try require(demolitionHapticCompleted == true, "Resumed explosion did not finish")
        return ["hardwareSupportsHaptics": true, "playback": lastDemolitionHapticPlayback.rawValue,
                "durationSeconds": GameplayHapticPattern.demolitionExplosion.duration,
                "completedWithoutError": true, "successfulDetonations": demolitionHapticStarts,
                "preparingAndDoubleTapSilent": true, "stopsOnExit": true,
                "inactiveLevelSilent": true, "resumeWorksWithoutReplay": true,
                "escapeAndDefeatDoNotCancelExplosion": true, "engineMuted": false,
                "physicalSensation": "Requires user confirmation; API completion does not measure sensation"]
    }

    @discardableResult func prepareDemolitionAutomaticReview() throws -> Int {
        let slot = try prepareDemolitionReview(stage: "first-placement", includeEnemies: false)
        guard let tower = placedTower(atSlot: slot), let charge = tower.demolitionCharge,
              let position = charge.position, let tuning = towerLevel(for: tower) else {
            throw NSError(domain: "DemolitionAutoReview", code: 1)
        }
        for (pathIndex, path) in paths.enumerated() {
            let nearest = path.nearestDistance(to: Point(position.x, position.y))
            if let exit = stride(from: nearest, to: path.totalLength, by: 1).first(where: {
                charge.willEnemyExitBlast(on: path, from: $0, advancingBy: 2,
                    radius: tuning.aoeRadius, targetOffset: Self.enemyBodyOffset)
            }) {
                walkers = [18.0, 60.0, 90.0].enumerated().map { index, gap in
                    let distance = max(0, exit - gap)
                    let p = path.point(atDistance: distance)
                    return Walker(id: index, assetName: "redcoat_regular", speed: 60,
                        maxHP: 5000, hp: 5000, bounty: 5, damageMin: 4, damageMax: 7,
                        cover: 0, blockImmune: false, spawnTick: -10000, pathIndex: pathIndex,
                        position: CGPoint(x: p.x, y: p.y), pathDistance: distance)
                }
                blockedWalkerIDs = []
                start(); stopSimulation()
                return slot
            }
        }
        throw NSError(domain: "DemolitionAutoReview", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "No outgoing route boundary in fixture"])
    }

    func advanceDemolitionAutomaticReview(seconds: Double) {
        advanceArtilleryImpacts(seconds: seconds)
        advanceWalkers(seconds: seconds, nowTicks: Double(timer.tick) + seconds / SimClock.dt)
    }

    func verifyDemolitionAutomationOnDevice() throws -> [String: Any] {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "DemolitionAutoReview", code: 3,
                userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        let slot = try prepareDemolitionReview(stage: "first-placement", includeEnemies: false)
        let index = placedTowers.firstIndex { $0.slotIndex == slot }!
        let charge = placedTowers[index].demolitionCharge!
        let center = charge.position!
        let savedPaths = paths
        defer { paths = savedPaths; blockedWalkerIDs = []; isCleared = false; isDefeated = false }
        paths = [Path(points: [Point(center.x - 500, center.y + 12), Point(center.x + 500, center.y + 12)]),
                 Path(points: [Point(center.x - 500, center.y + 512), Point(center.x + 500, center.y + 512)])]
        func enemy(_ id: Int, distance: Double, lane: Int = 0, hp: Double = 5000, speed: Double = 60) -> Walker {
            let point = paths[lane].point(atDistance: distance)
            return Walker(id: id, assetName: "redcoat_regular", speed: speed, maxHP: hp, hp: hp,
                bounty: 5, damageMin: 4, damageMax: 7, cover: 0, blockImmune: false,
                spawnTick: -10000, pathIndex: lane, position: CGPoint(x: point.x, y: point.y),
                pathDistance: distance)
        }
        func move(_ seconds: Double) { advanceWalkers(seconds: seconds, nowTicks: 10000) }
        move(2)
        try require(artilleryImpacts.isEmpty, "Empty site detonated")
        walkers = [enemy(0, distance: 319)]
        move(1)
        try require(artilleryImpacts.isEmpty, "Charge fired at the incoming edge")
        walkers = [enemy(0, distance: 500)]
        move(1)
        try require(artilleryImpacts.isEmpty, "Charge fired at the center")
        walkers = [enemy(0, distance: 679)]
        blockedWalkerIDs = [0]
        move(0.5)
        try require(artilleryImpacts.isEmpty && walkers[0].pathDistance == 679, "Blocked enemy triggered a charge")
        blockedWalkerIDs = []
        move(0)
        try require(artilleryImpacts.isEmpty, "Paused frame fired")
        walkers = [enemy(0, distance: 679), enemy(1, distance: 500), enemy(2, distance: 679, lane: 1)]
        move(SimClock.dt)
        try require(artilleryImpacts.count == 1 && walkers[0].hp < 5000 && walkers[1].hp < 5000
            && walkers[2].hp == 5000 && !placedTowers[index].demolitionCharge!.isReady,
            "Outgoing enemy failed to trigger one blast before leaving damage range")
        let hitPoints = walkers.map(\.hp)
        move(SimClock.dt)
        try require(artilleryImpacts.count == 1 && walkers.map(\.hp) == hitPoints, "Cooling charge fired twice")
        walkers = []
        move(8)
        try require(placedTowers[index].demolitionCharge!.isReady, "Charge failed to rearm")
        walkers = [enemy(0, distance: 679, lane: 1)]
        move(SimClock.dt)
        try require(artilleryImpacts.count == 1, "Unrelated lane triggered charge")
        walkers = [enemy(0, distance: 679, hp: 0)]
        move(SimClock.dt)
        try require(artilleryImpacts.count == 1, "Dead enemy triggered charge")
        walkers = [enemy(0, distance: 679)]
        isCleared = true; move(SimClock.dt)
        isCleared = false; isDefeated = true; move(SimClock.dt)
        try require(artilleryImpacts.count == 1, "Ended match triggered charge")
        isDefeated = false
        move(SimClock.dt)
        try require(artilleryImpacts.count == 2, "Rearmed charge failed to fire automatically")
        placedTowers[index].demolitionCharge = charge
        artilleryImpacts = []
        walkers = [enemy(0, distance: 100, hp: 1, speed: 300)]
        let cash = money, livesBefore = lives
        move(3)
        try require(artilleryImpacts.count == 1 && walkers.isEmpty && money == cash + 5 && lives == livesBefore,
            "Long frame skipped the blast, revived a killed enemy, or duplicated its bounty")
        return ["waitsAtEntryAndCenter": true, "firesBeforeOutgoingEnemyLeaves": true,
                "blockedAndPausedStayArmed": true, "emptyDeadAndOtherLaneIgnored": true,
                "oneBlastPerCharge": true, "automaticRearm": true, "longFrameCrossing": true,
                "killedEnemyStaysDeadAndPaysOnce": true, "blockedAfterGameEnd": true]
    }

    @discardableResult func prepareTowerUpgradeReview(kind: TowerKind, atLevel: Int = 3) throws -> Int {
        guard isReady, let tuning = towerLevels[kind]?[atLevel]?[1],
              let slot = slotPositions.indices.sorted(by: {
                  hypot(slotPositions[$0].x - playArea.midX, slotPositions[$0].y - playArea.midY)
                    < hypot(slotPositions[$1].x - playArea.midX, slotPositions[$1].y - playArea.midY)
              }).first(where: {
                  tuning.attackRange.nearestPathPoint(to: slotPositions[$0], from: slotPositions[$0], paths: paths) != nil
              }) else {
            throw NSError(domain: "TowerUpgradeReview", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No valid upgrade fixture: \(status)"])
        }
        stop()
        placedTowers = []; walkers = []; projectiles = []; artilleryImpacts = []
        rallyFlagFlash = nil; grapeshotHits = [:]
        nextFireTickBySlot = [:]; damageTotalBySlot = [:]
        money = 10_000; towerUnlocks[kind] = 4
        awaitingWaveStart = false; isCleared = false; isDefeated = false
        dismissMenu()
        selectSlot(slot); tapBuildButton(kind); tapBuildButton(kind)
        for _ in 1..<atLevel {
            selectPlacedTower(atSlot: slot)
            tapUpgradeButton(branch: 1); tapUpgradeButton(branch: 1)
        }
        selectPlacedTower(atSlot: slot)
        return slot
    }

    func verifyEngineerObstaclesOnDevice() throws -> [String: Any] {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "EngineerReview", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        let slot = try prepareTowerUpgradeReview(kind: .special, atLevel: 1)
        guard let site = placedTower(atSlot: slot)?.engineerObstaclePosition else {
            throw NSError(domain: "EngineerReview", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "No initial obstacle field"])
        }
        let savedPaths = paths
        defer { paths = savedPaths; blockedWalkerIDs = []; walkers = [] }
        paths = [Path(points: [Point(site.x - 500, site.y), Point(site.x + 1000, site.y)]),
                 Path(points: [Point(site.x - 500, site.y + 300), Point(site.x + 1000, site.y + 300)])]
        func enemy(_ id: Int, lane: Int = 0) -> Walker {
            let point = paths[lane].point(atDistance: 500)
            return Walker(id: id, assetName: "redcoat_regular", speed: 60, maxHP: 100, hp: 100,
                bounty: 5, damageMin: 4, damageMax: 7, cover: 0, blockImmune: false,
                spawnTick: -10000, pathIndex: lane, position: CGPoint(x: point.x, y: point.y), pathDistance: 500)
        }
        var travelByLevel: [Double] = []
        for tier in 1...3 {
            if tier > 1 {
                let before = money
                if selectedTowerSlotIndex != slot { selectPlacedTower(atSlot: slot) }
                tapUpgradeButton(branch: 1); tapUpgradeButton(branch: 1)
                try require(before - money == towerLevels[.special]?[tier]?[1]?.cost, "Incorrect upgrade cost")
            }
            try require(placedTower(atSlot: slot)?.level == tier
                && placedTower(atSlot: slot)?.engineerObstaclePosition == site, "Upgrade lost its field")
            walkers = [enemy(0), enemy(1, lane: 1)]
            advanceWalkers(seconds: 0.25, nowTicks: 10000)
            let travel = walkers[0].pathDistance - 500
            travelByLevel.append(travel)
            try require(abs(travel - 15 * (1 - Double(tier + 1) / 10)) < 0.001,
                        "Wrong tier \(tier) slowdown")
            try require(abs(walkers[1].pathDistance - 515) < 0.001, "Slowed an unrelated lane")
            updateCombat(gameDt: 0.25)
            try require(projectiles.isEmpty && walkers.allSatisfy { $0.hp == 100 && $0.morale.value == 100 },
                        "Engineers dealt direct damage")
        }
        let beforePause = walkers[0].pathDistance
        advanceWalkers(seconds: 0, nowTicks: 10000)
        try require(walkers[0].pathDistance == beforePause, "Pause moved an enemy")
        blockedWalkerIDs = [0]
        advanceWalkers(seconds: 0.25, nowTicks: 10000)
        try require(walkers[0].pathDistance == beforePause, "Obstacles overrode melee blocking")
        blockedWalkerIDs = []
        selectPlacedTower(atSlot: slot); beginEngineerObstaclePlacement()
        placeEngineerObstacles(at: CGPoint(x: -99999, y: -99999))
        try require(placedTower(atSlot: slot)?.engineerObstaclePosition == site
            && !isPlacingEngineerObstacles, "Invalid placement moved the field")
        selectPlacedTower(atSlot: slot); beginEngineerObstaclePlacement()
        placeEngineerObstacles(at: CGPoint(x: site.x + 30, y: site.y))
        try require(placedTower(atSlot: slot)?.engineerObstaclePosition == CGPoint(x: site.x + 30, y: site.y),
                    "Placement control failed to move obstacles")
        selectPlacedTower(atSlot: slot); tapUpgradeButton(branch: 3); tapUpgradeButton(branch: 3)
        try require(engineerObstacleFields.isEmpty
            && placedTower(atSlot: slot)?.demolitionCharge?.isReadyForPlacement == true,
                    "Demolition upgrade retained obstacles or auto-placed its charge")
        return ["passed": true, "distanceInQuarterSecondByLevel": travelByLevel,
                "unaffectedLaneDistance": 15, "upgradeAndPlacement": true,
                "pauseAndMeleeBlocking": true, "demolitionTransition": true]
    }

    @discardableResult func prepareEngineerObstacleReview(level: Int) throws -> Int {
        let slot = try prepareTowerUpgradeReview(kind: .special, atLevel: level)
        guard let site = placedTower(atSlot: slot)?.engineerObstaclePosition else { return slot }
        let target = Point(site.x, site.y)
        if let lane = paths.indices.min(by: {
            paths[$0].point(atDistance: paths[$0].nearestDistance(to: target)).distance(to: target)
                < paths[$1].point(atDistance: paths[$1].nearestDistance(to: target)).distance(to: target)
        }) {
            let center = paths[lane].nearestDistance(to: target)
            walkers = [-65.0, 0, 65].enumerated().map { index, offset in
                let distance = max(0, center + offset)
                let point = paths[lane].point(atDistance: distance)
                return Walker(id: index, assetName: "redcoat_regular", speed: 60, maxHP: 100, hp: 100,
                    bounty: 5, damageMin: 4, damageMax: 7, cover: 0, blockImmune: false,
                    spawnTick: -10000, pathIndex: lane,
                    position: CGPoint(x: point.x, y: point.y), pathDistance: distance)
            }
        }
        dismissMenu()
        return slot
    }

    func advanceEngineerObstacleReview(seconds: Double) {
        advanceWalkers(seconds: seconds, nowTicks: 10000)
    }

    @discardableResult func prepareDemolitionReview(stage: String, includeEnemies: Bool = true) throws -> Int {
        let slot = try prepareTowerUpgradeReview(kind: .special)
        guard let tuning = towerLevels[.special]?[4]?[3] else {
            throw NSError(domain: "DemolitionReview", code: 1)
        }
        if stage == "upgrade" { return slot }
        tapUpgradeButton(branch: 3); tapUpgradeButton(branch: 3)
        if stage == "unplaced" { return slot }
        if stage == "unplaced-menu" || stage == "unplaced-placement" {
            selectPlacedTower(atSlot: slot)
            if stage == "unplaced-placement" { beginDemolitionPlacement() }
            return slot
        }
        guard let tower = placedTower(atSlot: slot),
              let point = tuning.attackRange.nearestPathPoint(to: tower.position, from: tower.position, paths: paths) else {
            throw NSError(domain: "DemolitionReview", code: 2)
        }
        selectPlacedTower(atSlot: slot); beginDemolitionPlacement()
        placeDemolition(at: point)
        if stage != "first-placement" { rallyFlagFlash = nil }
        guard let charge = placedTower(atSlot: slot)?.demolitionCharge, let chargePosition = charge.position else {
            throw NSError(domain: "DemolitionReview", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Manual placement did not plant the charge"])
        }
        if stage == "preparing" {
            detonateDemolition(atSlot: slot)
            artilleryImpacts = []
            advanceDemolitionCharges(seconds: 3)
        }
        for i in 0..<(includeEnemies ? 6 : 0) {
            walkers.append(Walker(id: i, assetName: "redcoat_regular", speed: 60,
                maxHP: 180, hp: 180, bounty: 5, damageMin: 4, damageMax: 7,
                cover: 0, blockImmune: false, spawnTick: 0, pathIndex: 0, discipline: 0.6,
                position: CGPoint(x: chargePosition.x + Double(i % 3 - 1) * 65,
                                  y: chargePosition.y + Double(i / 3) * 65 + 12)))
        }
        if stage == "preparing" { return slot }
        advanceDemolitionCharges(seconds: 8)
        if stage == "blast" || stage == "after" {
            detonateDemolition(atSlot: slot)
            artilleryImpacts = artilleryImpacts.map { impact in
                var result = impact; result.age = 0.18; return result
            }
            if stage == "after" { artilleryImpacts = [] }
        }
        if stage == "menu" { selectPlacedTower(atSlot: slot) }
        if stage == "placement" || stage == "relocated" {
            selectPlacedTower(atSlot: slot); beginDemolitionPlacement()
            if stage == "relocated", let tower = placedTower(atSlot: slot) {
                placeDemolition(at: CGPoint(x: tower.position.x + tuning.range * 0.8, y: tower.position.y))
            }
        }
        return slot
    }

    func advanceDemolitionReadinessReview(seconds: Double) {
        advanceDemolitionCharges(seconds: seconds)
        advanceArtilleryImpacts(seconds: seconds)
    }

    @discardableResult func prepareExplosionReview(ended: Bool = false) throws -> Int {
        let slot = try prepareDemolitionReview(stage: "ready")
        guard let tower = placedTower(atSlot: slot), let tuning = towerLevel(for: tower) else {
            throw NSError(domain: "DemolitionReview", code: 8)
        }
        selectPlacedTower(atSlot: slot); beginDemolitionPlacement()
        placeDemolition(at: CGPoint(x: tower.position.x - tuning.range * 0.65,
                                    y: tower.position.y - tuning.range * 0.2))
        advanceDemolitionCharges(seconds: 8)
        guard let position = placedTower(atSlot: slot)?.demolitionCharge?.position else {
            throw NSError(domain: "DemolitionReview", code: 9)
        }
        for index in walkers.indices {
            walkers[index].position = CGPoint(x: position.x + Double(index % 3 - 1) * 65,
                                              y: position.y + Double(index / 3) * 65 + 12)
        }
        guard detonateDemolition(atSlot: slot) else {
            throw NSError(domain: "DemolitionReview", code: 10)
        }
        if ended { isCleared = true }
        return slot
    }

    func advanceExplosionReview(seconds: Double) {
        advanceArtilleryImpacts(seconds: seconds)
        for index in walkers.indices {
            _ = walkers[index].morale.advance(seconds: seconds, baseSpeed: 0,
                response: walkers[index].moraleResponse, blocked: true)
        }
    }

    func verifyDemolitionOnDevice() throws -> [String: Any] {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "DemolitionReview", code: 3,
                                          userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        let slot = try prepareDemolitionReview(stage: "upgrade")
        try require(upgradeOffers.map(\.branch) == [2, 3], "Expected support upgrade branches 2 and 3")
        let before = money
        tapUpgradeButton(branch: 3)
        try require(placedTower(atSlot: slot)?.level == 3, "Preview spent money or upgraded")
        tapUpgradeButton(branch: 3)
        guard let tower = placedTower(atSlot: slot), let tuning = towerLevel(for: tower),
              let initialCharge = tower.demolitionCharge else {
            throw NSError(domain: "DemolitionReview", code: 4)
        }
        try require(tower.kind == .special && tower.level == 4 && tower.branch == 3 && before - money == tuning.cost,
                    "Wrong upgrade or charge cost")
        try require(initialCharge.isReadyForPlacement && initialCharge.position == nil
                    && initialCharge.remainingSeconds == 0, "First charge was delayed or automatically placed")
        try require(!detonateDemolition(atSlot: slot), "Unplaced charge detonated")
        advanceDemolitionCharges(seconds: 100)
        try require(placedTower(atSlot: slot)?.demolitionCharge?.isReadyForPlacement == true,
                    "Elapsed time automatically placed the initial charge")
        selectPlacedTower(atSlot: slot); beginDemolitionPlacement()
        placeDemolition(at: CGPoint(x: tower.position.x + tuning.range + 1, y: tower.position.y))
        try require(placedTower(atSlot: slot)?.demolitionCharge?.isReadyForPlacement == true
                    && !isPlacingDemolition, "Cancelled first placement consumed the ready charge")
        selectPlacedTower(atSlot: slot); beginDemolitionPlacement()
        placeDemolition(at: tower.position)
        guard let charge = placedTower(atSlot: slot)?.demolitionCharge, let position = charge.position else {
            throw NSError(domain: "DemolitionReview", code: 4)
        }
        try require(charge.isReady && charge.remainingSeconds == 0 && !charge.isReadyForPlacement,
                    "First placement started an unnecessary cooldown")
        try require(rallyFlagFlash == nil, "Placement marker covered the armed first charge")
        func enemy(_ id: Int, offset: Double, hp: Double = 1000) -> Walker {
            Walker(id: id, assetName: "redcoat_regular", speed: 60, maxHP: hp, hp: hp,
                bounty: 5, damageMin: 4, damageMax: 7, cover: 0, blockImmune: false,
                spawnTick: 0, pathIndex: 0, discipline: 0.6,
                position: CGPoint(x: position.x + offset, y: position.y + 12))
        }
        walkers = [enemy(0, offset: 0), enemy(1, offset: tuning.aoeRadius - 1),
                   enemy(2, offset: tuning.aoeRadius + 1), enemy(3, offset: 20, hp: 1)]
        updateCombat(gameDt: 3)
        try require(projectiles.isEmpty && artilleryImpacts.isEmpty && walkers.allSatisfy { $0.hp == $0.maxHP },
                    "Charge incorrectly used ordinary ranged targeting")
        let cash = money
        try require(detonateDemolition(atSlot: slot), "Armed charge did not detonate")
        let center = walkers.first { $0.id == 0 }!
        let edge = walkers.first { $0.id == 1 }!
        let outside = walkers.first { $0.id == 2 }!
        try require(center.hp < 1000 && center.morale.value < 100 && edge.hp < 1000,
                    "Blast failed HP or morale damage inside its radius")
        try require(outside.hp == 1000 && outside.morale.value == 100,
                    "Blast damaged enemy beyond its independent radius")
        try require(!walkers.contains { $0.id == 3 } && money == cash + 5,
                    "Blast kill did not pay its bounty exactly once")
        try require(artilleryImpacts.count == 1 && artilleryImpacts[0].isDemolition,
                    "Missing demolition effect")
        try require(!detonateDemolition(atSlot: slot) && artilleryImpacts.count == 1,
                    "Consumed charge detonated twice")
        let hitPointsAfterBlast = walkers.map(\.hp)
        advanceArtilleryImpacts(seconds: 0.8)
        try require(artilleryImpacts.count == 1,
                    "Demolition smoke was removed at the ordinary artillery lifetime")
        advanceArtilleryImpacts(seconds: DemolitionExplosion.duration - 0.8 + 0.001)
        try require(artilleryImpacts.isEmpty && walkers.map(\.hp) == hitPointsAfterBlast && money == cash + 5,
                    "Explosion failed to expire or applied damage/rewards during animation")
        try require(placedTower(atSlot: slot)?.demolitionCharge?.remainingSeconds == 8,
                    "Next charge did not restart preparation")
        advanceDemolitionCharges(seconds: 8)
        selectPlacedTower(atSlot: slot); beginDemolitionPlacement()
        placeDemolition(at: CGPoint(x: tower.position.x + tuning.range + 1, y: tower.position.y))
        try require(!isPlacingDemolition && selectedTowerSlotIndex == nil
                    && placedTower(atSlot: slot)?.demolitionCharge?.position == charge.position,
                    "Outside tap did not cancel placement without moving the charge")
        selectPlacedTower(atSlot: slot); beginDemolitionPlacement()
        let requested = CGPoint(x: tower.position.x + tuning.range * 0.8, y: tower.position.y)
        placeDemolition(at: requested)
        guard let moved = placedTower(atSlot: slot)?.demolitionCharge, let movedPosition = moved.position else {
            throw NSError(domain: "DemolitionReview", code: 5)
        }
        try require(!isPlacingDemolition && tuning.attackRange.contains(movedPosition, from: tower.position),
                    "Placement escaped the displayed range")
        try require(rallyFlagFlash?.position == moved.position,
                    "Charge placement did not show its destination flag")
        try require(moved.position == charge.position || moved.remainingSeconds == 8,
                    "Relocation kept a ready charge")
        advanceDemolitionCharges(seconds: 8)
        isCleared = true
        try require(!detonateDemolition(atSlot: slot), "Charge fired after victory")
        isCleared = false; isDefeated = true
        try require(!detonateDemolition(atSlot: slot), "Charge fired after defeat")
        isDefeated = false
        return ["family": "Engineers", "branches": [2, 3], "preparationSeconds": 8, "upgradeCost": tuning.cost,
                "initialChargeReadyAndUnplaced": true, "firstPlacementImmediatelyArmed": true,
                "unplacedChargeCannotDetonate": true, "cancelledFirstPlacementKeepsReadyCharge": true,
                "placementRange": tuning.range, "blastRadius": tuning.aoeRadius,
                "usesSeparateTrigger": true, "duplicateDetonationProtected": true, "hpAndMoraleDamage": true,
                "bountyOnce": true, "placementUsesDisplayedRange": true,
                "outsideTapCancelsPlacement": true, "destinationFlagShown": true,
                "relocationRestartsPreparation": true, "blockedAfterGameEnd": true,
                "explosionExpires": true, "animationNeverRepeatsDamage": true]
    }

    func verifySiegeOnDevice() throws -> [String: Any] {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "SiegeReview", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        let slot = try prepareTowerUpgradeReview(kind: .areaOfEffect)
        tapUpgradeButton(branch: 4); tapUpgradeButton(branch: 4)
        guard let tower = placedTower(atSlot: slot), let tuning = towerLevel(for: tower) else {
            throw NSError(domain: "SiegeReview", code: 2)
        }
        try require(tower.demolitionCharge == nil && tuning.demolitionPreparationSeconds == nil,
                    "Siege inherited a demolition charge")
        let origin = tower.position
        func enemy(_ id: Int, x: Double, y: Double = 0, hp: Double = 1000,
                   discipline: Double = 0.6) -> Walker {
            Walker(id: id, assetName: "redcoat_regular", speed: 60, maxHP: hp, hp: hp,
                bounty: 5, damageMin: 4, damageMax: 7, cover: 0, blockImmune: false,
                spawnTick: 0, pathIndex: 0, discipline: discipline,
                position: CGPoint(x: origin.x + x, y: origin.y + y + 12),
                pathDistance: Double(100 - id))
        }
        placedTowers[0].artilleryAim = ArtilleryAim(heading: 0)
        walkers = [enemy(0, x: 60, hp: 1), enemy(1, x: 140),
                   enemy(2, x: 220, discipline: 1), enemy(3, x: 140, y: 60),
                   enemy(4, x: tuning.range + 1)]
        let cash = money
        updateCombat(gameDt: 0.00001)
        try require(projectiles.count == 1 && projectiles[0].solidShot != nil
                    && projectiles[0].impactPoint == nil, "Siege did not launch one solid shot")
        let shotDamage = projectiles[0].damage
        let heading = projectiles[0].heading
        updateCombat(gameDt: 0.00001)
        try require(projectiles.count == 1, "Siege ignored its reload interval")
        updateProjectiles(gameDt: 0.13)
        try require(!walkers.contains(where: { $0.id == 0 }) && money == cash + 5,
                    "First penetration failed to kill or pay its bounty once")
        try require(projectiles.count == 1, "Solid shot stopped when its target died")
        for _ in 0..<30 { updateProjectiles(gameDt: 0.01) }
        let middle = walkers.first { $0.id == 1 }!
        let disciplined = walkers.first { $0.id == 2 }!
        try require(abs(middle.hp - (1000 - shotDamage)) < 0.001
                    && abs(disciplined.hp - (1000 - shotDamage)) < 0.001,
                    "Shot failed to pierce multiple enemies or dealt repeated frame damage")
        try require(abs(middle.morale.value - (100 - tuning.terrorMax * 0.4)) < 0.001
                    && disciplined.morale.value == 100,
                    "Solid shot morale shock or discipline immunity failed")
        try require(projectiles.count == 1 && projectiles[0].heading == heading,
                    "Solid shot changed its launch bearing")
        updateProjectiles(gameDt: 10)
        try require(projectiles.isEmpty && artilleryImpacts.isEmpty,
                    "Solid shot travelled beyond its range or exploded like a shell")
        try require(walkers.filter { $0.id >= 3 }.allSatisfy { $0.hp == 1000 && $0.morale.value == 100 }
                    && money == cash + 5, "Shot damaged an off-line/out-of-range enemy or duplicated bounty")
        try require(abs(damageTotalBySlot[slot, default: 0] - (1 + 2 * shotDamage)) < 0.001,
                    "Penetration damage was attributed incorrectly")

        walkers = [enemy(0, x: 80)]
        placedTowers[0].artilleryAim = ArtilleryAim(heading: 0)
        nextFireTickBySlot = [:]
        updateCombat(gameDt: 0.00001)
        walkers[0].position.y += 90
        walkers.append(enemy(5, x: 130)); walkers.append(enemy(6, x: 260))
        updateProjectiles(gameDt: 10)
        try require(walkers[0].hp == 1000 && walkers.dropFirst().allSatisfy { $0.hp < 1000 }
                    && projectiles.isEmpty, "Shot homed or skipped enemies during a long frame")
        return ["level": 4, "branch": 4, "solidShot": true, "penetratesMultipleEnemies": true,
                "oneHitPerEnemy": true, "continuesAfterTargetDeath": true, "fixedBearing": true,
                "rangeLimited": true, "noSplashDamage": true, "bountyOnce": true,
                "reloadRespected": true, "moraleShockAndDisciplineVerified": true,
                "longFrameCollision": true, "damageAttributed": true]
    }

    func verifyArtilleryRangeOnDevice() throws -> [[String: Any]] {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "ArtilleryRangeReview", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        try require(isReady, status)
        let origin = CGPoint(x: playArea.midX, y: playArea.midY)
        func enemy(_ id: Int, at point: CGPoint) -> Walker {
            Walker(id: id, assetName: "redcoat_regular", speed: 60, maxHP: 1000, hp: 1000,
                bounty: 0, damageMin: 4, damageMax: 7, cover: 0, blockImmune: false,
                spawnTick: 0, pathIndex: 0, discipline: 0.6, position: point)
        }
        guard let levels = towerLevels[.areaOfEffect] else {
            throw NSError(domain: "ArtilleryRangeReview", code: 2)
        }
        var checks: [[String: Any]] = []
        defer {
            placedTowers = []
            walkers = []
            projectiles = []
            artilleryImpacts = []
            nextFireTickBySlot = [:]
            grapeshotHits = [:]
        }
        for level in levels.keys.sorted() {
            for branch in levels[level]!.keys.sorted() {
                let tuning = levels[level]![branch]!
                guard tuning.demolitionPreparationSeconds == nil else { continue }
                let swivel = ArtilleryHandling.isSwivel(level: level, branch: branch)
                let tower = PlacedTower(slotIndex: 0, kind: .areaOfEffect,
                                        position: origin, level: level, branch: branch)
                let overlayRadius = try { () throws -> CGFloat in
                    guard let radius = rangeOverlayRadius(for: tower) else {
                        throw NSError(domain: "ArtilleryRangeReview", code: 3)
                    }
                    return radius
                }()
                let ring = TowerRangeOverlay.size(range: overlayRadius, runtimeCanvas: runtimeCanvas)
                let rx = ring.width / (2 * runtimeCanvas.scaleFactor)
                let ry = ring.height / (2 * runtimeCanvas.scaleFactor)
                func insideRing(_ point: CGPoint) -> Bool {
                    pow((point.x - origin.x) / rx, 2) + pow((point.y - origin.y) / ry, 2) <= 1 + 1e-9
                }
                func prepareShot(at point: CGPoint) {
                    walkers = [enemy(0, at: point)]
                    var aimed = tower
                    let target = tuning.attackRange.clamped(bodyPoint(walkers[0]), from: origin)
                    aimed.artilleryAim = ArtilleryAim(heading: atan2(target.y - origin.y, target.x - origin.x))
                    placedTowers = [aimed]
                    projectiles = []
                    artilleryImpacts = []
                    grapeshotHits = [:]
                    nextFireTickBySlot = [:]
                }

                for degrees in stride(from: 0, to: 360, by: 15) {
                    let angle = Double(degrees) * .pi / 180
                    for factor in [0.999, 1.001] {
                        prepareShot(at: CGPoint(x: origin.x + cos(angle) * rx * factor,
                                                y: origin.y + sin(angle) * ry * factor))
                        updateCombat(gameDt: 0.00001)
                        try require(projectiles.count == (factor < 1 ? (swivel ? 5 : 1) : 0),
                                    "Wrong firing boundary at \(level)/\(branch), \(degrees) degrees, \(factor)")
                        for shot in projectiles {
                            try require(insideRing(shot.position), "Projectile escaped the ring")
                            if let aim = shot.impactPoint {
                                try require(insideRing(aim), "Shell aim escaped the ring")
                            }
                        }
                        updateProjectiles(gameDt: 10)
                        try require(artilleryImpacts.allSatisfy { insideRing($0.position) },
                                    "Impact body offset escaped the ring at \(level)/\(branch), \(degrees) degrees")
                    }
                }
                prepareShot(at: CGPoint(x: origin.x + rx * 0.98, y: origin.y + 12))
                updateCombat(gameDt: 0.00001)
                try require(!projectiles.isEmpty, "Missing moving-target test shot")
                if swivel || ArtilleryHandling.isSiege(level: level, branch: branch) {

                    walkers = [enemy(1, at: CGPoint(x: origin.x + rx + 1, y: origin.y + 12))]
                    for _ in 0..<200 {
                        updateProjectiles(gameDt: 0.01)
                        try require(projectiles.allSatisfy { insideRing($0.position) },
                                    "Swivel pellet travelled outside its range")
                    }
                    try require(projectiles.isEmpty && walkers[0].hp == 1000,
                                "Swivel hit an enemy outside its range")
                } else {
                    let aim = projectiles[0].impactPoint!

                    walkers[0].position = CGPoint(x: origin.x + rx * 4, y: origin.y)
                    let splashOnly = CGPoint(x: aim.x + tuning.aoeRadius / 2, y: aim.y + 12)
                    try require(!insideRing(splashOnly), "Invalid splash-only test fixture")
                    walkers.append(enemy(1, at: splashOnly))
                    walkers.append(enemy(2, at: CGPoint(x: aim.x + tuning.aoeRadius + 1, y: aim.y + 12)))
                    updateProjectiles(gameDt: 10)
                    try require(projectiles.isEmpty && artilleryImpacts.count == 1,
                                "Shell failed to land after its target left range")
                    try require(artilleryImpacts[0].position == aim && insideRing(aim),
                                "Shell chased the target beyond its launch-time aim")
                    try require(walkers[0].hp == 1000 && walkers[1].hp < 1000
                                && walkers[1].morale.value < 100 && walkers[2].hp == 1000,
                                "Blast radius was tied to firing range")
                    prepareShot(at: CGPoint(x: origin.x + rx / 2, y: origin.y))
                    updateCombat(gameDt: 0.00001)
                    walkers = []
                    updateCombat(gameDt: 10)
                    try require(artilleryImpacts.count == 1, "Shell vanished when its target died")
                }
                checks.append(["level": level, "branch": branch, "range": tuning.range,
                    "aoeRadius": tuning.aoeRadius, "overlayWidth": ring.width, "overlayHeight": ring.height,
                    "boundaryCases": 48, "projectilesStayInRange": true,
                    "blastIndependentOfRange": true, "swivel": swivel])
            }
        }
        try require(checks.count == 6, "Expected six automatic artillery tiers/branches")
        return checks
    }

    func verifyArtilleryMoraleOnDevice() throws -> (walkers: [Walker], checks: [[String: Any]]) {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "ArtilleryMoraleReview", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        try require(isReady, status)
        let center = CGPoint(x: playArea.midX, y: playArea.midY)
        func enemy(_ id: Int, x: Double, y: Double = 0, discipline: Double = 0.6) -> Walker {
            Walker(id: id, assetName: "redcoat_regular", speed: 60, maxHP: 1000, hp: 1000,
                bounty: 0, damageMin: 4, damageMax: 7, cover: 0, blockImmune: false,
                spawnTick: 0, pathIndex: 0, discipline: discipline,
                position: CGPoint(x: center.x + x, y: center.y + y + 12))
        }
        var checks: [[String: Any]] = []
        placedTowers = []
        guard let levels = towerLevels[.areaOfEffect] else {
            throw NSError(domain: "ArtilleryMoraleReview", code: 2)
        }
        for level in levels.keys.sorted() {
            for branch in levels[level]!.keys.sorted() {
                let tuning = levels[level]![branch]!
                guard tuning.demolitionPreparationSeconds == nil else { continue }
                if ArtilleryHandling.isSiege(level: level, branch: branch) {
                    let result = try verifySiegeOnDevice()
                    checks.append(result)
                    placedTowers = []
                    continue
                }
                try require(tuning.terrorMax > tuning.terrorMin && tuning.terrorMin > 0,
                            "Missing artillery morale tuning at \(level)/\(branch)")
                walkers = [enemy(0, x: 0), enemy(1, x: 40, y: 25),
                           enemy(2, x: max(100, tuning.aoeRadius + 1)),
                           enemy(3, x: 20, discipline: 1),
                           enemy(4, x: max(100, tuning.aoeRadius * 0.9)),
                           enemy(5, x: max(100, tuning.aoeRadius - 0.01))]
                artilleryImpacts = []
                let shot = Projectile(id: 0, kind: .areaOfEffect,
                    position: CGPoint(x: center.x - 10, y: center.y), heading: 0,
                    damage: 12, targetID: 0, slotIndex: 0, speed: 640,
                    splashRadius: CGFloat(tuning.aoeRadius),
                    moraleStrike: ArtilleryMoraleStrike(tuning: tuning))
                if ArtilleryHandling.isSwivel(level: level, branch: branch) {
                    grapeshotHits = [:]
                    projectiles = (0..<3).map { index in
                        var pellet = shot
                        pellet = Projectile(id: index, kind: pellet.kind, position: pellet.position,
                            heading: 0, damage: pellet.damage, targetID: 0, slotIndex: 0,
                            speed: pellet.speed, splashRadius: 0, moraleStrike: pellet.moraleStrike,
                            grapeshot: GrapeshotFlight(volleyID: 0, range: 100))
                        return pellet
                    }
                    updateCombat(gameDt: 0.03)
                    try require(abs(walkers[0].morale.value - (100 - tuning.terrorMax * 0.4)) < 0.001,
                                "Grapeshot must not stack morale loss per pellet")
                    try require(walkers[1].morale.value == 100, "Grapeshot shocked an unhit neighbor")
                } else {
                    applyImpact(shot, at: center)
                    try require(walkers[1].morale.value < 100, "Shell missed the nearby morale target")
                    try require(walkers[4].hp < walkers[4].maxHP && walkers[4].morale.value < 100,
                                "Shell missed HP or morale damage in the outer blast area")
                    try require(walkers[5].hp < walkers[5].maxHP && walkers[5].morale.value < 100,
                                "Shell missed HP or morale damage just inside the blast boundary")
                }
                try require(walkers[0].morale.isVisible, "Direct artillery hit did not reveal morale")
                try require(walkers[2].morale.value == 100, "Morale loss outside impact radius")
                try require(walkers[2].hp == walkers[2].maxHP, "HP damage outside impact radius")
                try require(walkers[3].morale.value == 100, "Discipline immunity ignored")
                try require(artilleryImpacts.count == 1, "Expected one shared impact effect")
                checks.append(["level": level, "branch": branch,
                    "aoeRadius": tuning.aoeRadius, "outerProbeDistance": max(100, tuning.aoeRadius * 0.9),
                    "hp": walkers.map { $0.hp },
                    "morale": walkers.map { $0.morale.value }, "impactCount": artilleryImpacts.count])
            }
        }
        try require(checks.count == 6, "Expected six automatic artillery tiers/branches")
        let tuning = levels[1]![1]!
        var display: [Walker] = []
        for count in 0..<7 {
            walkers = [enemy(count, x: 0)]
            let shot = Projectile(id: count, kind: .areaOfEffect, position: center, heading: 0,
                damage: 12, targetID: count, slotIndex: 0, speed: 320,
                splashRadius: CGFloat(tuning.aoeRadius), moraleStrike: ArtilleryMoraleStrike(tuning: tuning))
            for _ in 0..<count { applyImpact(shot, at: center) }
            walkers[0].morale.advance(seconds: 0.8)
            try require(abs(walkers[0].morale.displayedFraction - walkers[0].morale.value / 100) < 0.001,
                        "Level 1 displayed morale must settle at its remaining value")
            display.append(walkers[0])
        }
        return (display, checks)
    }

    func applyLevelOneReviewImpact(to targets: [Walker]) throws -> [Walker] {
        guard let tuning = towerLevels[.areaOfEffect]?[1]?[1] else {
            throw NSError(domain: "ArtilleryMoraleReview", code: 3)
        }
        let center = CGPoint(x: playArea.midX, y: playArea.midY)
        walkers = targets
        let shot = Projectile(id: 100, kind: .areaOfEffect, position: center, heading: 0,
            damage: 12, targetID: targets.first?.id ?? 0, slotIndex: 0, speed: 320,
            splashRadius: CGFloat(tuning.aoeRadius), moraleStrike: ArtilleryMoraleStrike(tuning: tuning))
        applyImpact(shot, at: center)
        return walkers
    }
}
#endif
