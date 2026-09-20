import Foundation
import CoreGraphics
import Combine

struct PlacedTower: Identifiable {
    let slotIndex: Int
    let kind: TowerKind
    let position: CGPoint
    var level: Int = 1
    var branch: Int = 1
    var upgrades = TowerUpgradeProgress()
    var preparedVolley: PreparedMetaVolley?
    var artilleryAim: ArtilleryAim
    var artilleryFacing: ArtilleryFacing { artilleryAim.facing }
    var demolitionCharge: DemolitionCharge?
    var engineerObstaclePosition: CGPoint?

    init(combatRules: CombatRules, slotIndex: Int, kind: TowerKind, position: CGPoint,
         level: Int = 1, branch: Int = 1) {
        self.slotIndex = slotIndex
        self.kind = kind
        self.position = position
        self.level = level
        self.branch = branch
        self.artilleryAim = ArtilleryAim(heading: combatRules.initialHeading,
                                         firingTolerance: combatRules.firingTolerance)
    }

    var id: Int { slotIndex }
}

@MainActor
public class BattleEngine: NSObject, ObservableObject {
    static let normalTickDuration: Duration = .seconds(1) / SimClock.ticksPerSecond
    let content: BattleContent
    var mapImageName: String

    var playArea: CGRect

    var slotSize: CGSize { virtualCanvas.towerSlotSize }
    var startingMoney = 0

    @Published var money = 0

    var startingLives = 0

    @Published var lives = 0

    @Published var escapedEnemyCount = 0

    @Published var isDefeated = false

    @Published var isCleared = false
    private(set) var outcomeTick: Int64?
    var acceptsPlayerInput: Bool { isReady && !isPaused && !isDefeated && !isCleared }
    @Published var earnedMetaStars = 0
    let onVictory: (Int, Int) -> Int
    let previousBestStars: Int

    @Published var awaitingWaveStart = false

    @Published var waveCountdownSeconds: Int?

    var towerCosts: [TowerKind: [Int: [Int: Int]]] = [:]
    var towerFamilyNames: [TowerKind: String] = [:]
    var towerMenuDetails: [TowerKind: [Int: [Int: TowerMenuDetails]]] = [:]

    func towerFamilyName(for kind: TowerKind) -> String {
        guard let name = towerFamilyNames[kind] else {
            fatalError("Missing database tower_type_name for \(kind.rawValue)")
        }
        return name
    }

    func towerName(for kind: TowerKind, atLevel level: Int, branch: Int = 1) -> String {
        guard let details = menuDetails(for: kind, atLevel: level, branch: branch) else {
            preconditionFailure("Missing authored tower text for \(kind), level \(level), branch \(branch)")
        }
        return details.name
    }

    func menuDetails(for kind: TowerKind, atLevel level: Int, branch: Int = 1) -> TowerMenuDetails? {
        guard let details = towerMenuDetails[kind]?[level]?[branch],
              let tuning = towerLevels[kind]?[level]?[branch] else {
            fatalError("Missing database tower text or tuning: \(kind), level \(level), branch \(branch)")
        }
        return details.including(upgrades: tuning.upgradePaths)
    }

    func buildCost(for kind: TowerKind) -> Int? {
        guard let cost = towerCosts[kind]?[1]?[1] else {
            fatalError("Missing database build cost for \(kind)")
        }
        return cost
    }

    func upgradeCost(for kind: TowerKind, to level: Int, branch: Int = 1, at slot: Int? = nil) -> Int? {
        guard let base = authoredTowerLevels[kind]?[level]?[branch] else {
            fatalError("Missing database upgrade cost for \(kind), level \(level), branch \(branch)")
        }
        let served = (slot ?? selectedTowerSlotIndex).map(isServedByMagazine) ?? false
        return metaUpgrades.priced(base, kind: kind, level: level,
            context: metaBattleProgress.context(kind: kind, level: level, servedByMagazine: served)).cost
    }

    func isServedByMagazine(_ slot: Int) -> Bool {
        guard slotPositions.indices.contains(slot) else { return false }
        return placedTowers.contains { post in
            guard post.kind == .supply, post.slotIndex != slot, let tuning = towerLevel(for: post) else { return false }
            return tuning.attackRange.contains(slotPositions[slot], from: post.position)
        }
    }

    @Published var towerUnlocks: [TowerKind: Int] = [:]

    var chosenHeroes: HeroSelection?
    var heroSelection: HeroSelection?
    var heroImageAspectRatios: [UUID: CGFloat] = [:]

    var primaryHero: Hero? { heroSelection?.primary }
    var secondaryHero: Hero? { heroSelection?.secondary }

    var availableTowerKinds: Set<TowerKind> { Set(towerUnlocks.filter { $0.value > 0 }.keys) }

    var slotPositions: [CGPoint] = []

    var exitPositions: [CGPoint] = []

    var projectileHitRadiusInImagePixels: CGFloat { combatRules.projectileHitRadius }

    var metaBattleProgress = MetaUpgradeBattleProgress()
    var authoredTowerLevels: [TowerKind: [Int: [Int: TowerLevel]]] = [:]
    var pricedTowerLevels: [TowerKind: [Int: [Int: TowerLevel]]] = [:]
    var towerLevels: [TowerKind: [Int: [Int: TowerLevel]]] = [:]

    func towerLevel(for tower: PlacedTower) -> TowerLevel? {
        guard let tuning = pricedTowerLevels[tower.kind]?[tower.level]?[tower.branch] else {
            fatalError("Missing database tower attributes: \(tower.kind), level \(tower.level), branch \(tower.branch)")
        }
        return metaUpgrades.combat(tuning.upgraded(with: tower.upgrades), kind: tower.kind)
    }

    func attackRange(for tower: PlacedTower) -> CGFloat? {
        towerLevel(for: tower)?.attackRange.radius
    }

    func hasAttackRange(_ tower: PlacedTower) -> Bool {
        tower.kind.projectileAssetName != nil && (attackRange(for: tower) ?? 0) > 0
    }

    func fireCooldownTicks(for tower: PlacedTower) -> Int64 {
        let rate = rateOfFire(for: tower)
        guard rate > 0 else { return .max }
        return max(1, Int64((Double(SimClock.ticksPerSecond) / rate).rounded()))
    }

    func rateOfFire(for tower: PlacedTower) -> Double {
        guard let tuning = towerLevel(for: tower), tuning.fireInterval > 0
        else { return 0 }
        return TowerSupportSource.attackSpeed(at: tower.position, for: tuning.attackMode,
            sources: supportSources) / tuning.fireInterval
    }

    var supportSources: [TowerSupportSource] {
        placedTowers.compactMap { tower in
            guard let tuning = towerLevel(for: tower),
                  tuning.support.hasAura || tuning.support.incomePerWave > 0 else { return nil }
            return TowerSupportSource(position: tower.position, tuning: tuning)
        }
    }

    var paidSupplyWaves: Set<Int> = []

    func paySupplyIncome(for wave: Int) {
        guard paidSupplyWaves.insert(wave).inserted else { return }
        let income = TowerSupportSource.income(supportSources)
        money += income
        goldEarned += income
    }

    var damageTotalBySlot: [Int: Double] = [:]
    var targetingSecondsBySlot: [Int: Double] = [:]
    var lastStatsTick: Int64 = 0

    @Published var totalDamageBySlot: [Int: Double] = [:]

    @Published var targetingTimeBySlot: [Int: Double] = [:]

    func refreshTowerStatsIfDue() {
        guard timer.tick - lastStatsTick >= Int64(SimClock.ticksPerSecond) else { return }
        lastStatsTick = timer.tick
        totalDamageBySlot = damageTotalBySlot
        targetingTimeBySlot = targetingSecondsBySlot
    }

    var pathHalfWidthInImagePixels: CGFloat { virtualCanvas.pathWidth / 2 }

    // Coverage is only used by a placed tower's debug legend. Keep its raster
    // and requested results on this level attempt instead of computing every
    // slot/range combination while the player waits to enter the level.
    var laneAreaBySlot: [Int: [CGFloat: Double]] = [:]
    var laneGrid: (columns: Int, rows: Int, cells: [Bool])?
    static let laneCell: CGFloat = 4

