import Foundation
import CoreGraphics
import Combine
import QuartzCore
import UIKit

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

    /// The level's art layers, probed once when the level loads so the
    /// per-frame render never re-asks the asset library which layers exist.
    private(set) var mapArt: LevelMapArt
    private(set) var playArea: CGRect

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

    /// True while the level is holding a wave for the player. Nothing
    /// spawns until an entrance icon is double-tapped, which calls
    /// startNextWave() and releases it.
    @Published private(set) var awaitingWaveStart = false

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

    /// Half-width of the enemy lane, in canonical units, from
    /// canvas_spec.path_width.
    private static var pathHalfWidthInImagePixels: CGFloat { CanvasSpec.pathWidth / 2 }

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
        let damageMin: Double
        let damageMax: Double
        let cover: Double
        let blockImmune: Bool
        let spawnTick: Int64
        let pathIndex: Int
        var position: CGPoint = .zero
        var pathDistance: Double = 0
        /// Ticks spent standing still while a militia soldier blocked the way;
        /// subtracted from the analytic march so the walker resumes where it
        /// stopped instead of teleporting ahead.
        var haltedTicks: Double = 0
    }

    struct MilitiaSoldier: Identifiable {
        let id: Int
        let assetName: String
        var position: CGPoint
        var hp: Double
        var maxHP: Double
    }

    private struct MilitiaGarrison {
        var rallyPoint: Point
        var units: [MilitiaUnit]
        var enemySwingTicks: [Int: Int] = [:]
    }

    @Published private(set) var projectiles: [Projectile] = []
    private var nextProjectileID = 0
    private var nextFireTickBySlot: [Int: Int64] = [:]
    private var lastStepGameTicks: Double = 0

    @Published private(set) var placedTowers: [PlacedTower] = []

    @Published private(set) var selectedSlotIndex: Int?

    @Published private(set) var selectedTowerSlotIndex: Int?

    /// Build choice awaiting its confirming second tap: the first tap on a
    /// tower button arms it (checkmark + range preview), the second builds.
    @Published private(set) var armedBuildKind: TowerKind?

    /// Upgrade branch awaiting its confirming second tap, same flow as
    /// armedBuildKind: the range preview shows the upgraded tier's range.
    @Published private(set) var armedUpgradeBranch: Int?

    @Published private(set) var walkers: [Walker] = []
    private var nextWalkerID = 0

    @Published private(set) var militia: [MilitiaSoldier] = []
    private var garrisonsBySlot: [Int: MilitiaGarrison] = [:]
    private var blockedWalkerIDs: Set<Int> = []
    private var lastMilitiaTick: Int64 = 0
    /// Soldier positions at the previous militia tick, keyed by soldier id.
    /// Militia step on 30Hz whole ticks; the published positions lerp between
    /// the last two ticks so they glide like the frame-interpolated walkers.
    private var militiaPrevPositions: [Int: CGPoint] = [:]
    private var militiaRespawnedIDs: Set<Int> = []
    private static let militiaAssetName = "militia_soldier"

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

    /// Where the held wave's enemies will enter the map, in canonical
    /// units: the mouth of each path that wave actually spawns on, not
    /// every path the level has. The level screen puts an entrance icon on
    /// each while the wave is waiting.
    var entrancePositions: [CGPoint] {
        guard waves.indices.contains(waveIndex) else { return [] }
        return Set(waves[waveIndex].spawns.map(\.pathIndex))
            .filter { paths.indices.contains($0) }
            .sorted()
            .map { CGPoint(x: paths[$0].points[0].x, y: paths[$0].points[0].y) }
    }

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
        self.mapArt = LevelMapArt(mapImageName: mapImageName)
        self.playArea = CanvasSpec.playArea
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
            holdWave(0)
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
        armedBuildKind = nil
        armedUpgradeBranch = nil
        selectedSlotIndex = selectedSlotIndex == index ? nil : index
    }

    func selectPlacedTower(atSlot index: Int) {
        guard isSlotOccupied(index) else { return }
        selectedSlotIndex = nil
        armedBuildKind = nil
        armedUpgradeBranch = nil
        selectedTowerSlotIndex = selectedTowerSlotIndex == index ? nil : index
    }

    func dismissMenu() {
        selectedSlotIndex = nil
        selectedTowerSlotIndex = nil
        armedBuildKind = nil
        armedUpgradeBranch = nil
    }

    /// First tap on a build button arms that kind; a second tap on the same
    /// button builds it. Tapping a different button re-arms to that kind.
    func tapBuildButton(_ kind: TowerKind) {
        guard maxLevel(for: kind) >= 1 else { return }
        if armedBuildKind == kind {
            buildTower(kind)
        } else {
            armedBuildKind = kind
        }
    }

    /// Radius previewed while a build choice is armed: attack range for
    /// shooting towers, rally-point radius for melee.
    func buildPreviewRadius(for kind: TowerKind) -> CGFloat? {
        towerLevels[kind]?[1]?[1].flatMap(Self.overlayRadius)
    }

    /// Radius shown while a placed tower's upgrade menu is open, at the
    /// tower's current level and branch.
    func rangeOverlayRadius(for tower: PlacedTower) -> CGFloat? {
        towerLevel(for: tower).flatMap(Self.overlayRadius)
    }

    /// First tap on an upgrade button arms that branch; a second tap on the
    /// same button performs the upgrade. Tapping a different branch re-arms.
    func tapUpgradeButton(branch: Int) {
        guard upgradeOffers.contains(where: { $0.branch == branch }) else { return }
        if armedUpgradeBranch == branch {
            upgradeSelectedTower(branch: branch)
        } else {
            armedUpgradeBranch = branch
        }
    }

    /// Radius previewed while an upgrade is armed: what the tower's range
    /// would become at the offered level and branch.
    func upgradePreviewRadius(branch: Int) -> CGFloat? {
        guard let slotIndex = selectedTowerSlotIndex,
              let tower = placedTower(atSlot: slotIndex),
              let offer = upgradeOffers.first(where: { $0.branch == branch })
        else { return nil }
        return towerLevels[tower.kind]?[offer.nextLevel]?[offer.branch]
            .flatMap(Self.overlayRadius)
    }

    private static func overlayRadius(for tuning: TowerLevel) -> CGFloat? {
        if let melee = tuning.meleeUnit { return CGFloat(melee.rallyPointRadius) }
        return tuning.range > 0 ? CGFloat(tuning.range) : nil
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
        let tower = PlacedTower(
            slotIndex: slotIndex,
            kind: kind,
            position: slotPositions[slotIndex]
        )
        placedTowers.append(tower)
        if let melee = towerLevel(for: tower)?.meleeUnit {
            let towerPos = Point(Double(tower.position.x), Double(tower.position.y))
            let rally = Simulation.defaultRallyPoint(
                towerPosition: towerPos,
                flagRange: melee.rallyPointRadius,
                paths: paths)
            garrisonsBySlot[slotIndex] = MilitiaGarrison(
                rallyPoint: rally,
                units: (0..<melee.soldierCount).map { _ in
                    MilitiaUnit(position: towerPos, hp: melee.hp)
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
        guard next <= maxLevel(for: tower.kind),
              let branches = towerCosts[tower.kind]?[next] else { return [] }
        return branches.keys.sorted().compactMap { branch in
            branches[branch].map { (next, branch, $0) }
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
        if var g = garrisonsBySlot[slotIndex],
           let melee = towerLevel(for: placedTowers[arrayIndex])?.meleeUnit {
            // Upgrading re-equips the garrison: living soldiers come back at
            // the new tier's full hp; the dead keep their respawn timers.
            for i in 0..<g.units.count where g.units[i].state != .dead {
                g.units[i].hp = melee.hp
            }
            garrisonsBySlot[slotIndex] = g
            publishMilitia()
        }
        selectedTowerSlotIndex = nil
        armedUpgradeBranch = nil
    }

    /// Parks the level on wave `index`: the wave is announced, but nothing
    /// spawns until startNextWave() releases it.
    private func holdWave(_ index: Int) {
        guard waves.indices.contains(index) else { return }
        waveIndex = index
        awaitingWaveStart = true
        status = "\(levelName)  •  wave \(index + 1)/\(waves.count) waiting  •  "
            + "double-tap an entrance to start it"
    }

    /// Releases the held wave. The entrance icons call this on a
    /// double-tap; until then the level sits quiet.
    func startNextWave() {
        guard awaitingWaveStart, isReady, !isDefeated else { return }
        awaitingWaveStart = false
        enterWave(waveIndex)
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
        lastMilitiaTick = timer.tick
        // A held wave stays held; a wave already in flight reschedules
        // against the resynced clock, exactly as before the gate existed.
        if !awaitingWaveStart {
            enterWave(waveIndex)
        }
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
                damageMin: stats.damageMin,
                damageMax: stats.damageMax,
                cover: stats.cover,
                blockImmune: type.traits.contains(.rideDown),
                spawnTick: next.tick,
                pathIndex: next.pathIndex
            ))
            nextWalkerID += 1
        }

        let alpha = timer.interpolationAlpha
        let nowTicks = Double(timer.tick) + alpha
        let frameDtTicks = max(0, nowTicks - lastStepGameTicks)
        lastStepGameTicks = nowTicks

        var marching: [Walker] = []
        for var walker in walkers {
            if blockedWalkerIDs.contains(walker.id) {
                walker.haltedTicks += frameDtTicks
                marching.append(walker)
                continue
            }
            let ticksWalking = Double(timer.tick - walker.spawnTick) + alpha
                - walker.haltedTicks
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

        stepMilitia()
        if !garrisonsBySlot.isEmpty {
            publishMilitia(alpha: alpha)
        }

        if pendingSpawns.isEmpty && walkers.isEmpty && !awaitingWaveStart {
            if waveIndex + 1 < waves.count {
                holdWave(waveIndex + 1)
            } else if !isCleared {
                isCleared = true
                status = "\(levelName)  •  all \(waves.count) waves cleared"
            }
        }

        updateCombat(gameDt: frameDtTicks * SimClock.dt)
    }

    /// Mirrors Engine Simulation.stepMilitia on the runner's walkers, run on
    /// whole ticks so the Int swing/respawn counters keep engine cadence.
    private func stepMilitia() {
        guard timer.tick > lastMilitiaTick else { return }
        let dueTicks = min(Int(timer.tick - lastMilitiaTick), 8)
        lastMilitiaTick = timer.tick
        guard !garrisonsBySlot.isEmpty else {
            blockedWalkerIDs.removeAll()
            return
        }
        militiaPrevPositions = militiaPositionsById()
        militiaRespawnedIDs.removeAll()
        for _ in 0..<dueTicks {
            stepMilitiaTick()
        }
        if !militiaRespawnedIDs.isEmpty {
            let now = militiaPositionsById()
            for id in militiaRespawnedIDs {
                militiaPrevPositions[id] = now[id]
            }
        }
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

    private func stepMilitiaTick() {
        let dt = SimClock.dt

        var claimed: Set<Int> = []
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
                  let tower = placedTower(atSlot: slot),
                  let melee = towerLevel(for: tower)?.meleeUnit
            else { continue }
            let towerPos = Point(Double(tower.position.x), Double(tower.position.y))

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
                let offset = MilitiaAI.formationOffset(index: ui, of: g.units.count)
                let context = MilitiaContext(
                    freeEnemies: free,
                    targetPosition: targetPos,
                    rallyPoint: Point(g.rallyPoint.x + offset.x, g.rallyPoint.y + offset.y),
                    towerPosition: towerPos)
                if unit.swingTicksLeft > 0 { unit.swingTicksLeft -= 1 }

                switch MilitiaAI.decide(unit, context: context) {
                case .idle:
                    if unit.state == .returning { unit.state = .holding }
                case .countdownRespawn:
                    unit.respawnTicksLeft -= 1
                case .respawn:
                    unit = MilitiaUnit(position: towerPos, hp: melee.hp)
                    militiaRespawnedIDs.insert(slot * 8 + ui)
                case .heal:
                    unit.hp = min(melee.hp, unit.hp + melee.healPerSecond * dt)
                case let .move(toward):
                    let d = unit.position.distance(to: toward)
                    let step = MilitiaTunables.moveSpeed * dt
                    unit.position = d <= step ? toward
                        : Point.lerp(unit.position, toward, step / d)
                case let .engage(targetSpawnID):
                    unit.state = .engaging
                    unit.targetSpawnID = targetSpawnID
                    claimed.insert(targetSpawnID)
                    free.removeAll { $0.spawnID == targetSpawnID }
                case let .strike(targetSpawnID):
                    if unit.state == .engaging {
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
                        unit.hp -= Double.random(in: w.damageMin...w.damageMax)
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

        if !killedIDs.isEmpty {
            walkers.removeAll { killedIDs.contains($0.id) }
        }
    }

    private func publishMilitia(alpha: Double = 1) {
        var out: [MilitiaSoldier] = []
        for slot in garrisonsBySlot.keys.sorted() {
            guard let g = garrisonsBySlot[slot],
                  let tower = placedTower(atSlot: slot),
                  let melee = towerLevel(for: tower)?.meleeUnit
            else { continue }
            for (i, u) in g.units.enumerated() where u.state != .dead {
                let id = slot * 8 + i
                let cur = CGPoint(x: u.position.x, y: u.position.y)
                let prev = militiaPrevPositions[id] ?? cur
                out.append(MilitiaSoldier(
                    id: id,
                    assetName: Self.militiaAssetName,
                    position: CGPoint(x: prev.x + (cur.x - prev.x) * alpha,
                                      y: prev.y + (cur.y - prev.y) * alpha),
                    hp: u.hp,
                    maxHP: melee.hp))
            }
        }
        militia = out
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
