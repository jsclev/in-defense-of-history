import Foundation
import CoreGraphics
import Combine
import QuartzCore

enum TowerKind: String, CaseIterable, Identifiable {
    case ranged
    case melee
    case areaOfEffect
    case special

    var id: String { rawValue }

    var categoryName: String {
        switch self {
        case .ranged: return "Ranged"
        case .melee: return "Melee"
        case .areaOfEffect: return "Area of Effect"
        case .special: return "Special"
        }
    }

    init?(categoryName: String) {
        guard let kind = Self.allCases.first(where: { $0.categoryName == categoryName })
        else { return nil }
        self = kind
    }

    private var assetFamilyName: String {
        switch self {
        case .ranged: return "ranged"
        case .melee: return "melee"
        case .areaOfEffect: return "artillery"
        case .special: return "special"
        }
    }

    var assetName: String? { assetName(atLevel: 1) }

    func assetName(atLevel level: Int, branch: Int = 1) -> String? {
        if level >= 4 {
            return "\(assetFamilyName)_tower_level_4_branch_\(branch)"
        }
        let spriteLevel = min(max(level, 1), 3)
        return "\(assetFamilyName)_tower_level_\(spriteLevel)"
    }

    var menuIconName: String {
        switch self {
        case .ranged: return "tower_menu_ranged_square"
        case .melee: return "tower_menu_melee_square"
        case .areaOfEffect: return "tower_menu_artillery_square"
        case .special: return "tower_menu_special_square"
        }
    }

    var spriteHeight: SpriteHeight {
        switch self {
        case .ranged: return MapSpriteSizing.tower(mapPixels: 80)
        case .melee: return MapSpriteSizing.tower(mapPixels: 88)
        case .areaOfEffect: return MapSpriteSizing.tower(mapPixels: 52)
        case .special: return MapSpriteSizing.tower(mapPixels: 76)
        }
    }

    var projectileAssetName: String? {
        switch self {
        case .areaOfEffect: return "cannonball_projectile"
        case .ranged: return "musket_ball_projectile"
        case .melee, .special: return nil
        }
    }

    var projectileHeight: SpriteHeight {
        self == .areaOfEffect ? MapSpriteSizing.cannonball : MapSpriteSizing.musketBall
    }

    /// Whether this kind's art is drawn on the same canvas as tower_slot.png.
    /// Those sprites are placed in the slot's own box on the map, so they land
    /// exactly on it; the older tight-cropped art is sized by `spriteHeight`
    /// instead. This is a fact about which art pipeline produced the sprites,
    /// not level content, and it goes away once every kind is redrawn on the
    /// slot canvas.
    var usesSlotCanvasArt: Bool { self == .ranged }

    // Rate of fire and shot damage are not here: they vary per level and
    // branch and live in the tower table. LevelRunner reads them from
    // `towerLevels`, which is the only source for them.
}

struct PlacedTower: Identifiable {
    let slotIndex: Int
    let kind: TowerKind
    let position: CGPoint
    var level: Int = 1
    var branch: Int = 1

    var id: Int { slotIndex }
}

@MainActor
final class LevelRunner: NSObject, ObservableObject {
    private static let normalTickDuration: Duration = .seconds(1) / SimClock.ticksPerSecond
    private(set) var mapImageName: String
    private(set) var playableRect: CGRect

    /// Box the map renderer fits the slot sprite into, in canonical units.
    /// Tower art drawn on the slot's own canvas is placed in this same box so
    /// it sits on the slot pad. One size for every slot in the game, from the
    /// canvas_spec table.
    var slotSize: CGSize { CanvasSpec.slotSize }
    private(set) var startingMoney = 0

    @Published private(set) var money = 0

    private(set) var startingLives = 0

    @Published private(set) var lives = 0

    @Published private(set) var isDefeated = false

    @Published private(set) var isCleared = false

    private(set) var towerCosts: [TowerKind: [Int: [Int: Int]]] = [:]
    private(set) var towerDisplayNames: [TowerKind: String] = [:]
    private(set) var towerNames: [TowerKind: [Int: [Int: String]]] = [:]