    func pathAreaInRange(for tower: PlacedTower) -> Double {
        guard let tuning = towerLevel(for: tower) else { return 0 }
        let range = CGFloat(tuning.range)
        if let cached = laneAreaBySlot[tower.slotIndex]?[range] { return cached }
        let grid = laneGrid ?? makeLaneGrid()
        laneGrid = grid
        let cell = Self.laneCell
        let c = tower.position
        let reach = TowerAttackRange(tuning.range, verticalFraction: combatRules.rangeVerticalFraction)
        let gx0 = max(0, Int((c.x - range) / cell)), gx1 = min(grid.columns - 1, Int((c.x + range) / cell))
        let gy0 = max(0, Int((c.y - range) / cell)), gy1 = min(grid.rows - 1, Int((c.y + range) / cell))
        var covered = 0.0
        if gx0 <= gx1, gy0 <= gy1 {
            let cellArea = Double(cell * cell)
            for gy in gy0...gy1 {
                for gx in gx0...gx1 where grid.cells[gy * grid.columns + gx] {
                    let px = (CGFloat(gx) + 0.5) * cell, py = (CGFloat(gy) + 0.5) * cell
                    if reach.contains(CGPoint(x: px, y: py), from: c) { covered += cellArea }
                }
            }
        }
        laneAreaBySlot[tower.slotIndex, default: [:]][range] = covered
        return covered
    }

    func makeLaneGrid() -> (columns: Int, rows: Int, cells: [Bool]) {
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
        return (cols, rows, lane)
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
        var splashCoverPierce: Double? = nil

        var firingBoundary: TowerAttackRange? = nil
        var firingOrigin: CGPoint? = nil
        var moraleStrike: ArtilleryMoraleStrike? = nil
        var grapeshot: GrapeshotFlight? = nil
        var solidShot: SolidShotFlight? = nil
    }

    #if DEBUG
    /// Observe the normal display-link loop without substituting enemies or time.
    var engineerLiveReviewSnapshot: [String: Any] {
        let fields = engineerObstacleFields
        return ["gameSeconds": lastStepGameTicks * SimClock.dt,
                "speedMultiplier": speedMultiplier, "money": money,
                "walkers": walkers.map { walker in
                    ["id": walker.id, "asset": walker.assetName, "pathIndex": walker.pathIndex,
                     "distance": walker.pathDistance, "x": walker.position.x, "y": walker.position.y,
                     "baseSpeed": walker.speed, "blocked": blockedWalkerIDs.contains(walker.id),
                     "morale": walker.morale.value,
                     "slowMultiplier": EngineerObstacleField.movementMultiplier(
                        at: walker.position, retreating: false, fields: fields)] as [String: Any]
                }]
    }

    func engineerLiveReviewCoverage() -> [[String: Any]] {
        guard let tuning = towerLevels[.special]?[1]?[1], let stats = tuning.engineerObstacles else {
            preconditionFailure("Missing authored level-1 engineer tuning")
        }
        return slotPositions.enumerated().map { slot, position in
            guard let site = tuning.attackRange.nearestPathPoint(to: position, from: position, paths: paths) else {
                return ["slot": slot, "reachable": false]
            }
            let field = EngineerObstacleField(position: site, stats: stats, paths: paths)
            return ["slot": slot, "reachable": true, "x": site.x, "y": site.y,
                    "heading": field.heading, "radius": stats.radius, "widthFraction": stats.widthFraction,
                    "routes": paths.enumerated().map { index, path in
                        let covered = stride(from: 0.0, through: path.totalLength, by: 1).filter {
                            let point = path.point(atDistance: $0)
                            return field.contains(CGPoint(x: point.x, y: point.y))
                        }
                        return ["pathIndex": index, "coveredWorldUnits": covered.count,
                                "firstDistance": covered.first as Any? ?? NSNull(),
                                "lastDistance": covered.last as Any? ?? NSNull()] as [String: Any]
                    }] as [String: Any]
        }
    }
    var reviewEnemyStats: EnemyStats {
        guard let enemy = enemyTypesByID.values.first(where: { $0.key == "redcoat_regular" }) else {
            fatalError("Missing authored review enemy")
        }
        return enemy.stats
    }
    #endif

    struct Walker: Identifiable {
        let id: Int
        let assetName: String
        let speed: Double
        let maxHP: Double
        var hp: Double
        let bounty: Int
        let livesCost: Int
        let damageMin: Double
        let damageMax: Double
        let cover: Double
        let blockImmune: Bool
        let spawnTick: Int64
        let pathIndex: Int
        var discipline: Double
        var moraleResponse: EnemyMoraleResponse
        var morale: EnemyMorale
        var position: CGPoint = .zero
        var pathDistance: Double = 0
        var meleeDamageRange: ClosedRange<Double> {
            let multiplier = moraleResponse.damageMultiplier(morale: morale.value, maximum: morale.rules.moraleMax)
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

    struct HeroPost {
        let hero: Hero
        let assetName: String
        let combat: HeroCombatStats
        var unit: MilitiaUnit
        var movement: HeroMovement
        var enemySwingTicks: [Int: Int] = [:]
    }

    struct MilitiaGarrison {
        var rallyPoint: Point
        var units: [MilitiaUnit]
        var enemySwingTicks: [Int: Int] = [:]
        var stats: MeleeUnitStats? = nil
        var anchor: Point? = nil
    }

    struct WalkPose {
        var facing: UnitFacing
        var walkPhase: Double
        var isWalking: Bool
    }

    @Published var projectiles: [Projectile] = []
    struct ArtilleryImpact: Identifiable {
        let id: Int
        let position: CGPoint
        let radius: CGFloat
        var isDemolition = false
        var age: Double = 0
        var duration: Double { isDemolition ? DemolitionExplosion.duration : 0.78 }
    }
    @Published var artilleryImpacts: [ArtilleryImpact] = []
    var nextProjectileID = 0
    var grapeshotHits: [Int: Set<Int>] = [:]
    var nextFireTickBySlot: [Int: Int64] = [:]
    var lastStepGameTicks: Double = 0

    @Published var placedTowers: [PlacedTower] = []

    @Published var selectedSlotIndex: Int?

    @Published var selectedTowerSlotIndex: Int?

    @Published var rallyPointsBySlot: [Int: CGPoint] = [:]

    @Published var isPlacingRallyPoint = false
    @Published var isPlacingDemolition = false
    @Published var isPlacingEngineerObstacles = false

    func engineerObstacleField(for tower: PlacedTower) -> EngineerObstacleField? {
        guard let position = tower.engineerObstaclePosition,
              let stats = towerLevel(for: tower)?.engineerObstacles else { return nil }
        return EngineerObstacleField(position: position, stats: stats, paths: paths)
    }

    var engineerObstacleFields: [EngineerObstacleField] {
        placedTowers.compactMap { engineerObstacleField(for: $0) }
    }

    /// The same live footprints drive movement and contact feedback.
    var engineerObstacleFeedback: (walkerIDs: Set<Int>, towerSlots: Set<Int>) {
        let towerFields = placedTowers.compactMap { tower -> (Int, EngineerObstacleField)? in
            guard let field = engineerObstacleField(for: tower) else { return nil }
            return (tower.slotIndex, field)
        }
        let fields = towerFields.map { $0.1 }
        var walkerIDs: Set<Int> = []
        var towerSlots: Set<Int> = []
        for walker in walkers where walker.hp > 0 {
            let multiplier = EngineerObstacleField.movementMultiplier(
                at: walker.position, retreating: false, fields: fields)
            guard multiplier < 1 else { continue }
            walkerIDs.insert(walker.id)
            for (slot, field) in towerFields where 1 - field.stats.slowFraction <= multiplier
                && field.contains(walker.position) {
                towerSlots.insert(slot)
            }
        }
        return (walkerIDs, towerSlots)
    }

    func beginEngineerObstaclePlacement() {
        guard acceptsPlayerInput, let slot = selectedTowerSlotIndex, let tower = placedTower(atSlot: slot),
              towerLevel(for: tower)?.engineerObstacles != nil else { return }
        isPlacingRallyPoint = false
        isPlacingDemolition = false
        armedUpgradeBranch = nil
        armedUpgradePathID = nil
        isPlacingEngineerObstacles = true
    }

    @discardableResult
    func placeEngineerObstacles(at requested: CGPoint) -> BuildResult {
        guard acceptsPlayerInput, isPlacingEngineerObstacles, let slot = selectedTowerSlotIndex,
              let index = placedTowers.firstIndex(where: { $0.slotIndex == slot }),
              let tuning = towerLevel(for: placedTowers[index]), tuning.engineerObstacles != nil else { return .invalid }
        defer { dismissMenu() }
        let origin = placedTowers[index].position
        guard tuning.attackRange.contains(requested, from: origin),
              let site = tuning.attackRange.nearestPathPoint(to: requested, from: origin, paths: paths) else { return .invalid }
        placedTowers[index].engineerObstaclePosition = site
        return .ok
    }

    func beginDemolitionPlacement() {
        guard acceptsPlayerInput, let slot = selectedTowerSlotIndex,
              placedTower(atSlot: slot)?.demolitionCharge != nil else { return }
        isPlacingRallyPoint = false
        armedUpgradeBranch = nil
        armedUpgradePathID = nil
        isPlacingDemolition = true
    }

    @discardableResult
    func placeDemolition(at requested: CGPoint) -> BuildResult {
        guard acceptsPlayerInput, isPlacingDemolition, let slot = selectedTowerSlotIndex,
              let index = placedTowers.firstIndex(where: { $0.slotIndex == slot }),
              let tuning = towerLevel(for: placedTowers[index]) else { return .invalid }
        let origin = placedTowers[index].position
        guard tuning.attackRange.contains(requested, from: origin),
              let point = tuning.attackRange.nearestPathPoint(to: requested, from: origin, paths: paths)
        else {

            dismissMenu()
            return .invalid
        }
        placedTowers[index].demolitionCharge?.place(at: point)

        if placedTowers[index].demolitionCharge?.isReady == false {
            rallyFlagFlashCount += 1
            rallyFlagFlash = RallyFlagFlash(id: rallyFlagFlashCount, position: point)
        } else {
            rallyFlagFlash = nil
        }
        dismissMenu()
        return .ok
    }

    @discardableResult func detonateDemolition(atSlot slot: Int) -> Bool {
        guard acceptsPlayerInput,
              let index = placedTowers.firstIndex(where: { $0.slotIndex == slot }),
              var charge = placedTowers[index].demolitionCharge,
              let position = charge.position,
              let tuning = towerLevel(for: placedTowers[index]),
              tuning.attackRange.contains(position, from: placedTowers[index].position),
              charge.detonate() else { return false }
        placedTowers[index].demolitionCharge = charge
        demolitionDetonations += 1
        let blast = Projectile(id: nextProjectileID, kind: .areaOfEffect, position: position,
            heading: 0, damage: random.double(in: tuning.shotMinDamage...max(tuning.shotMinDamage, tuning.shotMaxDamage)),
            targetID: -1, slotIndex: slot, speed: 0, splashRadius: CGFloat(tuning.aoeRadius),
            impactPoint: position, splashCoverPierce: tuning.splashCoverPierce, moraleStrike: ArtilleryMoraleStrike(tuning: tuning))
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

    func advanceDemolitionCharges(seconds: Double) {
        guard seconds > 0, !isCleared, !isDefeated else { return }
        for index in placedTowers.indices {
            guard placedTowers[index].demolitionCharge?.isReady == false else { continue }
            placedTowers[index].demolitionCharge?.advance(seconds: seconds)
        }
    }

    func detonateOutgoingDemolitionCharges(seconds: Double, nowTicks: Double) {
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
                    advancingBy: travel, radius: tuning.aoeRadius, targetOffset: enemyBodyOffset)
            }
            if enemyAboutToExit { detonateDemolition(atSlot: tower.slotIndex) }
        }
    }

