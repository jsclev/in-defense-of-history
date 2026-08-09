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

    var fireCooldownTicks: Int64 {
        self == .areaOfEffect ? 72 : 24
    }

    func projectileDamage(atLevel level: Int) -> Double {
        switch self {
        case .ranged: return [1: 12, 2: 20, 3: 30, 4: 45][level] ?? 12
        case .areaOfEffect: return [1: 18, 2: 28, 3: 40][level] ?? 18
        case .melee, .special: return 0
        }
    }

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
    private(set) var mapImageSize: CGSize
    private(set) var mapImageName: String
    private(set) var playableRect: CGRect
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

    private static let attackRangeInImagePixels: CGFloat = 260
    private static let projectileSpeedPerSecond: CGFloat = 520
    private static let projectileHitRadiusInImagePixels: CGFloat = 10
    private static let muzzleOffsetInImagePixels: CGFloat = 35
    private static let splashRadiusInImagePixels: CGFloat = 55

    /// Where shots leave a tower, in map image pixels. Targeting measures from
    /// here rather than the tower's base, so the debug ring is centred here too.
    func muzzlePoint(for tower: PlacedTower) -> CGPoint {
        CGPoint(x: tower.position.x,
                y: tower.position.y - Self.muzzleOffsetInImagePixels)
    }

    /// Firing range in map image pixels. `updateCombat` and the debug range
    /// overlay both read this, so the ring always draws what actually shoots.
    func attackRange(for tower: PlacedTower) -> CGFloat {
        Self.attackRangeInImagePixels
    }

    /// Whether `tower` uses `attackRange` — only kinds that fire a projectile
    /// do, so the debug ring stays off the kinds it would misrepresent.
    func hasAttackRange(_ tower: PlacedTower) -> Bool {
        tower.kind.projectileAssetName != nil
    }

    struct Projectile: Identifiable {
        let id: Int
        let kind: TowerKind
        var position: CGPoint
        var heading: CGFloat
        let damage: Double
        let targetID: Int
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

    init(levelInfoID: UUID?, mapImageName: String, mapImageSize: CGSize) {
        self.mapImageName = mapImageName
        self.mapImageSize = mapImageSize
        self.playableRect = CGRect(origin: .zero, size: mapImageSize)
        super.init()
        load(levelInfoID: levelInfoID)
    }

    private func load(levelInfoID: UUID?) {
        guard let levelInfoID else {
            status = "This campaign node has no level_info id."
            return
        }
        guard Bundle.main.url(forResource: "redcoat_raid", withExtension: "sqlite") != nil else {
            status = "redcoat_raid.sqlite is not in the app bundle."
            return
        }

        do {
            let db = Db(
                dbPath: Db.getAbsolutePathToDb(dbFilename: "redcoat_raid", fullRefresh: true),
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
            if !level.mapImageName.isEmpty,
               level.mapImageSize.width > 0, level.mapImageSize.height > 0 {
                mapImageName = level.mapImageName
                mapImageSize = level.mapImageSize
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

        while let next = pendingSpawns.first, timer.tick >= next.tick {
            pendingSpawns.removeFirst()
            guard let type = enemyTypesByID[next.enemyTypeID] else { continue }
            let stats = type.stats
            walkers.append(Walker(
                id: nextWalkerID,
                assetName: Self.assetName(for: type.name),
                speed: stats.speed,
                maxHP: stats.maxHP,
                hp: stats.maxHP,
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

        for tower in placedTowers where tower.kind.projectileAssetName != nil {
            guard timer.tick >= nextFireTickBySlot[tower.slotIndex, default: 0] else { continue }
            let muzzle = muzzlePoint(for: tower)
            guard let closest = walkers.min(by: {
                distanceFrom(muzzle, to: $0) < distanceFrom(muzzle, to: $1)
            }), distanceFrom(muzzle, to: closest) <= attackRange(for: tower)
            else { continue }

            let target = bodyPoint(closest)
            nextFireTickBySlot[tower.slotIndex] = timer.tick + tower.kind.fireCooldownTicks
            projectiles.append(Projectile(
                id: nextProjectileID,
                kind: tower.kind,
                position: muzzle,
                heading: atan2(target.y - muzzle.y, target.x - muzzle.x),
                damage: tower.kind.projectileDamage(atLevel: tower.level),
                targetID: closest.id
            ))
            nextProjectileID += 1
        }

        let stepLength = Self.projectileSpeedPerSecond * CGFloat(gameDt)
        var survivors: [Projectile] = []
        for var projectile in projectiles {
                guard let target = walkers.first(where: { $0.id == projectile.targetID })
            else { continue }

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

    private func applyImpact(_ projectile: Projectile, at point: CGPoint) {
        var remaining: [Walker] = []
        for var walker in walkers {
            let isHit: Bool
            if projectile.kind == .areaOfEffect {
                isHit = distanceFrom(point, to: walker) <= Self.splashRadiusInImagePixels
            } else {
                isHit = walker.id == projectile.targetID
            }
            if isHit {
                walker.hp -= projectile.damage
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