    func towerName(for kind: TowerKind, atLevel level: Int, branch: Int = 1) -> String? {
        towerNames[kind]?[level]?[branch]
    }

    func buildCost(for kind: TowerKind) -> Int? {
        towerCosts[kind]?[1]?[1]
    }

    func upgradeCost(for kind: TowerKind, to level: Int, branch: Int = 1) -> Int? {
        towerCosts[kind]?[level]?[branch]
    }

    @Published private(set) var towerUnlocks: [TowerKind: Int] = [:]

    var availableTowerKinds: Set<TowerKind> { Set(towerUnlocks.keys) }

    private(set) var slotPositions: [CGPoint] = []

    /// How close a shot must get to count as a hit, in map pixels. Purely a
    /// rendering tolerance — it has no column in the tower table.
    private static let projectileHitRadiusInImagePixels: CGFloat = 10

    /// Tuning rows from the tower table, keyed kind → level → branch. Every
    /// combat number the runner uses comes from here; none are written in
    /// Swift, so editing the tower table is the only way to retune.
    private(set) var towerLevels: [TowerKind: [Int: [Int: TowerLevel]]] = [:]

    /// The tower table row backing `tower`, or nil if the level and branch it
    /// carries have no row.
    func towerLevel(for tower: PlacedTower) -> TowerLevel? {
        towerLevels[tower.kind]?[tower.level]?[tower.branch]
    }

    /// Firing range in map pixels, from `tower.tower_range`. `updateCombat`
    /// and the debug range ring both read this, so the ring always draws what
    /// actually shoots.
    func attackRange(for tower: PlacedTower) -> CGFloat? {
        towerLevel(for: tower).map { CGFloat($0.range) }
    }

    /// Whether a range ring means anything for `tower`: it needs both a range
    /// in the table and a projectile to actually use it.
    func hasAttackRange(_ tower: PlacedTower) -> Bool {
        tower.kind.projectileAssetName != nil && (attackRange(for: tower) ?? 0) > 0
    }

    /// Ticks between shots, from `tower.fire_interval`. A row with no interval
    /// never comes off cooldown.
    private func fireCooldownTicks(for tower: PlacedTower) -> Int64 {
        guard let interval = towerLevel(for: tower)?.fireInterval, interval > 0
        else { return .max }
        return max(1, Int64((interval * Double(SimClock.ticksPerSecond)).rounded()))
    }

    /// Shots per second, from `tower.fire_interval`.
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

    // MARK: - Per-tower running totals

    /// Accumulated on the tick loop, republished once a second so the legend
    /// updates without driving a view refresh every tick. Both are cumulative
    /// for the whole level and never reset between waves.
    private var damageTotalBySlot: [Int: Double] = [:]
    private var targetingSecondsBySlot: [Int: Double] = [:]
    private var lastStatsTick: Int64 = 0

    /// Total damage each tower has landed.
    @Published private(set) var totalDamageBySlot: [Int: Double] = [:]

    /// Cumulative seconds each tower has spent with a target in range.
    @Published private(set) var targetingTimeBySlot: [Int: Double] = [:]

    private func refreshTowerStatsIfDue() {
        guard timer.tick - lastStatsTick >= Int64(SimClock.ticksPerSecond) else { return }
        lastStatsTick = timer.tick
        totalDamageBySlot = damageTotalBySlot
        targetingTimeBySlot = targetingSecondsBySlot
    }

    // MARK: - Path area in range

    /// Half-width of the enemy lane, in map pixels.
    /// TODO: this belongs in the database alongside the path points. It is the
    /// last combat number still written in Swift; everything the tower table
    /// covers now reads from `towerLevels`.
    private static let pathHalfWidthInImagePixels: CGFloat = 51

    /// Lane coverage per slot, in map pixels squared, computed once at load.
    ///
    /// Placing a tower must not cost a frame, so nothing here is derived on
    /// demand. A coarse boolean raster of the lane is built once, then each
    /// slot's coverage is summed from it; both happen before the level is
    /// marked ready.
    private var laneAreaBySlot: [Int: [Int: Double]] = [:]