    func advanceWalkers(seconds: Double, nowTicks: Double) {
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
                    recordRemoval(walker, fate: .leaked)
                    loseLife(cost: walker.livesCost)
                    continue
                }
                let p = path.point(atDistance: distance)
                walker.position = CGPoint(x: p.x, y: p.y)
                walker.pathDistance = distance
                if let origin = spawnOrigins[walker.id] {
                    waveMaxProgress[origin.wave] = max(waveMaxProgress[origin.wave], distance / path.totalLength)
                }
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

    @Published var rallyFlagFlash: RallyFlagFlash?

    var rallyFlagFlashCount = 0

    func dismissRallyFlag(id: Int) {
        guard rallyFlagFlash?.id == id else { return }
        rallyFlagFlash = nil
    }

    func toggleRallyPlacement() {
        guard acceptsPlayerInput else { return }
        isPlacingRallyPoint.toggle()
        if isPlacingRallyPoint { armedUpgradeBranch = nil; armedUpgradePathID = nil }
    }

    @discardableResult
    func placeRallyPoint(at point: CGPoint) -> BuildResult {
        guard acceptsPlayerInput, isPlacingRallyPoint, let slot = selectedTowerSlotIndex else { return .invalid }
        var result = BuildResult.invalid
        if let tower = placedTower(atSlot: slot),
           let melee = towerLevel(for: tower)?.meleeUnit,
           hypot(point.x - tower.position.x, point.y - tower.position.y)
               <= CGFloat(melee.rallyPointRadius) {
            setRallyPoint(slot: slot, to: point)
            result = .ok
            if let placed = rallyPointsBySlot[slot] {
                rallyFlagFlashCount += 1
                rallyFlagFlash = RallyFlagFlash(id: rallyFlagFlashCount, position: placed)
            }
        }
        isPlacingRallyPoint = false
        selectedTowerSlotIndex = nil
        return result
    }

    func rallyPoint(forSlot slot: Int) -> CGPoint? { rallyPointsBySlot[slot] }

    func setRallyPoint(slot: Int, to point: CGPoint) {
        guard var g = garrisonsBySlot[slot],
              let tower = placedTower(atSlot: slot),
              let melee = towerLevel(for: tower)?.meleeUnit else { return }
        let towerPos = Point(Double(tower.position.x), Double(tower.position.y))
        g.rallyPoint = BattleGeometry.rallyPoint(requested: Point(Double(point.x), Double(point.y)),
                                             towerPosition: towerPos,
                                             flagRange: melee.rallyPointRadius, paths: paths)
        garrisonsBySlot[slot] = g
        rallyPointsBySlot[slot] = CGPoint(x: g.rallyPoint.x, y: g.rallyPoint.y)
    }

    @Published var armedBuildKind: TowerKind?
    enum HapticPlayback: String { case inactive, coreHaptics, fallback }
    #if DEBUG
    var demolitionHapticStarts = 0
    var lastDemolitionHapticPlayback = HapticPlayback.inactive
    var demolitionHapticCompleted: Bool?
    #endif

    @Published var armedUpgradeBranch: Int?
    @Published var armedUpgradePathID: String?

    @Published var walkers: [Walker] = []
    var nextWalkerID = 0
    var killedCount = 0
    var goldEarned = 0
    var demolitionDetonations = 0
    var shotsByMode: [TowerAttackMode: Int] = [:]
    var shotsBySlot: [Int: Int] = [:]
    var leaksByWave: [Int] = []
    var waveMaxProgress: [Double] = []
    var fatesByType: [UUID: SimulationResult.TypeFates] = [:]
    var spawnOrigins: [Int: (type: UUID, wave: Int)] = [:]
    var onEvent: ((SimEvent, Double) -> Void)?

    func recordRemoval(_ walker: Walker, fate: EnemyFate) {
        guard let origin = spawnOrigins.removeValue(forKey: walker.id) else { return }
        var fates = fatesByType[origin.type] ?? SimulationResult.TypeFates(killed: 0, routed: 0, captured: 0, leaked: 0)
        if fate == .killed { killedCount += 1; fates.killed += 1 }
        if fate == .leaked {
            fates.leaked += 1; leaksByWave[origin.wave] += 1; waveMaxProgress[origin.wave] = 1
        }
        fatesByType[origin.type] = fates
        onEvent?(.enemyRemoved(spawnID: walker.id, typeID: origin.type, fate: fate), Double(timer.tick) * SimClock.dt)
    }

    func creditKill(_ walker: Walker) {
        let bounty = Int((Double(walker.bounty) * combatRules.killBountyMultiplier).rounded())
        money += bounty
        goldEarned += bounty
        recordRemoval(walker, fate: .killed)
    }

    @Published var militia: [MilitiaSoldier] = []
    var garrisonsBySlot: [Int: MilitiaGarrison] = [:]
    var blockedWalkerIDs: Set<Int> = []
    var lastMilitiaTick: Int64 = 0

    var militiaPrevPositions: [Int: CGPoint] = [:]
    var militiaRespawnedIDs: Set<Int> = []
    var militiaPoses: [Int: WalkPose] = [:]
    let combatRules: CombatRules
    let meleeFormation: MeleeFormation
    var nextReinforcementSlot = -1
    var reinforcementSchedule: ReinforcementSchedule?
    @Published var reinforcementCooldown: ReinforcementCooldown = .ready
    @Published var reinforcementCharges = 1
    @Published var isPlacingReinforcements = false

    var canCallReinforcements: Bool {
        isReady && !isDefeated && !isCleared && reinforcementStats != nil
            && reinforcementSchedule?.cooldown(at: timer.tick).isReady == true
    }

    @Published var heroes: [HeroSoldier] = []
    @Published var selectedHeroIndex: Int?
    var heroPosts: [HeroPost] = []

    var hudHeroes: [Hero] {
        heroSelection?.heroes ?? []
    }

    func hudHeroIndex(for heroID: UUID) -> Int? {
        heroPosts.firstIndex { $0.hero.id == heroID && $0.unit.state != .dead }
    }
    var heroRespawnedIDs: Set<Int> = []
    var heroPoses: [Int: HeroWalkPose] = [:]

    struct ScheduledSpawn {
        let wave: Int
        let tick: Int64
        let enemyTypeID: UUID
        let pathIndex: Int
    }

    var pendingSpawns: [ScheduledSpawn] = []

    @Published var speedMultiplier = 1
    @Published var isPaused = false

    @Published var status: String = "Loading…"

    var isReady = false

    var paths: [Path] = []
    var loadedRoadSurface: CGPath?

    var roadSurfacePath: CGPath {
        guard let surface = loadedRoadSurface else {
            preconditionFailure("Missing GeoJSON road surface for \(mapImageName)")
        }
        return surface
    }


    var callWaveButtons: [CallWaveButtonPosition] = []

    var callWaveButtonPositions: [Point] {
        let next = waveSchedule.nextWaveIndex
        guard waves.indices.contains(next) else { return [] }
        return CallWaveButtonPosition.visiblePositions(
            callWaveButtons, forPathIndices: Set(waves[next].spawns.map(\.pathIndex)))
    }

    var levelName = ""
    var enemyTypesByID: [UUID: EnemyType] = [:]
    var waves: [Wave] = []
    var waveIndex = 0
    var waveSchedule = WaveStartSchedule()

    var waveCount: Int { waves.count }
    var currentWaveNumber: Int { min(waveIndex + 1, max(waves.count, 1)) }
    var nextWaveNumber: Int { waveSchedule.nextWaveIndex + 1 }

    var publishesPresentation = false
    private var previousWalkerDistances: [Int: Double] = [:]
    private var previousProjectilePositions: [Int: CGPoint] = [:]
    @Published private(set) var presentationAlpha: Double = 1

    /// Copies for rendering only. Combat always reads walkers/projectiles.
    var displayedWalkers: [Walker] {
        walkers.map { walker in
            guard let previous = previousWalkerDistances[walker.id] else { return walker }
            var displayed = walker
            let distance = previous + (walker.pathDistance - previous) * presentationAlpha
            let point = paths[walker.pathIndex].point(atDistance: distance)
            displayed.position = CGPoint(x: point.x, y: point.y)
            return displayed
        }
    }

    func displayedPosition(of projectile: Projectile) -> CGPoint {
        guard let previous = previousProjectilePositions[projectile.id] else { return projectile.position }
        return CGPoint(x: previous.x + (projectile.position.x - previous.x) * presentationAlpha,
                       y: previous.y + (projectile.position.y - previous.y) * presentationAlpha)
    }

    private func publishBattleFrame(alpha: Double) {
        guard publishesPresentation else { return }
        presentationAlpha = min(1, max(0, alpha))
        publishMilitia(alpha: presentationAlpha)
        publishHeroes(alpha: presentationAlpha)
    }

    var validateHeroAsset: ((String) -> Void)?
    var random: SeededRNG
    let timer = Timer(tickDuration: BattleEngine.normalTickDuration)

    let metaUpgrades: MetaUpgradeEffects
    let enemyHPMultiplier: Double

    let virtualCanvas: VirtualCanvas

    /// Constructed from exactly the same immutable DAO snapshot in the app and CLI.
    init(content: BattleContent, heroesEnabled: Bool,
         startingMoneyOverride: Int?, seed: UInt64,
         onVictory: @escaping (Int, Int) -> Int) throws {
        self.content = content
        combatRules = content.arsenal.combatRules
        meleeFormation = MeleeFormation(rules: combatRules)
        virtualCanvas = content.virtualCanvas
        mapImageName = content.level.mapImageName
        playArea = content.level.playArea
        self.metaUpgrades = content.playerUpgrades.loadout.effects
        self.onVictory = onVictory
        guard let previous = content.playerUpgrades.bestStarsByLevel[content.level.id] else {
            throw DbError.Db(message: "player_meta_upgrade_level_stars[active:\(content.level.id)]: missing level result")
        }
        previousBestStars = previous
        self.enemyHPMultiplier = content.difficulty.enemyHPMultiplier
        random = SeededRNG(seed: seed)
        super.init()
        reinforcementSchedule = ReinforcementSchedule(config: content.reinforcementConfig,
            capacity: metaUpgrades.reinforcementCapacity)
        let level = content.level
        callWaveButtons = content.callButtons
        exitPositions = content.exits.map { CGPoint(x: $0.x, y: $0.y) }
        chosenHeroes = content.chosenHeroes
        let deployments = heroesEnabled ? content.deployments : []
        if !deployments.isEmpty { heroSelection = try HeroSelection(heroes: deployments.map(\.hero)) }
        towerUnlocks = content.unlocks
        levelName = level.name
        startingMoney = startingMoneyOverride ?? level.startingMoney
        money = startingMoney
        startingLives = level.numStartingLives
        lives = level.numStartingLives
        leaksByWave = Array(repeating: 0, count: level.waves.count)
        waveMaxProgress = Array(repeating: 0, count: level.waves.count)
        towerFamilyNames = Dictionary(uniqueKeysWithValues: content.arsenal.towers.map { ($0.kind, $0.name) })
        for tower in content.arsenal.towers {
            for tier in tower.tiers {
                authoredTowerLevels[tower.kind, default: [:]][tier.level, default: [:]][tier.branch] = tier.tuning
                let priced = metaUpgrades.priced(tier.tuning, kind: tower.kind, level: tier.level)
                pricedTowerLevels[tower.kind, default: [:]][tier.level, default: [:]][tier.branch] = priced
                towerCosts[tower.kind, default: [:]][tier.level, default: [:]][tier.branch] = priced.cost
                towerMenuDetails[tower.kind, default: [:]][tier.level, default: [:]][tier.branch] = tier.details
                towerLevels[tower.kind, default: [:]][tier.level, default: [:]][tier.branch] = metaUpgrades.combat(priced, kind: tower.kind)
            }
        }
        slotPositions = level.towerSlots.map { CGPoint(x: $0.position.x, y: $0.position.y) }
        enemyTypesByID = Dictionary(uniqueKeysWithValues: content.enemies.map { ($0.id, $0) })
        waves = level.waves
        paths = level.paths
        loadedRoadSurface = content.movementArea.boundaryPath
        heroPosts = try deployments.map { deployment in
            let hero = deployment.hero
            guard let combat = content.heroCombat[hero.id] else {
                throw DbError.Db(message: "hero[\(hero.id)]: missing battle combat attributes")
            }
            let position = deployment.spawn.position
            return HeroPost(hero: hero, assetName: hero.unitImageName, combat: combat,
                unit: MilitiaUnit(position: position, hp: combat.hp),
                movement: try HeroMovement(area: content.movementArea, spawn: position))
        }
        heroPoses = Dictionary(uniqueKeysWithValues: heroPosts.enumerated().map { index, post in
            (index, HeroWalkPose(baseAssetName: post.assetName, position: post.unit.position))
        })
        waveSchedule = try WaveStartSchedule(waves: waves)
        isReady = true
        refreshWaveStartState()
        status = "\(levelName)  •  wave 1/\(waves.count) waiting  •  tap an entrance, then tap to confirm"
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
        guard acceptsPlayerInput, slotPositions.indices.contains(index), !isSlotOccupied(index) else { return }
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
        armedUpgradePathID = nil
        selectedSlotIndex = selectedSlotIndex == index ? nil : index
    }