    private static let laneCell: CGFloat = 4

    private static func rangeKey(_ range: CGFloat) -> Int { Int(range.rounded()) }

    func pathAreaInRange(for tower: PlacedTower) -> Double {
        guard let range = towerLevel(for: tower)?.range else { return 0 }
        return laneAreaBySlot[tower.slotIndex]?[Self.rangeKey(CGFloat(range))] ?? 0
    }

    private func precomputeLaneCoverage() {
        let cell = Self.laneCell
        let w = Self.pathHalfWidthInImagePixels
        let cols = Int((CanvasSpec.width / cell).rounded(.up)) + 1
        let rows = Int((CanvasSpec.height / cell).rounded(.up)) + 1
        var lane = [Bool](repeating: false, count: cols * rows)

        // Rasterise the lane by walking each segment's neighbourhood, rather
        // than distance-testing every cell on the map against every segment.
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
                let key = Self.rangeKey(r)
                let gx0 = max(0, Int((c.x - r) / cell)), gx1 = min(cols - 1, Int((c.x + r) / cell))
                let gy0 = max(0, Int((c.y - r) / cell)), gy1 = min(rows - 1, Int((c.y + r) / cell))
                guard gx0 <= gx1, gy0 <= gy1 else { byRange[key] = 0; continue }
                var covered = 0.0
                for gy in gy0...gy1 {
                    for gx in gx0...gx1 where lane[gy * cols + gx] {
                        let px = (CGFloat(gx) + 0.5) * cell, py = (CGFloat(gy) + 0.5) * cell
                        if hypot(px - c.x, py - c.y) <= r { covered += cellArea }
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
        /// Which tower fired this, so damage can be attributed back to it.
        let slotIndex: Int
        /// Copied off the firing tower's row so a shot already in the air
        /// keeps the tuning it was fired with, even if the tower upgrades.
        let speed: CGFloat
        let splashRadius: CGFloat
    }

    struct Walker: Identifiable {
        let id: Int
        let assetName: String
        let speed: Double
        let maxHP: Double
        var hp: Double
        let bounty: Int
        let spawnTick: Int64
        let pathIndex: Int
        var position: CGPoint = .zero
        var pathDistance: Double = 0
    }

    @Published private(set) var projectiles: [Projectile] = []
    private var nextProjectileID = 0
    private var nextFireTickBySlot: [Int: Int64] = [:]
    private var lastStepGameTicks: Double = 0

    @Published private(set) var placedTowers: [PlacedTower] = []

    @Published private(set) var selectedSlotIndex: Int?

    @Published private(set) var selectedTowerSlotIndex: Int?

    @Published private(set) var walkers: [Walker] = []
    private var nextWalkerID = 0

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
    private var levelName = ""
    private var enemyTypesByID: [UUID: EnemyType] = [:]
    private var waves: [Wave] = []
    private var waveIndex = 0

    var waveCount: Int { waves.count }
    var currentWaveNumber: Int { min(waveIndex + 1, max(waves.count, 1)) }

    private static func assetName(for enemyName: String) -> String {
        enemyName.folding(options: .diacriticInsensitive, locale: .init(identifier: "en_US"))
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
    }

    private let timer = Timer(tickDuration: LevelRunner.normalTickDuration)
    private var displayLink: CADisplayLink?

    private let enemyHPMultiplier: Double

    init(levelInfoID: UUID?, mapImageName: String,
         enemyHPMultiplier: Double = 1.0) {
        self.mapImageName = mapImageName
        self.playableRect = CanvasSpec.playable
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
            let db = Db(
                dbPath: Db.getAbsolutePathToDb(dbFilename: "in_defense_of_history", fullRefresh: true),
                fullRefresh: true
            )
            let level = try db.levelInfoDao.getBy(id: levelInfoID)
            let enemies = try db.enemyTypeDao.getAll()

            let unlockRows = try db.towerUnlockDao.getUnlocksFor(levelInfoId: levelInfoID)
            towerUnlocks = Dictionary(uniqueKeysWithValues: unlockRows.compactMap { key, value in
                TowerKind(rawValue: key).map { ($0, value) }
            })

            levelName = level.name
            playableRect = level.playableRect
            if !level.mapImageName.isEmpty {
                mapImageName = level.mapImageName
            }
            startingMoney = level.startingMoney
            money = level.startingMoney
            startingLives = level.numStartingLives
            lives = level.numStartingLives

            let costRows = try db.towerTypeDao.getCostsByLevel()
            towerCosts = Dictionary(uniqueKeysWithValues: costRows.compactMap { category, levels in
                TowerKind(categoryName: category).map { ($0, levels) }
            })

            let nameRows = try db.towerTypeDao.getDisplayNames()
            towerDisplayNames = Dictionary(uniqueKeysWithValues: nameRows.compactMap { category, name in
                TowerKind(categoryName: category).map { ($0, name) }
            })

            let levelNameRows = try db.towerTypeDao.getNamesByLevel()
            towerNames = Dictionary(uniqueKeysWithValues: levelNameRows.compactMap { category, levels in
                TowerKind(categoryName: category).map { ($0, levels) }
            })

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
            precomputeLaneCoverage()
            isReady = true
            enterWave(0)
        } catch {
            status = "Database load failed: \(error)"
        }
    }

    func isSlotOccupied(_ index: Int) -> Bool {
        placedTowers.contains { $0.slotIndex == index }
    }

    func placedTower(atSlot index: Int) -> PlacedTower? {
        placedTowers.first { $0.slotIndex == index }
    }

    func maxLevel(for kind: TowerKind) -> Int {
        towerUnlocks[kind] ?? 0
    }

    func selectSlot(_ index: Int) {
        guard !isSlotOccupied(index) else { return }
        selectedTowerSlotIndex = nil
        selectedSlotIndex = selectedSlotIndex == index ? nil : index
    }

    func selectPlacedTower(atSlot index: Int) {
        guard isSlotOccupied(index) else { return }
        selectedSlotIndex = nil
        selectedTowerSlotIndex = selectedTowerSlotIndex == index ? nil : index
    }

    func dismissMenu() {
        selectedSlotIndex = nil
        selectedTowerSlotIndex = nil
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
        placedTowers.append(PlacedTower(
            slotIndex: slotIndex,
            kind: kind,
            position: slotPositions[slotIndex]
        ))
        selectedSlotIndex = nil
    }

    var upgradeOffers: [(nextLevel: Int, branch: Int, cost: Int)] {
        guard let slotIndex = selectedTowerSlotIndex,
              let tower = placedTower(atSlot: slotIndex) else { return [] }
        let next = tower.level + 1
        guard next <= maxLevel(for: tower.kind),
              let branches = towerCosts[tower.kind]?[next] else { return [] }
        return branches.keys.sorted().compactMap { branch in
            branches[branch].map { (next, branch, $0) }
        }
    }

    func upgradeSelectedTower(branch: Int = 1) {
        guard let slotIndex = selectedTowerSlotIndex,
              let offer = upgradeOffers.first(where: { $0.branch == branch }),
              let arrayIndex = placedTowers.firstIndex(where: { $0.slotIndex == slotIndex })
        else { return }
        placedTowers[arrayIndex].level = offer.nextLevel
        placedTowers[arrayIndex].branch = offer.branch
        selectedTowerSlotIndex = nil
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
        pendingSpawns = scheduled.sorted { $0.tick < $1.tick }

        walkers.removeAll()
        projectiles.removeAll()
        status = "\(levelName)  •  wave \(index + 1)/\(waves.count)  •  "
            + "\(pendingSpawns.count) enemies"
    }

    func start() {
        guard isReady, !isDefeated, displayLink == nil else { return }
        timer.resync()
        lastStepGameTicks = Double(timer.tick) + timer.interpolationAlpha
        enterWave(waveIndex)
        let link = CADisplayLink(target: self, selector: #selector(handleFrame))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func loseLife() {
        guard !isDefeated else { return }
        lives = max(0, lives - 1)
        guard lives == 0 else { return }
        isDefeated = true
        pendingSpawns.removeAll()
        stop()
    }

    func speedUp() {
        timer.setTickDuration(timer.tickDuration / 2)
        speedMultiplier *= 2
    }

    @objc private func handleFrame() {
        step()
    }

    private func step() {
        guard !paths.isEmpty, !isDefeated else { return }

        for _ in 0..<timer.dueTicks() {
            timer.advanceTick()
        }
        refreshTowerStatsIfDue()

        while let next = pendingSpawns.first, timer.tick >= next.tick {
            pendingSpawns.removeFirst()
            guard let type = enemyTypesByID[next.enemyTypeID] else { continue }
            let stats = type.stats
            let maxHP = stats.maxHP * enemyHPMultiplier
            walkers.append(Walker(
                id: nextWalkerID,
                assetName: Self.assetName(for: type.name),
                speed: stats.speed,
                maxHP: maxHP,
                hp: maxHP,
                bounty: stats.gold,
                spawnTick: next.tick,
                pathIndex: next.pathIndex
            ))
            nextWalkerID += 1
        }

        let alpha = timer.interpolationAlpha
        var marching: [Walker] = []
        for var walker in walkers {
            let ticksWalking = Double(timer.tick - walker.spawnTick) + alpha
            let distance = walker.speed * ticksWalking * SimClock.dt
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

        guard !isDefeated else { return }

        if pendingSpawns.isEmpty && walkers.isEmpty {
            if waveIndex + 1 < waves.count {
                enterWave(waveIndex + 1)
            } else if !isCleared {
                isCleared = true
                status = "\(levelName)  •  all \(waves.count) waves cleared"
            }
        }

        let nowTicks = Double(timer.tick) + timer.interpolationAlpha
        let gameDt = max(0, nowTicks - lastStepGameTicks) * SimClock.dt
        lastStepGameTicks = nowTicks
        updateCombat(gameDt: gameDt)
    }

    private func bodyPoint(_ walker: Walker) -> CGPoint {
        CGPoint(x: walker.position.x, y: walker.position.y - 12)
    }

    private func updateCombat(gameDt: Double) {
        guard !walkers.isEmpty else {
            if !projectiles.isEmpty { projectiles.removeAll() }
            return
        }

        let candidates = targetCandidates()

        for tower in placedTowers where tower.kind.projectileAssetName != nil {
            guard let tuning = towerLevel(for: tower) else { continue }
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

            // Engaged this tick, whether or not the gun is off cooldown.
            targetingSecondsBySlot[tower.slotIndex, default: 0] += gameDt

            guard timer.tick >= nextFireTickBySlot[tower.slotIndex, default: 0] else { continue }

            let target = bodyPoint(leader)
            nextFireTickBySlot[tower.slotIndex] = timer.tick + fireCooldownTicks(for: tower)
            let minDamage = tuning.shotMinDamage
            let maxDamage = max(minDamage, tuning.shotMaxDamage)
            projectiles.append(Projectile(
                id: nextProjectileID,
                kind: tower.kind,
                position: origin,
                heading: atan2(target.y - origin.y, target.x - origin.x),
                damage: Double.random(in: minDamage...maxDamage),
                targetID: leader.id,
                slotIndex: tower.slotIndex,
                speed: CGFloat(tuning.projectileSpeed),
                splashRadius: CGFloat(tuning.aoeRadius)
            ))
            nextProjectileID += 1
        }

        var survivors: [Projectile] = []
        for var projectile in projectiles {
                guard let target = walkers.first(where: { $0.id == projectile.targetID })
            else { continue }

            let stepLength = projectile.speed * CGFloat(gameDt)
            let aim = bodyPoint(target)
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
                            morale: Tunables.moraleMax,
                            isBroken: false)
        }
    }

    private func applyImpact(_ projectile: Projectile, at point: CGPoint) {
        var remaining: [Walker] = []
        for var walker in walkers {
            let isHit: Bool
            if projectile.kind == .areaOfEffect {
                isHit = distanceFrom(point, to: walker) <= projectile.splashRadius
            } else {
                isHit = walker.id == projectile.targetID
            }
            if isHit {
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
}