    func selectPlacedTower(atSlot index: Int) {
        guard acceptsPlayerInput, isSlotOccupied(index) else { return }
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
        armedUpgradePathID = nil
        isPlacingRallyPoint = false
        selectedTowerSlotIndex = selectedTowerSlotIndex == index ? nil : index
    }

    func dismissMenu() {
        selectedSlotIndex = nil
        selectedTowerSlotIndex = nil
        armedBuildKind = nil
        armedUpgradeBranch = nil
        armedUpgradePathID = nil
        isPlacingRallyPoint = false
        isPlacingDemolition = false
        isPlacingEngineerObstacles = false
    }

    /// nil means the first tap only armed the confirmation.
    @discardableResult
    func tapBuildButton(_ kind: TowerKind) -> BuildResult? {
        guard acceptsPlayerInput, let slot = selectedSlotIndex,
              slotPositions.indices.contains(slot), maxLevel(for: kind) >= 1 else { return .invalid }
        if armedBuildKind == kind {
            guard let cost = buildCost(for: kind), money >= cost else {
                dismissMenu()
                return .needGold
            }
            return buildTower(kind)
        } else if armedBuildKind != nil {
            armedBuildKind = nil
        } else {
            armedBuildKind = kind
        }
        return nil
    }

    func buildPreviewRadius(for kind: TowerKind) -> CGFloat? {
        guard let cost = buildCost(for: kind), money >= cost else { return nil }
        return towerLevels[kind]?[1]?[1].flatMap(Self.overlayRadius)
    }

    func rangeOverlayRadius(for tower: PlacedTower) -> CGFloat? {
        towerLevel(for: tower).flatMap(Self.overlayRadius)
    }

    @discardableResult
    func tapUpgradeButton(branch: Int) -> BuildResult? {
        armedUpgradePathID = nil
        guard acceptsPlayerInput,
              let offer = upgradeOffers.first(where: { $0.branch == branch }) else { return .invalid }
        if armedUpgradeBranch == branch {
            guard money >= offer.cost else {
                dismissMenu()
                return .needGold
            }
            return upgradeSelectedTower(branch: branch)
        } else {
            armedUpgradeBranch = branch
            isPlacingRallyPoint = false
        }
        return nil
    }

    var upgradePaths: [TowerUpgradePath] {
        guard let slot = selectedTowerSlotIndex, let tower = placedTower(atSlot: slot),
              tower.level == 4, maxLevel(for: tower.kind) >= 4 else { return [] }
        return towerLevel(for: tower)!.upgradePaths
    }

    @discardableResult
    func tapUpgradePath(_ pathID: String) -> BuildResult? {
        guard acceptsPlayerInput, let slot = selectedTowerSlotIndex,
              placedTowers.contains(where: { $0.slotIndex == slot }),
              upgradePaths.contains(where: { $0.id == pathID }) else { return .invalid }
        armedUpgradeBranch = nil
        isPlacingRallyPoint = false
        isPlacingDemolition = false
        isPlacingEngineerObstacles = false
        if armedUpgradePathID != pathID {
            armedUpgradePathID = pathID
            return nil
        }
        return purchaseTowerUpgrade(slot: slot, pathID: pathID)
    }

    @discardableResult
    func purchaseTowerUpgrade(slot: Int, pathID: String) -> BuildResult {
        guard acceptsPlayerInput,
              let index = placedTowers.firstIndex(where: { $0.slotIndex == slot }),
              placedTowers[index].level == 4, maxLevel(for: placedTowers[index].kind) >= 4,
              let path = towerLevel(for: placedTowers[index])?.upgradePaths.first(where: { $0.id == pathID })
        else { return .invalid }
        let tower = placedTowers[index]
        guard tower.upgrades.rank(for: pathID) < path.ranks.count,
              let old = towerLevel(for: tower),
              let base = towerLevels[tower.kind]?[tower.level]?[tower.branch] else { return .invalid }
        var progress = tower.upgrades
        let result = progress.purchase(pathID: pathID, from: base, money: &money)
        guard result == .ok else { return result }
        placedTowers[index].upgrades = progress
        let new = towerLevel(for: placedTowers[index])!
        if let preparation = new.demolitionPreparationSeconds {
            placedTowers[index].demolitionCharge?.updatePreparation(seconds: preparation)
        }
        if let oldMelee = old.meleeUnit, let newMelee = new.meleeUnit, var garrison = garrisonsBySlot[slot] {
            for unit in garrison.units.indices { garrison.units[unit].applyUpgrade(from: oldMelee, to: newMelee) }
            garrisonsBySlot[slot] = garrison
            publishMilitia()
        }
        if let next = nextFireTickBySlot[slot], next > timer.tick, old.fireInterval > 0 {
            let remaining = Double(next - timer.tick) * new.fireInterval / old.fireInterval
            nextFireTickBySlot[slot] = timer.tick + Int64(remaining.rounded(.up))
        }
        // Keep the tower selected so the player can inspect and buy the next rank.
        armedUpgradePathID = nil
        return .ok
    }

    var upgradePathPreviewRadius: CGFloat? {
        guard let id = armedUpgradePathID, let slot = selectedTowerSlotIndex,
              let tower = placedTower(atSlot: slot),
              let base = pricedTowerLevels[tower.kind]?[tower.level]?[tower.branch] else { return nil }
        var progress = tower.upgrades
        var previewMoney = money
        guard progress.purchase(pathID: id, from: base, money: &previewMoney) == .ok else { return nil }
        return Self.overlayRadius(for: metaUpgrades.combat(base.upgraded(with: progress), kind: tower.kind))
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

    static func overlayRadius(for tuning: TowerLevel) -> CGFloat? {
        if let melee = tuning.meleeUnit { return CGFloat(melee.rallyPointRadius) }
        return tuning.attackRange.radius > 0 ? tuning.attackRange.radius : nil
    }

    @discardableResult
    func buildTower(_ kind: TowerKind) -> BuildResult {
        guard acceptsPlayerInput, let slotIndex = selectedSlotIndex,
              maxLevel(for: kind) >= 1,
              kind.assetName != nil,
              !isSlotOccupied(slotIndex),
              slotPositions.indices.contains(slotIndex),
              let cost = buildCost(for: kind)
        else { return .invalid }
        guard money >= cost else { return .needGold }
        money -= cost
        var tower = PlacedTower(combatRules: combatRules,
            slotIndex: slotIndex,
            kind: kind,
            position: slotPositions[slotIndex]
        )
        if let tuning = towerLevel(for: tower), tuning.engineerObstacles != nil {
            tower.engineerObstaclePosition = tuning.attackRange.nearestPathPoint(
                to: tower.position, from: tower.position, paths: paths)
        }
        if kind == .ranged { tower.preparedVolley = PreparedMetaVolley(effects: metaUpgrades) }
        placedTowers.append(tower)
        if let melee = towerLevel(for: tower)?.meleeUnit {
            let towerPos = Point(Double(tower.position.x), Double(tower.position.y))
            let rally = BattleGeometry.defaultRallyPoint(
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
        guard let tier = content.arsenal.towers.first(where: { $0.kind == kind })?.tiers.first(where: { $0.level == 1 && $0.branch == 1 }) else {
            fatalError("Missing authored first tier for \(kind)")
        }
        onEvent?(.towerBuilt(slot: slotIndex, towerID: tier.id), elapsedTime)
        return .ok
    }

    var upgradeOffers: [(nextLevel: Int, branch: Int, cost: Int)] {
        guard let slotIndex = selectedTowerSlotIndex else { return [] }
        return upgradeOffers(at: slotIndex)
    }

    func upgradeOffers(at slotIndex: Int) -> [(nextLevel: Int, branch: Int, cost: Int)] {
        guard let tower = placedTower(atSlot: slotIndex) else { return [] }
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
            return upgradeCost(for: tower.kind, to: next, branch: branch, at: slotIndex).map { (next, branch, $0) }
        }
    }

    @discardableResult
    func upgradeSelectedTower(branch: Int = 1) -> BuildResult {
        guard acceptsPlayerInput, let slotIndex = selectedTowerSlotIndex,
              let offer = upgradeOffers.first(where: { $0.branch == branch }),
              let arrayIndex = placedTowers.firstIndex(where: { $0.slotIndex == slotIndex })
        else { return .invalid }
        guard money >= offer.cost else { return .needGold }
        money -= offer.cost
        metaBattleProgress.recordPurchase(kind: placedTowers[arrayIndex].kind, level: offer.nextLevel)
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
        armedUpgradePathID = nil
        onEvent?(.towerUpgraded(slot: slotIndex, level: offer.nextLevel), elapsedTime)
        return .ok
    }

    func refreshWaveStartState() {
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

    @discardableResult
    func startNextWave() -> BuildResult {
        guard acceptsPlayerInput,
              let start = waveSchedule.startNextWave(at: timer.tick, manually: true)
        else { return .invalid }
        money += start.moneyBonus
        goldEarned += start.moneyBonus
        enterWave(start.index)
        refreshWaveStartState()
        return .ok
    }

    func advanceWaveSchedule() {

        while let start = waveSchedule.startNextWave(at: timer.tick, manually: false) {
            enterWave(start.index)
        }
        refreshWaveStartState()
    }

    func enterWave(_ index: Int) {
        guard waves.indices.contains(index) else { return }
        waveIndex = index
        onEvent?(.waveStarted(index: index), Double(timer.tick) * SimClock.dt)
        paySupplyIncome(for: index)
        let wave = waves[index]
        let base = timer.tick

        var scheduled: [ScheduledSpawn] = []
        for entry in wave.spawns {
            for i in 0..<entry.count {
                let seconds = entry.delay + Double(i) * entry.interval
                scheduled.append(ScheduledSpawn(
                    wave: index, tick: base + Int64((seconds / SimClock.dt).rounded()),
                    enemyTypeID: entry.enemyTypeID,
                    pathIndex: entry.pathIndex))
            }
        }

        pendingSpawns.append(contentsOf: scheduled)
        pendingSpawns.sort { $0.tick < $1.tick }
        status = "\(levelName)  •  wave \(index + 1)/\(waves.count)  •  "
            + "\(scheduled.count) enemies"
    }

    // Presentation lifecycle hooks. They do not implement combat.
    func start() {}
    func stop() {}
    func stopSimulation() {}
    func pause() { isPaused = true; stop() }
    func resume() { isPaused = false }
    @discardableResult func playGameplayHaptic(_ pattern: GameplayHapticPattern) -> HapticPlayback { .inactive }

    func loseLife(cost: Int) {
        guard !isDefeated else { return }
        lives = max(0, lives - cost)
        escapedEnemyCount += 1
        guard lives == 0 else { return }
        isDefeated = true
        outcomeTick = timer.tick
        pendingSpawns.removeAll()
        refreshWaveStartState()

        if artilleryImpacts.isEmpty { stopSimulation() }
    }

    func speedUp() {
        timer.setTickDuration(timer.tickDuration / 2)
        speedMultiplier *= 2
    }

    /// Both the display driver and headless driver advance the same complete
    /// engine ticks. Display interpolation must never advance combat or RNG.
    func advance(ticks: Int, interpolation: Double) {
        precondition(ticks >= 0)
        guard !isPaused, !paths.isEmpty else { return }
        for _ in 0..<ticks { advanceBattleTick() }
        publishBattleFrame(alpha: interpolation)
    }

    private func advanceBattleTick() {
        if publishesPresentation {
            previousWalkerDistances = Dictionary(uniqueKeysWithValues: walkers.map { ($0.id, $0.pathDistance) })
            previousProjectilePositions = Dictionary(uniqueKeysWithValues: projectiles.map { ($0.id, $0.position) })
        }
        timer.advanceTick()
        lastStepGameTicks = Double(timer.tick)
        if isCleared || isDefeated {
            advanceArtilleryImpacts(seconds: SimClock.dt)
            if artilleryImpacts.isEmpty { stopSimulation() }
            return
        }
        advanceWaveSchedule()
        advanceReinforcements()
        refreshTowerStatsIfDue()

        while let next = pendingSpawns.first, timer.tick >= next.tick {
            pendingSpawns.removeFirst()
            guard let type = enemyTypesByID[next.enemyTypeID] else {
                fatalError("Missing enemy_type[\(next.enemyTypeID)] in battle content")
            }
            spawnOrigins[nextWalkerID] = (type.id, next.wave)
            onEvent?(.enemySpawned(spawnID: nextWalkerID, typeID: type.id), Double(timer.tick) * SimClock.dt)
            let stats = type.stats
            let maxHP = stats.maxHP * enemyHPMultiplier
            walkers.append(Walker(
                id: nextWalkerID,
                assetName: type.imageName,
                speed: stats.speed,
                maxHP: maxHP,
                hp: maxHP,
                bounty: stats.gold, livesCost: stats.livesCost,
                damageMin: stats.damageMin,
                damageMax: stats.damageMax,
                cover: stats.cover,
                blockImmune: type.traits.contains(.rideDown),
                spawnTick: next.tick,
                pathIndex: next.pathIndex,
                discipline: stats.discipline,
                moraleResponse: stats.moraleResponse,
                morale: EnemyMorale(rules: combatRules),
                position: {
                    let point = paths[min(max(next.pathIndex, 0), paths.count - 1)].point(atDistance: 0)
                    return CGPoint(x: point.x, y: point.y)
                }()
            ))
            nextWalkerID += 1
        }

        let gameDt = SimClock.dt
        advanceArtilleryImpacts(seconds: gameDt)
        advanceWalkers(seconds: gameDt, nowTicks: Double(timer.tick))

        guard !isDefeated else { return }
        stepMilitia()

        if waveSchedule.allWavesStarted && pendingSpawns.isEmpty && walkers.isEmpty && !isCleared {
            isCleared = true
            outcomeTick = timer.tick
            do {
                earnedMetaStars = try VictoryReward(lives: lives, startingLives: startingLives,
                                                    previousBestStars: previousBestStars).earned
            } catch { fatalError("Invalid battle victory: \(error)") }
            _ = onVictory(lives, startingLives) // Persist only; never decide the battle's reward.
            refreshWaveStartState()
            status = "\(levelName)  •  all \(waves.count) waves cleared"
        }

        updateCombat(gameDt: gameDt)
    }

    func stepMilitia() {
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

    func updateMilitiaPoses() {
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

    func updateHeroPoses() {
        var poses: [Int: HeroWalkPose] = [:]
        poses.reserveCapacity(heroPosts.count)
        for (id, post) in heroPosts.enumerated() where post.unit.state != .dead {
            var pose: HeroWalkPose
            if heroRespawnedIDs.contains(id) {
                pose = HeroWalkPose(baseAssetName: post.assetName, position: post.unit.position)
            } else {
                guard let existing = heroPoses[id] else {
                    fatalError("hero[\(post.hero.id)]: missing animation pose")
                }
                pose = existing
            }
            pose.advance(to: post.unit.position)
            if post.unit.state == .fighting,
               let target = walkers.first(where: { $0.id == post.unit.targetSpawnID }) {
                pose.face(toward: Point(target.position.x, target.position.y))
            }
            poses[id] = pose
        }
        heroPoses = poses
    }

    var reinforcementStats: MeleeUnitStats? {
        guard let levels = towerLevels[.melee] else { return nil }
        for level in levels.keys.sorted() {
            guard let branches = levels[level] else { continue }
            for branch in branches.keys.sorted() {
                if let melee = branches[branch]?.meleeUnit { return melee }
            }
        }
        return nil
    }

    func garrisonMelee(slot: Int,
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
        guard acceptsPlayerInput, canCallReinforcements, let melee = reinforcementStats,
              reinforcementSchedule?.deploy(slot: nextReinforcementSlot, at: timer.tick) == true
        else { return false }
        let anchor = Point(Double(point.x), Double(point.y))
        garrisonsBySlot[nextReinforcementSlot] = MilitiaGarrison(
            rallyPoint: anchor,
            units: (0..<combatRules.reinforcementSoldierCount).map { index in
                MilitiaUnit(position: meleeFormation.spawnPoint(
                    index: index, of: combatRules.reinforcementSoldierCount, building: anchor),
                            hp: melee.hp)
            },
            stats: melee,
            anchor: anchor)
        nextReinforcementSlot -= 1
        isPlacingReinforcements = false
        reinforcementCooldown = reinforcementSchedule!.cooldown(at: timer.tick)
        reinforcementCharges = reinforcementSchedule!.availableDeployments(at: timer.tick)
        publishMilitia()
        return true
    }

    func toggleReinforcementPlacement() {
        guard acceptsPlayerInput, canCallReinforcements else { return }
        dismissMenu()
        if selectedHeroIndex != nil {
            selectedHeroIndex = nil
            publishHeroes()
        }
        isPlacingReinforcements.toggle()
    }

    @discardableResult
    func placeReinforcements(at point: CGPoint) -> BuildResult {
        guard acceptsPlayerInput, isPlacingReinforcements, isOnPath(point) else { return .invalid }
        return callReinforcements(at: point) ? .ok : .invalid
    }

    func advanceReinforcements() {
        guard let expired = reinforcementSchedule?.expire(at: timer.tick) else { return }
        let cooldown = reinforcementSchedule!.cooldown(at: timer.tick)
        if reinforcementCooldown != cooldown { reinforcementCooldown = cooldown }
        let charges = reinforcementSchedule!.availableDeployments(at: timer.tick)
        if reinforcementCharges != charges { reinforcementCharges = charges }
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

    func militiaPositionsById() -> [Int: CGPoint] {
        var out: [Int: CGPoint] = [:]
        for (slot, g) in garrisonsBySlot {
            for (i, u) in g.units.enumerated() where u.state != .dead {
                out[slot * 8 + i] = CGPoint(x: u.position.x, y: u.position.y)
            }
        }
        return out
    }

    func pathNearest(to target: Point) -> Path? {
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

    func marchWaypoint(from current: Point, to target: Point,
                               path: Path, targetAlong: Double) -> Point {
        let fallInRadius = meleeFormation.postSpread
        guard current.distance(to: target) > fallInRadius else { return target }
        let currentAlong = path.nearestDistance(to: current)
        let remaining = targetAlong - currentAlong
        guard abs(remaining) > fallInRadius else { return target }
        let lookahead = remaining > 0 ? fallInRadius : -fallInRadius
        return path.point(atDistance: currentAlong + lookahead)
    }

    func stepMilitiaTick() {
        let dt = SimClock.dt
        let sources = supportSources

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
                TowerSupportSource.heal(&unit, maximumHP: melee.hp, seconds: dt, sources: sources)
                var targetPos: Point? = nil
                if unit.targetSpawnID >= 0, !killedIDs.contains(unit.targetSpawnID),
                   let wi = indexByWalkerID[unit.targetSpawnID] {
                    targetPos = Point(Double(walkers[wi].position.x),
                                      Double(walkers[wi].position.y))
                }
                let context = MilitiaContext(rules: combatRules,
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
                    let step = combatRules.meleeMoveSpeed * dt
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
                            BattleGeometry.fireTicks(combatRules.enemySwingInterval)
                    }
                    if !killedIDs.contains(targetSpawnID),
                       let wi = indexByWalkerID[targetSpawnID] {
                        var w = walkers[wi]
                        let roll = random.double(in: melee.damageRange) * metaUpgrades.meleeDamageMultiplier(
                            moraleFraction: w.morale.value / w.morale.rules.moraleMax)
                        let dealt = min(w.hp, roll * (1.0 - w.cover))
                        w.hp -= roll * (1.0 - w.cover)
                        damageTotalBySlot[slot, default: 0] += dealt
                        walkers[wi] = w
                        if w.hp <= 0 {
                            creditKill(w)
                            killedIDs.insert(targetSpawnID)
                            unit.state = .holding
                            unit.targetSpawnID = -1
                            g.enemySwingTicks[targetSpawnID] = nil
                        }
                    }
                    unit.swingTicksLeft = BattleGeometry.fireTicks(melee.attackInterval)
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
                        ?? BattleGeometry.fireTicks(combatRules.enemySwingInterval)
                    swing -= 1
                    if swing <= 0 {
                        let w = walkers[wi]
                        unit.hp -= random.double(in: w.meleeDamageRange)
                            * (1.0 - melee.defenseRating)
                        swing = BattleGeometry.fireTicks(combatRules.enemySwingInterval)
                        if unit.hp <= 0 {
                            claimed.remove(unit.targetSpawnID)
                            blockedWalkerIDs.remove(unit.targetSpawnID)
                            g.enemySwingTicks[unit.targetSpawnID] = nil
                            unit.state = .dead
                            unit.targetSpawnID = -1
                            unit.respawnTicksLeft =
                                BattleGeometry.fireTicks(melee.respawnSeconds)
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

    func stepHeroesTick(claimed: inout Set<Int>,
                                killedIDs: inout Set<Int>,
                                indexByWalkerID: [Int: Int]) {
        guard !heroPosts.isEmpty else { return }
        let dt = SimClock.dt
        let sources = supportSources

        for hi in 0..<heroPosts.count {
            var post = heroPosts[hi]
            TowerSupportSource.heal(&post.unit, maximumHP: post.combat.hp,
                                    seconds: dt, sources: sources)
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

            let context = MilitiaContext(rules: combatRules, freeEnemies: free,
                                         targetPosition: targetPos,
                                         rallyPoint: station,
                                         towerPosition: station,
                                         leashRadius: combatRules.heroLeashRadius,
                                         engageScanRadius: combatRules.heroEngageScanRadius)
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
                        BattleGeometry.fireTicks(combatRules.enemySwingInterval)
                }
                if !killedIDs.contains(targetSpawnID),
                   let wi = indexByWalkerID[targetSpawnID] {
                    var w = walkers[wi]
                    let roll = random.double(in: post.combat.damageRange(attackSpread: combatRules.meleeAttackSpread))
                    w.hp -= roll * (1.0 - w.cover)
                    walkers[wi] = w
                    if w.hp <= 0 {
                        creditKill(w)
                        killedIDs.insert(targetSpawnID)
                        post.unit.state = .holding
                        post.unit.targetSpawnID = -1
                        post.enemySwingTicks[targetSpawnID] = nil
                    }
                }
                post.unit.swingTicksLeft = BattleGeometry.fireTicks(post.combat.attackInterval)
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
                    ?? BattleGeometry.fireTicks(combatRules.enemySwingInterval)
                swing -= 1
                if swing <= 0 {
                    let w = walkers[wi]
                    post.unit.hp -= random.double(in: w.meleeDamageRange)
                        * (1.0 - post.combat.defenseRating)
                    swing = BattleGeometry.fireTicks(combatRules.enemySwingInterval)
                    if post.unit.hp <= 0 {
                        claimed.remove(post.unit.targetSpawnID)
                        blockedWalkerIDs.remove(post.unit.targetSpawnID)
                        post.enemySwingTicks[post.unit.targetSpawnID] = nil
                        post.unit.state = .dead
                        post.unit.targetSpawnID = -1
                        post.unit.respawnTicksLeft =
                            BattleGeometry.fireTicks(post.combat.respawnSeconds)
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

    func publishHeroes(alpha: Double = 1) {
        guard publishesPresentation else { return }
        var out: [HeroSoldier] = []
        for (i, post) in heroPosts.enumerated() where post.unit.state != .dead {
            guard let pose = heroPoses[i] else {
                fatalError("hero[\(post.hero.id)]: missing animation pose")
            }
            let sample = pose.sample(alpha: alpha)
            validateHeroAsset?(sample.assetName)
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
        guard acceptsPlayerInput, heroPosts.indices.contains(index), heroPosts[index].unit.state != .dead else { return }
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
        guard acceptsPlayerInput, let index = selectedHeroIndex, heroPosts.indices.contains(index) else { return false }
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

    func publishMilitia(alpha: Double = 1) {
        guard publishesPresentation else { return }
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

    var enemyBodyOffset: CGPoint { CGPoint(x: combatRules.enemyBodyOffsetX, y: combatRules.enemyBodyOffsetY) }

    func bodyPoint(_ walker: Walker) -> CGPoint {
        CGPoint(x: walker.position.x + enemyBodyOffset.x,
                y: walker.position.y + enemyBodyOffset.y)
    }

    func updateCombat(gameDt: Double) {
        let candidates = targetCandidates()

        for towerIndex in placedTowers.indices {
            let tower = placedTowers[towerIndex]
            guard let tuning = towerLevel(for: tower) else { continue }
            guard tuning.attackMode.firesProjectiles else { continue }
            let origin = tower.position
            let solution = RangedTargetCommand(
                tower: TowerTargetingContext(
                    slotIndex: tower.slotIndex,
                    position: Point(Double(origin.x), Double(origin.y)),
                    range: tuning.range, verticalFraction: combatRules.rangeVerticalFraction,
                    targeting: tuning.targeting),
                enemies: candidates,
                paths: paths
            ).execute()
            placedTowers[towerIndex].preparedVolley?.advance(seconds: gameDt, hasTarget: solution != nil)
            guard let solution, let leader = walkers.first(where: { $0.id == solution.id })
            else { continue }

            targetingSecondsBySlot[tower.slotIndex, default: 0] += gameDt

            let target = tuning.attackMode.requiresAim
                ? tuning.attackRange.clamped(bodyPoint(leader), from: origin)
                : bodyPoint(leader)
            var heading = atan2(target.y - origin.y, target.x - origin.x)
            var aligned = true
            if tuning.attackMode.requiresAim {
                var aim = tower.artilleryAim
                aligned = aim.track(from: origin, to: target,
                                    radiansPerSecond: tuning.turnRate,
                                    deltaTime: gameDt)
                placedTowers[towerIndex].artilleryAim = aim
                heading = CGFloat(aim.heading)
            }

            guard aligned,
                  timer.tick >= nextFireTickBySlot[tower.slotIndex, default: 0] else { continue }
            nextFireTickBySlot[tower.slotIndex] = timer.tick + fireCooldownTicks(for: tower)
            shotsByMode[tuning.attackMode, default: 0] += 1
            shotsBySlot[tower.slotIndex, default: 0] += 1
            onEvent?(.towerFired(slot: tower.slotIndex, target: Point(target.x, target.y)), Double(timer.tick) * SimClock.dt)
            let prepared = placedTowers[towerIndex].preparedVolley?.fire() == true
            let metaDamage = metaUpgrades.rangedDamageMultiplier(kind: tower.kind,
                blocked: blockedWalkerIDs.contains(leader.id), prepared: prepared)
            let minDamage = tuning.shotMinDamage * metaDamage
            let maxDamage = tuning.shotMaxDamage * metaDamage
            if tuning.attackMode == .grapeshot {
                let volleyID = nextProjectileID
                let damage = random.double(in: minDamage...maxDamage)
                for offset in combatRules.grapeshotSpread {
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
            if tuning.attackMode == .solidShot {
                projectiles.append(Projectile(
                    id: nextProjectileID, kind: tower.kind, position: origin,
                    heading: heading, damage: random.double(in: minDamage...maxDamage),
                    targetID: leader.id, slotIndex: tower.slotIndex,
                    speed: CGFloat(tuning.projectileSpeed), splashRadius: 0,
                    firingBoundary: tuning.attackRange, firingOrigin: origin,
                    moraleStrike: ArtilleryMoraleStrike(tuning: tuning),
                    solidShot: SolidShotFlight(range: tuning.attackRange.travelDistance(heading: heading), hitRadius: combatRules.solidShotHitRadius)))
                nextProjectileID += 1
                continue
            }
            projectiles.append(Projectile(
                id: nextProjectileID,
                kind: tower.kind,
                position: origin,
                heading: heading,
                damage: random.double(in: minDamage...maxDamage),
                targetID: leader.id,
                slotIndex: tower.slotIndex,
                speed: CGFloat(tuning.projectileSpeed),
                splashRadius: CGFloat(tuning.aoeRadius),
                impactPoint: tuning.attackMode == .shell ? target : nil,
                splashCoverPierce: tuning.attackMode == .shell ? tuning.splashCoverPierce : nil,
                moraleStrike: tuning.attackMode.requiresAim ? ArtilleryMoraleStrike(tuning: tuning) : nil
            ))
            nextProjectileID += 1
        }

        updateProjectiles(gameDt: gameDt)
    }

    func updateProjectiles(gameDt: Double) {
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
                var priorHits = flight.hitIDs.count
                for id in flight.contacts(from: start, to: end, targets: targets) {
                    if let index = walkers.firstIndex(where: { $0.id == id }),
                       let strike = projectile.moraleStrike {
                        var walker = walkers[index]
                        applyMorale(strike, to: &walker, at: bodyPoint(walker))
                        walkers[index] = walker
                    }
                    let doctrine = metaUpgrades.batteryDamageMultiplier(mode: .solidShot, priorHits: priorHits, distanceFraction: 0)
                    damageWalker(id: id, damage: projectile.damage * doctrine * fireLaneBonus(for: id, kind: projectile.kind), slotIndex: projectile.slotIndex)
                    priorHits += 1
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
                            from: projectile.position, to: end, target: bodyPoint(walker), radius: combatRules.grapeshotHitRadius) else { return nil }
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
                    guard let origin = projectile.firingOrigin, let boundary = projectile.firingBoundary,
                          let victim = walkers.first(where: { $0.id == hit.id }) else {
                        fatalError("Grapeshot projectile is missing its firing boundary or victim")
                    }
                    let distance = hypot(victim.position.x - origin.x, victim.position.y - origin.y)
                    let reach = boundary.travelDistance(heading: projectile.heading)
                    let doctrine = metaUpgrades.batteryDamageMultiplier(mode: .grapeshot, priorHits: 0,
                        distanceFraction: Double(distance / reach))
                    damageWalker(id: hit.id, damage: projectile.damage * doctrine * fireLaneBonus(for: hit.id, kind: projectile.kind), slotIndex: projectile.slotIndex)
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
            if distance <= projectileHitRadiusInImagePixels || distance <= stepLength {
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

    func fireLaneBonus(for id: Int, kind: TowerKind) -> Double {
        guard let walker = walkers.first(where: { $0.id == id }) else { return 1 }
        return metaUpgrades.fireLaneMultiplier(kind: kind,
            inAbatis: engineerObstacleFields.contains { $0.contains(walker.position) })
    }

    func damageWalker(id: Int, damage: Double, slotIndex: Int) {
        guard let index = walkers.firstIndex(where: { $0.id == id }) else { return }
        damageTotalBySlot[slotIndex, default: 0] += min(walkers[index].hp, damage)
        walkers[index].hp -= damage
        if walkers[index].hp <= 0 {
            creditKill(walkers[index])
            walkers.remove(at: index)
        }
    }

    func distanceFrom(_ point: CGPoint, to walker: Walker) -> CGFloat {
        let bp = bodyPoint(walker)
        return hypot(bp.x - point.x, bp.y - point.y)
    }

    func targetCandidates() -> [TargetCandidate] {
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

    func advanceArtilleryImpacts(seconds: Double) {
        guard seconds.isFinite, seconds > 0 else { return }
        artilleryImpacts = artilleryImpacts.compactMap { impact in
            var next = impact
            next.age += seconds
            return next.age < next.duration ? next : nil
        }
    }

    func applyImpact(_ projectile: Projectile, at point: CGPoint, isDemolition: Bool = false) {
        if projectile.moraleStrike != nil {
            artilleryImpacts.append(ArtilleryImpact(id: projectile.id, position: point,
                                                  radius: max(24, projectile.splashRadius),
                                                  isDemolition: isDemolition))
        }
        var remaining: [Walker] = []
        for var walker in walkers {
            let isHit: Bool
            if projectile.moraleStrike != nil {
                isHit = distanceFrom(point, to: walker) <= projectile.splashRadius
            } else {
                isHit = walker.id == projectile.targetID
            }
            if isHit {
                if let strike = projectile.moraleStrike {
                    applyMorale(strike, to: &walker, at: point)
                }
                let damage = projectile.damage * metaUpgrades.fireLaneMultiplier(kind: projectile.kind,
                    inAbatis: !isDemolition && engineerObstacleFields.contains { $0.contains(walker.position) })
                let cover: Double
                if projectile.moraleStrike != nil {
                    guard let pierce = projectile.splashCoverPierce else { fatalError("Explosive projectile is missing authored splash_cover_pierce") }
                    cover = 1 - walker.cover * (1 - pierce)
                } else { cover = 1 }
                let dealt = min(walker.hp, damage * cover)
                walker.hp -= damage * cover
                damageTotalBySlot[projectile.slotIndex, default: 0] += dealt
                if walker.hp <= 0 {
                    creditKill(walker)
                    continue
                }
            }
            remaining.append(walker)
        }
        walkers = remaining
    }

    func applyMorale(_ strike: ArtilleryMoraleStrike, to walker: inout Walker,
                             at point: CGPoint) {
        let loss = strike.loss(distance: Double(distanceFrom(point, to: walker)),
                               discipline: walker.discipline)
        walker.morale.apply(loss: loss, direction: walker.position.x < point.x ? -1 : 1)
    }
}
