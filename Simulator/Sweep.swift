import Foundation
import CoreGraphics

struct SweepFixedInputs {
    let combatRules: CombatRules
    var levelID: UUID
    var levelName: String
    var lives: Int
    var numWaves: Int
    var unlocks: [String: Int]
    var towerLevels: [String: [TowerLevel]]
    var towerNames: [String: String]
    var towerIDs: [String: UUID]
    var roster: [EnemyType]
    var bounds: [String: [String: SimStatBounds]]
    var speedBounds: [UUID: ClosedRange<Double>]
    var hpBounds: [UUID: ClosedRange<Double>]
    var bountyBounds: [UUID: ClosedRange<Double>]
    var meleeBrackets: [String: [Int: SimMeleeBrackets]]
    /// Range search bounds from sim_tower_range, keyed kind then tower level.
    /// The sweep walks every integer between them; there is no grid in Swift.
    var towerRanges: [String: [Int: SimTowerRange]]
    var fieldMelee: Bool

    /// The sweep's designer-fixed inputs for one level, read from the database.
    init(db: Db, levelName: String, fieldMelee: Bool = false) throws {
        func normalizeKind(_ s: String) -> String {
            switch s.lowercased() {
            case "ranged": return "ranged"
            case "melee": return "melee"
            case "area of effect", "areaofeffect": return "areaOfEffect"
            case "special", "special forces": return "special"
            default: return s
            }
        }
        guard let levelID = try db.levelInfoDao.getIdBy(levelName: levelName) else {
            throw DbError.Db(message: "No level named '\(levelName)' in the database")
        }
        let level = try db.levelLoader.load(id: levelID)
        let arsenal = try db.towerTypeDao.getDesignArsenal()
        let towerLevels = Dictionary(uniqueKeysWithValues: arsenal.towers.map { ($0.kind.rawValue, $0.type.levels) })
        let towerNames = Dictionary(uniqueKeysWithValues: arsenal.towers.map { ($0.kind.rawValue, $0.name) })
        self.towerIDs = Dictionary(uniqueKeysWithValues: arsenal.towers.map { ($0.kind.rawValue, $0.id) })
        var meleeBrackets: [String: [Int: SimMeleeBrackets]] = [:]
        for (category, byLevel) in try db.simMeleeUnitDao.getBrackets() {
            meleeBrackets[normalizeKind(category)] = byLevel
        }
        var towerRanges: [String: [Int: SimTowerRange]] = [:]
        for (category, byLevel) in try db.simBoundsDao.getTowerRanges() {
            towerRanges[normalizeKind(category)] = byLevel
        }

        self.combatRules = arsenal.combatRules
        self.levelID = levelID
        self.levelName = levelName
        self.lives = level.numStartingLives
        self.numWaves = level.numWaves > 0 ? level.numWaves : level.waves.count
        self.unlocks = try db.towerUnlockDao.getUnlocksFor(levelInfoId: levelID).filter { $0.value > 0 }
        for (kind, count) in self.unlocks {
            guard let levels = towerLevels[kind], !levels.isEmpty, count > 0 else {
                throw DbError.Db(message: "Missing authored tower levels for simulator kind '\(kind)'")
            }
            if fieldMelee {
                for (index, tuning) in levels.prefix(count).enumerated() where tuning.meleeUnit != nil {
                    guard meleeBrackets[kind]?[index + 1] != nil else {
                        throw DbError.Db(message: "Missing sim_melee_unit for '\(kind)', tier \(index + 1)")
                    }
                }
            }
        }
        self.towerLevels = towerLevels
        self.towerNames = towerNames
        self.roster = try db.enemyTypeDao.getAll()
        self.bounds = try db.simBoundsDao.getBoundsFor(levelInfoId: levelID)
        self.speedBounds = try db.simEnemyTypeDao.getSpeedBounds()
        self.hpBounds = try db.simEnemyTypeDao.getHpBounds()
        self.bountyBounds = try db.simEnemyTypeDao.getBountyBounds()
        self.meleeBrackets = meleeBrackets
        self.towerRanges = towerRanges
        self.fieldMelee = fieldMelee
    }

    func requiredLevels(for kind: String) -> [TowerLevel] {
        guard let levels = towerLevels[kind], !levels.isEmpty else {
            fatalError("Missing authored tower levels for simulator kind '\(kind)'")
        }
        return levels
    }

    func designLevel(db: Db) throws -> LevelInfo {
        let level = try db.levelLoader.load(id: levelID)
        guard !level.paths.isEmpty, !level.towerSlots.isEmpty else {
            throw DbError.Db(message: "Level '\(levelName)' needs database paths and GeoJSON tower slots")
        }
        let paths = level.paths.map { Path(points: simplify($0.points, maxPoints: 16)) }
        return LevelInfo(
            id: level.id, name: level.name, campaign: level.campaign,
            startedAt: level.startedAt, endedAt: level.endedAt,
            startingMoney: level.startingMoney, numStartingLives: level.numStartingLives,
            numWaves: numWaves,
            playArea: level.playArea,
            paths: paths, towerSlots: level.towerSlots, waves: []
        )
    }

    private func simplify(_ points: [Point], maxPoints: Int) -> [Point] {
        guard points.count > maxPoints else { return points }
        var epsilon = 2.0
        var result = points
        while result.count > maxPoints && epsilon < 500 {
            result = rdp(points, epsilon: epsilon)
            epsilon *= 1.5
        }
        if result.count > maxPoints {
            let step = Double(points.count - 1) / Double(maxPoints - 1)
            result = (0..<maxPoints).map { points[Int((Double($0) * step).rounded())] }
        }
        return result
    }

    private func rdp(_ points: [Point], epsilon: Double) -> [Point] {
        guard points.count > 2 else { return points }
        let a = points[0]
        let b = points[points.count - 1]
        var maxDist = 0.0
        var maxIndex = 0
        for i in 1..<(points.count - 1) {
            let d = points[i].distance(toSegment: a, b)
            if d > maxDist { maxDist = d; maxIndex = i }
        }
        if maxDist > epsilon {
            let left = rdp(Array(points[0...maxIndex]), epsilon: epsilon)
            let right = rdp(Array(points[maxIndex...]), epsilon: epsilon)
            return left.dropLast() + right
        }
        return [a, b]
    }
}

struct SweepFocus {
    var stat: String
    var kind: String
    var label: String { kind.isEmpty ? stat : "\(stat):\(kind)" }
}

struct SweepGrids {
    var upgradeGrowth: [Double]
    var rofGrids: [String: [Double]]
    var splashGrids: [String: [Double]]
    var falloffGrid: [Double]
    var projSpeedGrids: [String: [Double]]
    var rangeModes: [String: String]

    init(dao: SimTowerSweepDAO, profile: String) throws {
        let tuning = try dao.get(profile: profile)
        upgradeGrowth = tuning.upgradeGrowth
        rofGrids = tuning.rof
        splashGrids = tuning.splash
        falloffGrid = tuning.falloff
        projSpeedGrids = tuning.projectileSpeed
        rangeModes = tuning.rangeModes
    }
    var fixedRange: [String: Double] = [:]
    var fixedRof: [String: Double] = [:]
    var fixedGrowth: [String: Double] = [:]
    var fixedSplash: [String: Double] = [:]
    var fixedFalloff: [String: Double] = [:]
    var fixedProjSpeed: [String: Double] = [:]
    var fixedMoney: Int?
    var fixedCurve: String?
    var fixedMix: String?
    var fixedSpacing: String?
    var enemySpeedGrid: [Double] = [0, 0.25, 0.5, 0.75, 1.0]
    var fixedEnemySpeed: Double?
    var enemyHpGrid: [Double] = [0, 0.25, 0.5, 0.75, 1.0]
    var fixedEnemyHp: Double?
    var enemyBountyGrid: [Double] = [0, 0.25, 0.5, 0.75, 1.0]
    var fixedEnemyBounty: Double?
    var meleeHpGrid: [Double] = [0, 0.25, 0.5, 0.75, 1.0]
    var fixedMeleeHp: Double?
    var meleeDamageGrid: [Double] = [0, 0.25, 0.5, 0.75, 1.0]
    var fixedMeleeDamage: Double?
    var focus: SweepFocus?
    var rangeGridOverride: [String: [Double]] = [:]
    var moneyGridOverride: [Int]?
    var reportDir = ""
    var limit: Int?
    var boundsStep: Double = 0
    var startingMoneyStep = 5
    var livesGrid: [Int] = [1, 10, 20, 35, 50]
    var fixedLives: Int?
    var probeSeeds = 8
    var budgetHours = 8.0
    var compCurves = ["gentle", "standard", "steep"]
    var compMixes = ["swarm", "balanced", "elite", "combined"]
    var compSpacings = ["tight", "loose"]
    var seedsPerPermutation = 40
    var baseSeed: UInt64 = 1776
}

struct SweepSpace {
    var moneyValues: [Int]
    var combatKinds: [String]
    var aoeKinds: [String]
    var meleeFielded: Bool = false
    var fixedInputs: SweepFixedInputs
    var grids: SweepGrids
    var bounds: [String: [String: SimStatBounds]]
    var speedBounds: [UUID: ClosedRange<Double>]
    var hpBounds: [UUID: ClosedRange<Double>]
    var bountyBounds: [UUID: ClosedRange<Double>]

    init(grids: SweepGrids, fixed: SweepFixedInputs, slotCount: Int) {
        self.grids = grids
        self.fixedInputs = fixed
        self.bounds = fixed.bounds
        self.speedBounds = fixed.speedBounds
        self.hpBounds = fixed.hpBounds
        self.bountyBounds = fixed.bountyBounds
        self.combatKinds = fixed.unlocks.keys.sorted().filter { kind in
            let base = fixed.requiredLevels(for: kind)
            guard let count = fixed.unlocks[kind] else { fatalError("Missing tower unlock for '\(kind)'") }
            let capped = base.prefix(count)
            let ranged = capped.contains { $0.shotMaxDamage > 0 || $0.terrorMax > 0 || $0.contagionChance > 0 }
            let melee = fixed.fieldMelee && capped.contains { $0.meleeUnit != nil }
            return ranged || melee
        }
        self.meleeFielded = fixed.fieldMelee && combatKinds.contains { kind in
            fixed.requiredLevels(for: kind)[0].meleeUnit != nil
        }
        self.aoeKinds = combatKinds.filter { kind in
            fixed.requiredLevels(for: kind).contains { $0.aoeRadius > 0 }
        }
        guard let cheapest = combatKinds.map({ fixed.requiredLevels(for: $0)[0].cost }).min() else {
            fatalError("The simulator requires an authored, unlocked combat tower")
        }
        let minMoney = 3 * cheapest
        let maxMoney = cheapest * (slotCount / 2 + 1)
        if let pinned = grids.fixedMoney {
            self.moneyValues = [pinned]
        } else if let override = grids.moneyGridOverride {
            self.moneyValues = override
        } else {
            self.moneyValues = Array(Swift.stride(
                from: minMoney,
                through: max(minMoney, maxMoney),
                by: grids.startingMoneyStep
            ))
        }
    }

    var livesValues: [Int] {
        grids.fixedLives.map { [$0] } ?? grids.livesGrid
    }

    var enemySpeeds: [Double] {
        guard speedBounds.contains(where: { $0.value.upperBound > $0.value.lowerBound }) else { return [0.5] }
        return grids.fixedEnemySpeed.map { [$0] } ?? grids.enemySpeedGrid
    }

    var enemyHps: [Double] {
        guard hpBounds.contains(where: { $0.value.upperBound > $0.value.lowerBound }) else { return [0.5] }
        return grids.fixedEnemyHp.map { [$0] } ?? grids.enemyHpGrid
    }

    var enemyBounties: [Double] {
        guard bountyBounds.contains(where: { $0.value.upperBound > $0.value.lowerBound }) else { return [0.5] }
        return grids.fixedEnemyBounty.map { [$0] } ?? grids.enemyBountyGrid
    }

    var meleeHps: [Double] {
        guard meleeFielded else { return [0.5] }
        return grids.fixedMeleeHp.map { [$0] } ?? grids.meleeHpGrid
    }

    var meleeDamages: [Double] {
        guard meleeFielded else { return [0.5] }
        return grids.fixedMeleeDamage.map { [$0] } ?? grids.meleeDamageGrid
    }

    var curves: [String] { grids.fixedCurve.map { [$0] } ?? grids.compCurves }
    var mixes: [String] { grids.fixedMix.map { [$0] } ?? grids.compMixes }
    var spacings: [String] { grids.fixedSpacing.map { [$0] } ?? grids.compSpacings }

    func growthGrid(for kind: String) -> [Double] {
        grids.fixedGrowth[kind].map { [$0] } ?? grids.upgradeGrowth
    }

    private func isMeleeKind(_ kind: String) -> Bool {
        fixedInputs.requiredLevels(for: kind)[0].meleeUnit != nil
    }

    /// Every range the sweep tries for `kind`, as whole numbers.
    ///
    /// The values come from sim_tower_range: min through max, stepping by one.
    /// There is no hardcoded grid and no sample count - widening or narrowing
    /// the search is an edit to that table.
    func rangeGrid(for kind: String) -> [Double] {
        if isMeleeKind(kind) {
            return [fixedInputs.requiredLevels(for: kind)[0].range.rounded()]
        }
        if let override = grids.rangeGridOverride[kind] { return override }
        if let pinned = grids.fixedRange[kind] { return [pinned.rounded()] }
        if let b = bounds[kind]?["range"] {
            return gridFromBounds(b.minValue, b.maxValue, step: grids.boundsStep)
        }
        guard let mode = grids.rangeModes[kind] else { fatalError("Missing simulator range mode for '\(kind)'") }
        if mode == "authored" { return [fixedInputs.requiredLevels(for: kind)[0].range.rounded()] }
        guard let r = fixedInputs.towerRanges[kind]?[1] else {
            fatalError("Missing sim_tower_range for '\(kind)', tier 1")
        }
        return r.values.map(Double.init)
    }

    private func gridFromBounds(_ lo: Double, _ hi: Double, step: Double) -> [Double] {
        guard hi > lo else { return [lo] }
        if step > 0 {
            return Array(stride(from: lo, through: hi, by: step))
        }
        return (0..<5).map { lo + (hi - lo) * Double($0) / 4 }
            .map { ($0 / 5).rounded() * 5 }
    }

    func rofGrid(for kind: String) -> [Double] {
        if isMeleeKind(kind) {
            return [fixedInputs.requiredLevels(for: kind)[0].fireInterval]
        }
        if let fixed = grids.fixedRof[kind] { return [fixed] }
        guard let values = grids.rofGrids[kind] else { fatalError("Missing simulator rate of fire grid for '\(kind)'") }
        return values
    }

    func splashGrid(for kind: String) -> [Double] {
        if let fixed = grids.fixedSplash[kind] { return [fixed] }
        guard let values = grids.splashGrids[kind] else { fatalError("Missing simulator splash grid for '\(kind)'") }
        return values
    }

    func projSpeedGrid(for kind: String, fixed: SweepFixedInputs) -> [Double] {
        let base = fixed.requiredLevels(for: kind)[0]
        if base.projectileSpeed == 0 { return [base.projectileSpeed] }
        if let pinned = grids.fixedProjSpeed[kind] { return [pinned] }
        guard let values = grids.projSpeedGrids[kind] else { fatalError("Missing simulator projectile speed grid for '\(kind)'") }
        return values
    }

    func falloffGrid(for kind: String) -> [Double] {
        grids.fixedFalloff[kind].map { [$0] } ?? grids.falloffGrid
    }

    func dimensionLayout() -> [(stat: String, kind: String, count: Int)] {
        var dims: [(stat: String, kind: String, count: Int)] = [
            ("money", "", moneyValues.count),
            ("lives", "", livesValues.count),
        ]
        for kind in combatKinds {
            dims.append(("growth", kind, growthGrid(for: kind).count))
            dims.append(("range", kind, rangeGrid(for: kind).count))
            dims.append(("rof", kind, rofGrid(for: kind).count))
            dims.append(("projspeed", kind, projSpeedGrid(for: kind, fixed: fixedInputs).count))
        }
        for kind in aoeKinds {
            dims.append(("splash", kind, splashGrid(for: kind).count))
            dims.append(("falloff", kind, falloffGrid(for: kind).count))
        }
        dims.append(("enemyspeed", "", enemySpeeds.count))
        dims.append(("enemyhp", "", enemyHps.count))
        dims.append(("enemybounty", "", enemyBounties.count))
        dims.append(("meleehp", "", meleeHps.count))
        dims.append(("meleedamage", "", meleeDamages.count))
        dims.append(("curve", "", curves.count))
        dims.append(("mix", "", mixes.count))
        dims.append(("spacing", "", spacings.count))
        return dims
    }

    func focusPlacement(stat: String, kind: String) -> (place: Int, count: Int)? {
        var place = 1
        for dim in dimensionLayout() {
            if dim.stat == stat && dim.kind == kind { return (place, dim.count) }
            place *= dim.count
        }
        return nil
    }

    var permutationCount: Int {
        dimensionLayout().reduce(1) { $0 * $1.count }
    }

    func permutation(at index: Int) -> SweepPermutation {
        var r = index
        func nextIndex(_ count: Int) -> Int { let v = r % count; r /= count; return v }
        func pick(_ grid: [Double]) -> Double { grid[nextIndex(grid.count)] }
        let money = moneyValues[nextIndex(moneyValues.count)]
        let lives = livesValues[nextIndex(livesValues.count)]
        var growth: [String: Double] = [:]
        var range: [String: Double] = [:]
        var rof: [String: Double] = [:]
        var projSpeed: [String: Double] = [:]
        var splash: [String: Double] = [:]
        var falloff: [String: Double] = [:]
        for kind in combatKinds {
            growth[kind] = pick(growthGrid(for: kind))
            range[kind] = pick(rangeGrid(for: kind))
            rof[kind] = pick(rofGrid(for: kind))
            projSpeed[kind] = pick(projSpeedGrid(for: kind, fixed: fixedInputs))
        }
        for kind in aoeKinds {
            splash[kind] = pick(splashGrid(for: kind))
            falloff[kind] = pick(falloffGrid(for: kind))
        }
        let speedPosition = pick(enemySpeeds)
        let hpPosition = pick(enemyHps)
        let bountyPosition = pick(enemyBounties)
        let meleeHpPosition = pick(meleeHps)
        let meleeDamagePosition = pick(meleeDamages)
        return SweepPermutation(
            index: index,
            money: money,
            lives: lives,
            upgradeGrowth: growth,
            rangeByKind: range,
            rofByKind: rof,
            projSpeedByKind: projSpeed,
            splashByKind: splash,
            falloffByKind: falloff,
            enemySpeedBracketPosition: speedPosition,
            enemyHpBracketPosition: hpPosition,
            enemyBountyBracketPosition: bountyPosition,
            meleeHpBracketPosition: meleeHpPosition,
            meleeDamageBracketPosition: meleeDamagePosition,
            curve: curves[nextIndex(curves.count)],
            mix: mixes[nextIndex(mixes.count)],
            spacing: spacings[nextIndex(spacings.count)]
        )
    }
}

struct SweepPermutation {
    var index: Int
    var money: Int
    var lives: Int
    var upgradeGrowth: [String: Double]
    var rangeByKind: [String: Double]
    var rofByKind: [String: Double]
    var projSpeedByKind: [String: Double]
    var splashByKind: [String: Double]
    var falloffByKind: [String: Double]
    var enemySpeedBracketPosition: Double
    var enemyHpBracketPosition: Double
    var enemyBountyBracketPosition: Double
    var meleeHpBracketPosition: Double
    var meleeDamageBracketPosition: Double
    var curve: String
    var mix: String
    var spacing: String

    var growthLabel: String {
        upgradeGrowth.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ";")
    }

    var rangeLabel: String {
        rangeByKind.sorted { $0.key < $1.key }
            .map { "\($0.key)=\(Int($0.value))" }
            .joined(separator: ";")
    }

    var rofLabel: String {
        rofByKind.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ";")
    }

    var projSpeedLabel: String {
        projSpeedByKind.sorted { $0.key < $1.key }
            .map { "\($0.key)=\(Int($0.value))" }
            .joined(separator: ";")
    }

    var splashLabel: String {
        splashByKind.sorted { $0.key < $1.key }
            .map { "\($0.key)=\(Int($0.value))" }
            .joined(separator: ";")
    }

    var falloffLabel: String {
        falloffByKind.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ";")
    }
}

/// Builds the content catalog a permutation plays with: the fixed roster
/// and tower levels, bent by the permutation's swept values.
struct SweepCatalog {
    let fixed: SweepFixedInputs
    var kindIDs: [String: UUID] { fixed.towerIDs }

    init(fixed: SweepFixedInputs) {
        self.fixed = fixed
    }

    func make(perm: SweepPermutation) -> ContentCatalog {
        let roster = fixed.roster.map { type -> EnemyType in
            var t = type
            if let b = fixed.speedBounds[type.id] {
                t.stats.speed = b.lowerBound + perm.enemySpeedBracketPosition * (b.upperBound - b.lowerBound)
            }
            if let b = fixed.hpBounds[type.id] {
                t.stats.maxHP = b.lowerBound + perm.enemyHpBracketPosition * (b.upperBound - b.lowerBound)
            }
            if let b = fixed.bountyBounds[type.id] {
                t.stats.gold = Int((b.lowerBound + perm.enemyBountyBracketPosition * (b.upperBound - b.lowerBound)).rounded())
            }
            return t
        }
        var towers: [TowerType] = []
        for (kind, maxLevel) in fixed.unlocks {
            guard let id = kindIDs[kind] else { fatalError("Unsupported simulator tower kind '\(kind)'") }
            let baseLevels = fixed.requiredLevels(for: kind)
            let isMelee = baseLevels[0].meleeUnit != nil
            if isMelee {
                guard fixed.fieldMelee else { continue }
                guard let growth = perm.upgradeGrowth[kind] else { fatalError("Missing simulator growth for '\(kind)'") }
                let levels = baseLevels.prefix(maxLevel).enumerated().map { n, base -> TowerLevel in
                    var l = base
                    if n > 0 {
                        let raw = Double(baseLevels[0].cost) * pow(growth, Double(n))
                        l.cost = Int((raw / 5).rounded()) * 5
                    }
                    guard let b = fixed.meleeBrackets[kind]?[n + 1] else { fatalError("Missing simulator melee attributes for '\(kind)' tier \(n + 1)") }
                    l.meleeUnit?.hp = b.hp.lowerBound
                        + perm.meleeHpBracketPosition * (b.hp.upperBound - b.hp.lowerBound)
                    l.meleeUnit?.attackRating = b.averageDamage.lowerBound
                        + perm.meleeDamageBracketPosition
                        * (b.averageDamage.upperBound - b.averageDamage.lowerBound)
                    return l
                }
                towers.append(TowerType(id: id, name: fixed.towerNames[kind]!, levels: Array(levels)))
                continue
            }
            guard baseLevels.prefix(maxLevel).contains(where: {
                $0.shotMaxDamage > 0 || $0.terrorMax > 0 || $0.contagionChance > 0
            }) else { continue }
            guard let growth = perm.upgradeGrowth[kind],
                  let l1Range = perm.rangeByKind[kind],
                  let l1Rof = perm.rofByKind[kind],
                  let speed = perm.projSpeedByKind[kind]
            else { fatalError("Missing simulator tower attributes for '\(kind)'") }
            let baseCost = baseLevels[0].cost
            let dbL1Range = baseLevels[0].range
            let dbL1Rof = baseLevels[0].fireInterval
            let dbL1Splash = baseLevels.first { $0.aoeRadius > 0 }?.aoeRadius
            let levels = baseLevels.prefix(maxLevel).enumerated().map { n, base in
                var l = base
                if n > 0 {
                    let raw = Double(baseCost) * pow(growth, Double(n))
                    l.cost = Int((raw / 5).rounded()) * 5
                }
                l.range = l1Range * (base.range / dbL1Range)
                if dbL1Rof > 0 {
                    l.fireInterval = l1Rof * (base.fireInterval / dbL1Rof)
                }
                if base.projectileSpeed > 0 {
                    l.projectileSpeed = speed
                }
                if let dbL1Splash, base.aoeRadius > 0 {
                    guard let l1Splash = perm.splashByKind[kind], let falloff = perm.falloffByKind[kind] else {
                        fatalError("Missing simulator splash attributes for '\(kind)'")
                    }
                    l.aoeRadius = l1Splash * (base.aoeRadius / dbL1Splash)
                    l.aoeFalloffExponent = falloff
                }
                return l
            }
            towers.append(TowerType(id: id, name: fixed.towerNames[kind]!, levels: Array(levels)))
        }
        return ContentCatalog(combatRules: fixed.combatRules, enemyTypes: roster, towerTypes: towers)
    }
}

/// Builds the wave list a permutation plays: the fixed wave count, budgeted
/// along the permutation's curve, mix and spacing.
struct SweepWaves {
    let fixed: SweepFixedInputs
    let pathCount: Int
    let curveWeights: [String: [Double]] = [
        "gentle": [1.0, 1.15, 1.3, 1.45, 1.6, 1.75],
        "standard": [1.0, 1.3, 1.7, 2.1, 2.6, 3.2],
        "steep": [0.7, 1.0, 1.5, 2.2, 3.2, 4.6],
    ]
    let mixFractions: [String: [(key: String, frac: Double)]] = [
        "swarm": [(Foe.loyalistMilitia.rawValue, 0.7), (Foe.redcoatRegular.rawValue, 0.3)],
        "balanced": [(Foe.loyalistMilitia.rawValue, 0.4), (Foe.redcoatRegular.rawValue, 0.4), (Foe.lightInfantry.rawValue, 0.2)],
        "elite": [(Foe.redcoatRegular.rawValue, 0.5), (Foe.lightInfantry.rawValue, 0.5)],
        "combined": [(Foe.loyalistMilitia.rawValue, 0.3), (Foe.redcoatRegular.rawValue, 0.4),
                     (Foe.lightInfantry.rawValue, 0.2), (Foe.regimentalDrummer.rawValue, 0.1)],
    ]
    let budgetPerWave = 110.0

    init(fixed: SweepFixedInputs, pathCount: Int = 1) {
        self.fixed = fixed
        self.pathCount = pathCount
    }

    func make(perm: SweepPermutation) -> [Wave] {
        let totalBudget = budgetPerWave * Double(fixed.numWaves)
        let interval = perm.spacing == "tight" ? 1.4 : 2.2
        var weights = curveWeights[perm.curve] ?? curveWeights["standard"]!
        if weights.count != fixed.numWaves {
            weights = (0..<fixed.numWaves).map { i in
                weights[min(i * weights.count / fixed.numWaves, weights.count - 1)]
            }
        }
        let weightSum = weights.reduce(0, +)
        let mix = mixFractions[perm.mix] ?? mixFractions["balanced"]!

        var byKey: [String: EnemyType] = [:]
        for e in fixed.roster { byKey[e.key] = e }

        var waves: [Wave] = []
        var start = 10.0
        for w in 0..<fixed.numWaves {
            let budget = totalBudget * weights[w] / weightSum
            var lines: [SpawnEntry] = []
            var delay = 0.0
            for (li, entry) in mix.enumerated() {
                let (key, frac) = entry
                guard let type = byKey[key] else { continue }
                let isDrummer = key == Foe.regimentalDrummer.rawValue
                if isDrummer && w < 2 { continue }
                var count = Int((budget * frac / Double(type.stats.gold)).rounded())
                if isDrummer { count = min(count, 1) }
                guard count >= 1 else { continue }
                let path = pathCount > 1 ? (w + li) % pathCount : 0
                lines.append(SpawnEntry(
                    enemyTypeID: type.id, count: count, interval: interval,
                    delay: delay, pathIndex: path
                ))
                delay += 2.0
            }
            if lines.isEmpty, let militia = byKey[Foe.loyalistMilitia.rawValue] {
                lines = [SpawnEntry(enemyTypeID: militia.id, count: 1, interval: interval)]
            }
            waves.append(Wave(startTime: start, spawns: lines))
            let lastSpawn = lines.map { $0.delay + Double(max(0, $0.count - 1)) * $0.interval }.max() ?? 0
            start += lastSpawn + 12
        }
        return waves
    }
}

struct GreedyCommander: CommanderPolicy {
    let slotOrder: [Int]
    let plan: [UUID]
    private var nextCheck = 0.0
    private var buildsDone = 0

    init(level: LevelInfo, catalog: ContentCatalog) {
        func dps(_ t: TowerType) -> Double {
            guard let l = t.levels.first, l.fireInterval > 0 else { return 0 }
            return (l.shotMinDamage + l.shotMaxDamage + l.terrorMin + l.terrorMax) / 2 / l.fireInterval
        }
        let ranked = catalog.towerTypes.sorted { dps($0) > dps($1) }
        let melee = catalog.towerTypes.first { $0.levels.first?.meleeUnit != nil }
        var order: [UUID] = []
        if let primary = ranked.first {
            order = [primary.id, primary.id]
            if let melee { order.append(melee.id) }
            else if ranked.count > 1 { order.append(ranked[1].id) }
            order.append(primary.id)
        }
        plan = order

        guard let range = ranked.first?.levels.first?.range else {
            fatalError("The simulator commander requires an authored tower range")
        }
        var scores: [(Int, Double)] = []
        for (i, slot) in level.towerSlots.enumerated() {
            var covered = 0.0
            let r2 = range * range
            for path in level.paths {
                var d = 0.0
                while d < path.totalLength {
                    if path.point(atDistance: d).squaredDistance(to: slot.position) <= r2 {
                        covered += 8
                    }
                    d += 8
                }
            }
            scores.append((i, covered))
        }
        slotOrder = scores.sorted { $0.1 > $1.1 }.map { $0.0 }
    }

    mutating func tick(time: Double, sim: Simulation) {
        guard time >= nextCheck else { return }
        nextCheck = time + 0.5

        if buildsDone < plan.count, buildsDone < slotOrder.count {
            switch sim.build(slot: slotOrder[buildsDone], towerID: plan[buildsDone]) {
            case .ok: buildsDone += 1
            case .needGold: return
            case .invalid: buildsDone += 1
            }
            return
        }

        for slot in slotOrder {
            guard let tower = sim.towers[slot] else { continue }
            let type = sim.catalog.towerTypes[tower.typeIndex]
            guard tower.level + 1 < type.levels.count else { continue }
            let cost = type.levels[tower.level + 1].cost
            if sim.gold >= cost + 40 {
                if sim.upgrade(slot: slot) == .ok { return }
            }
            return
        }

        let built = sim.towers.compactMap { $0 }.count
        if built < min(6, slotOrder.count), sim.gold >= 150, let primary = plan.first {
            sim.build(slot: slotOrder[built], towerID: primary)
        }
    }
}

struct NaiveCommander: CommanderPolicy {
    let slotOrder: [Int]
    let plan: [UUID]
    private var nextCheck = 0.0
    private var buildsDone = 0

    init(level: LevelInfo, catalog: ContentCatalog, seed: UInt64) {
        func dps(_ t: TowerType) -> Double {
            guard let l = t.levels.first, l.fireInterval > 0 else { return 0 }
            return (l.shotMinDamage + l.shotMaxDamage + l.terrorMin + l.terrorMax) / 2 / l.fireInterval
        }
        let ranked = catalog.towerTypes.sorted { dps($0) > dps($1) }
        let melee = catalog.towerTypes.first { $0.levels.first?.meleeUnit != nil }
        var order: [UUID] = []
        if let primary = ranked.first {
            order = [primary.id, primary.id]
            if let melee { order.append(melee.id) }
            else if ranked.count > 1 { order.append(ranked[1].id) }
            order.append(primary.id)
        }
        plan = order

        var rng = SeededRNG(seed: seed ^ 0xA1F0_5107)
        var slots = Array(level.towerSlots.indices)
        for i in stride(from: slots.count - 1, to: 0, by: -1) {
            let j = Int(rng.double(in: 0...Double(i)))
            slots.swapAt(i, min(j, i))
        }
        slotOrder = slots
    }

    mutating func tick(time: Double, sim: Simulation) {
        guard time >= nextCheck else { return }
        nextCheck = time + 0.5
        if buildsDone < plan.count, buildsDone < slotOrder.count {
            switch sim.build(slot: slotOrder[buildsDone], towerID: plan[buildsDone]) {
            case .ok: buildsDone += 1
            case .needGold: return
            case .invalid: buildsDone += 1
            }
        }
    }
}

struct SweepRow {
    var perm: SweepPermutation
    var seedsUsed: Int
    var winRate: Double
    var livesP10: Double
    var livesP50: Double
    var livesP90: Double
    var meanLeaked: Double
    var routShare: Double
    var tensionMean: Double
    var tensionPeak: Double
    var tensionFinal: Double
    var meanSeconds: Double
    var w1GreedyClear: Double
    var w1GreedyLeaks: Double
    var w1NaiveClear: Double
    var w1NaiveLeaks: Double

    func csv() -> String {
        let p = perm
        return "\(p.index),\(p.money),\(p.lives),\(p.growthLabel),\(p.rangeLabel),\(p.rofLabel),"
            + "\(p.projSpeedLabel),\(p.splashLabel),\(p.falloffLabel),\(p.enemySpeedBracketPosition),\(p.enemyHpBracketPosition),\(p.enemyBountyBracketPosition),\(p.meleeHpBracketPosition),\(p.meleeDamageBracketPosition),"
            + "\(p.curve),\(p.mix),\(p.spacing),\(seedsUsed),"
            + String(format: "%.4f,%.1f,%.1f,%.1f,%.3f,%.4f,%.4f,%.4f,%.4f,%.1f,",
                     winRate, livesP10, livesP50, livesP90, meanLeaked, routShare,
                     tensionMean, tensionPeak, tensionFinal, meanSeconds)
            + String(format: "%.4f,%.3f,%.4f,%.3f",
                     w1GreedyClear, w1GreedyLeaks, w1NaiveClear, w1NaiveLeaks)
    }
}

/// The permutation sweep of a level: every input it needs comes through
/// init, and every run reads the one shared database.
struct Sweep {
    let db: Db
    let runs: SimulatorRunDAO?

    init(db: Db, runs: SimulatorRunDAO?) {
        self.db = db
        self.runs = runs
    }

    func bench(levelName: String, sims: Int) throws {
        let fixed = try SweepFixedInputs(db: db, levelName: levelName)
        let base = try fixed.designLevel(db: db)
        let space = SweepSpace(grids: try SweepGrids(dao: db.simTowerSweepDao, profile: "coarse"), fixed: fixed, slotCount: base.towerSlots.count)
        let perm = space.permutation(at: space.permutationCount / 2)
        let catalog = SweepCatalog(fixed: fixed).make(perm: perm)
        let waves = SweepWaves(fixed: fixed, pathCount: base.paths.count).make(perm: perm)
        let level = LevelInfo(
            id: base.id, name: base.name, campaign: base.campaign,
            startedAt: base.startedAt, endedAt: base.endedAt,
            startingMoney: perm.money, numStartingLives: perm.lives,
            playArea: base.playArea,
            paths: base.paths, towerSlots: base.towerSlots, waves: waves
        )
        let proto = GreedyCommander(level: level, catalog: catalog)

        let lock = NSLock()
        var totalTicks = 0
        let t0 = Date()
        let chunk = 64
        let chunks = (sims + chunk - 1) / chunk
        DispatchQueue.concurrentPerform(iterations: chunks) { c in
            var ticks = 0
            let lo = c * chunk
            let hi = min(sims, lo + chunk)
            for s in lo..<hi {
                guard let sim = try? Simulation(
                    level: level, catalog: catalog, policy: proto, seed: 1776 &+ UInt64(s)
                ) else { continue }
                _ = sim.run(maxSeconds: 600)
                ticks += sim.tick
            }
            lock.lock()
            totalTicks += ticks
            lock.unlock()
        }
        let dt = Date().timeIntervalSince(t0)
        let simsPerSec = Double(sims) / dt
        print(String(format: """

        ── bench: %@ ─────────────────────────────
        %d sims in %.1fs on %d cores
        %.0f sims/s   %.1fM engine ticks/s   %.1f ms/sim
        8-hour night at this rate: %.1fM sims
        ──────────────────────────────────────────
        """, levelName, sims, dt, ProcessInfo.processInfo.activeProcessorCount,
        simsPerSec, Double(totalTicks) / dt / 1_000_000,
        1000 / max(0.001, simsPerSec) * Double(ProcessInfo.processInfo.activeProcessorCount),
        simsPerSec * 8 * 3600 / 1_000_000))
    }

    func run(
        levelName: String,
        grids: SweepGrids,
        stride sampleStride: Int,
        outPath: String,
        useGPU: Bool = false,
        storeBounds: Bool = false,
        fieldMelee: Bool = false
    ) throws {
        let fixed = try SweepFixedInputs(db: db, levelName: levelName, fieldMelee: fieldMelee)
        let base = try fixed.designLevel(db: db)
        let space = SweepSpace(grids: grids, fixed: fixed, slotCount: base.towerSlots.count)
        let catalogs = SweepCatalog(fixed: fixed)
        let waveBuilder = SweepWaves(fixed: fixed, pathCount: base.paths.count)

        let allPerms = space.permutationCount
        var indices: [Int]
        if let focus = grids.focus {
            guard let (place, count) = space.focusPlacement(stat: focus.stat, kind: focus.kind) else {
                throw DbError.Db(message: "focus \(focus.label) is not a permutation dimension of this level")
            }
            guard count > 1 else {
                throw DbError.Db(message: "focus \(focus.label) has a single-value grid — nothing to compare (pinned by --fix, collapsed for this kind, or missing sim brackets)")
            }
            let otherCount = allPerms / count
            var paired: [Int] = []
            paired.reserveCapacity((otherCount / sampleStride + 1) * count)
            var other = 0
            while other < otherCount {
                let lo = other % place
                let hi = other / place
                for f in 0..<count {
                    paired.append(lo + (f + hi * count) * place)
                }
                other += sampleStride
            }
            indices = paired
        } else {
            indices = Array(Swift.stride(from: 0, to: allPerms, by: sampleStride))
        }
        let unlimited = indices.count
        if let limit = grids.limit, limit < indices.count {
            if let focus = grids.focus,
               let (_, count) = space.focusPlacement(stat: focus.stat, kind: focus.kind) {
                indices = Array(indices.prefix(max(1, limit / count) * count))
            } else {
                indices = Array(indices.prefix(limit))
            }
        }
        let sims = indices.count * grids.seedsPerPermutation
        let moneyLo = space.moneyValues.first ?? 0
        let moneyHi = space.moneyValues.last ?? 0
        FileHandle.standardError.write(Data("""
        sweep: \(levelName)
          fixed from DB: lives \(fixed.lives), \(fixed.numWaves) waves, unlocks \
        \(fixed.unlocks.sorted { $0.key < $1.key }.map { "\($0.key)≤\($0.value)" }.joined(separator: " "))
          money: \(moneyLo)–\(moneyHi) step \(grids.startingMoneyStep) \
        (min = 3 × cheapest tower; max = cheapest × (slots/2 + 1), \(base.towerSlots.count) slots)
          starting lives: \(space.livesValues) (DB shipped value \(fixed.lives))
          upgrade growth per kind (\(space.combatKinds.joined(separator: ", "))): \(grids.upgradeGrowth)
          range grids: \(space.combatKinds.map { "\($0) \(space.rangeGrid(for: $0).map(Int.init))\(grids.fixedRange[$0] == nil && space.bounds[$0]?["range"] != nil ? " ← stored bounds" : "")" }.joined(separator: "  "))
          rate-of-fire grids (s): \(space.combatKinds.map { "\($0) \(space.rofGrid(for: $0))" }.joined(separator: "  "))
          projectile speed grids: \(space.combatKinds.map { "\($0) \(space.projSpeedGrid(for: $0, fixed: space.fixedInputs).map(Int.init))" }.joined(separator: "  "))
          enemy bracket positions (0 = bracket min, 0.5 = designed, 1 = max): speed \(space.enemySpeeds)  hp \(space.enemyHps)  bounty \(space.enemyBounties)
          melee bracket positions: \(space.meleeFielded ? "hp \(space.meleeHps)  damage \(space.meleeDamages) (fielded)" : "not fielded (pass --melee)")\
        \(space.aoeKinds.isEmpty ? "" : "\n  splash grids: " + space.aoeKinds.map { "\($0) \(space.splashGrid(for: $0).map(Int.init)) falloff \(space.falloffGrid(for: $0))" }.joined(separator: "  "))\
        \({ () -> String in
            var pins = grids.fixedRange.map { "range:\($0.key)=\($0.value)" }
                + grids.fixedProjSpeed.map { "projspeed:\($0.key)=\($0.value)" }
                + grids.fixedRof.map { "rof:\($0.key)=\($0.value)" }
                + grids.fixedGrowth.map { "growth:\($0.key)=\($0.value)" }
                + grids.fixedSplash.map { "splash:\($0.key)=\($0.value)" }
                + grids.fixedFalloff.map { "falloff:\($0.key)=\($0.value)" }
            if let m = grids.fixedMoney { pins.append("money=\(m)") }
            if let c = grids.fixedCurve { pins.append("curve=\(c)") }
            if let m = grids.fixedMix { pins.append("mix=\(m)") }
            if let s = grids.fixedSpacing { pins.append("spacing=\(s)") }
            return pins.isEmpty ? "" : "\n  designer pins: " + pins.sorted().joined(separator: " ")
        }())
          permutations: \(indices.count) of \(allPerms) grid points × \(grids.seedsPerPermutation) seeds = \(sims) simulations
        \({ () -> String in
            guard let limit = grids.limit, indices.count < unlimited else { return "" }
            let rounded = indices.count > limit
                ? " (raised from \(limit) to keep whole focus groups)" : ""
            return "  ⚠ --limit: running \(indices.count)\(rounded) of \(unlimited) sampled permutations — partial run, not a balance result\n"
        }())\
          cores: \(ProcessInfo.processInfo.activeProcessorCount)
        \(grids.focus.map { f -> String in
            let count = space.focusPlacement(stat: f.stat, kind: f.kind)?.count ?? 0
            return "  focus: \(f.label) — \(count) values × \(indices.count / max(1, count)) paired samples of the other variables\n"
        } ?? "")
        """.utf8))

        let lock = NSLock()
        var rows: [SweepRow] = []
        rows.reserveCapacity(indices.count)
        var done = 0
        let t0 = Date()

        let runID = try? runs?.begin(levelName: levelName,
                                     focus: grids.focus?.label ?? "",
                                     totalIterations: indices.count,
                                     outputPath: outPath)
        if let runID = runID ?? nil {
            FileHandle.standardError.write(Data("  run id: \(runID.uuidString)\n".utf8))
        }
        func report(_ completed: Int, _ rate: Double) {
            if let runs, let id = runID ?? nil { runs.progress(id: id, completed: completed,
                                                               iterationsPerSecond: rate) }
        }
        let store = try SweepResultStore(databasePath: db.path, runID: runID ?? nil)

        func conclude(_ status: SimulatorRunStatus, report reportPath: String? = nil, error: String? = nil) {
            if let runs, let id = runID ?? nil {
                runs.finish(id: id, status: status, reportPath: reportPath, errorMessage: error)
            }
        }

        if useGPU {
            rows = try GPUHarness(db: db).sweepRows(
                fixed: fixed, base: base, space: space,
                indices: indices, grids: grids, store: store,
                onProgress: { report($0, $1) }
            )
            try finish(rows: &rows, fixed: fixed, grids: grids, outPath: outPath,
                       sims: sims, t0: t0, levelName: levelName,
                       inBandLow: 0.6, inBandHigh: 0.95, store: store)
            if storeBounds {
                try deriveAndStoreBounds(fixed: fixed, space: space,
                                         rows: rows, outPath: outPath)
            }
            if let focus = grids.focus {
                try FocusReport(focus: focus, space: space).emit(rows: rows, sweepOut: outPath)
            }
            conclude(.completed)
            return
        }

        func processPerm(_ index: Int) -> SweepRow {
            let perm = space.permutation(at: index)
            let catalog = catalogs.make(perm: perm)
            let waves = waveBuilder.make(perm: perm)
            let level = LevelInfo(
                id: base.id, name: base.name, campaign: base.campaign,
                startedAt: base.startedAt, endedAt: base.endedAt,
                startingMoney: perm.money, numStartingLives: perm.lives,
                playArea: base.playArea,
                paths: base.paths, towerSlots: base.towerSlots, waves: waves
            )
            let proto = GreedyCommander(level: level, catalog: catalog)

            var results: [SimulationResult] = []
            results.reserveCapacity(grids.seedsPerPermutation)
            let probe = min(grids.probeSeeds, grids.seedsPerPermutation)
            for s in 0..<grids.seedsPerPermutation {
                if s == probe {
                    let allPerfect = results.allSatisfy {
                        $0.outcome == .victory && $0.leaked == 0
                            && $0.livesRemaining == perm.lives
                    }
                    let allLost = results.allSatisfy { $0.outcome == .defeat }
                    if allPerfect || allLost { break }
                }
                let seed = grids.baseSeed &+ UInt64(s)
                guard let sim = try? Simulation(
                    level: level, catalog: catalog, policy: proto, seed: seed
                ) else { continue }
                results.append(sim.run(maxSeconds: 600))
            }
            let seedsUsed = results.count
            let report = BatchReport(results: results)

            let w1Cutoff = waves.count > 1 ? waves[1].startTime + 25 : 600
            var naiveW1: [Int] = []
            naiveW1.reserveCapacity(seedsUsed)
            for s in 0..<seedsUsed {
                let seed = grids.baseSeed &+ UInt64(s)
                guard let sim = try? Simulation(
                    level: level, catalog: catalog,
                    policy: NaiveCommander(level: level, catalog: catalog, seed: seed),
                    seed: seed
                ) else { continue }
                let r = sim.run(maxSeconds: w1Cutoff)
                naiveW1.append(r.leaksByWave.first ?? 0)
            }
            let greedyW1 = results.map { $0.leaksByWave.first ?? 0 }
            let peaks = results.map { $0.waveMaxProgress.max() ?? 0 }
            let finals = results.map { $0.waveMaxProgress.last ?? 0 }
            let means = results.map { $0.waveMaxProgress.isEmpty ? 0 :
                $0.waveMaxProgress.reduce(0, +) / Double($0.waveMaxProgress.count) }
            return SweepRow(
                perm: perm,
                seedsUsed: seedsUsed,
                winRate: report.winRate,
                livesP10: report.livesPercentile(10),
                livesP50: report.livesPercentile(50),
                livesP90: report.livesPercentile(90),
                meanLeaked: Double(report.totalLeaked) / Double(max(1, results.count)),
                routShare: report.routShare,
                tensionMean: means.reduce(0, +) / Double(max(1, means.count)),
                tensionPeak: peaks.reduce(0, +) / Double(max(1, peaks.count)),
                tensionFinal: finals.reduce(0, +) / Double(max(1, finals.count)),
                meanSeconds: results.map(\.seconds).reduce(0, +) / Double(max(1, results.count)),
                w1GreedyClear: Double(greedyW1.filter { $0 == 0 }.count) / Double(max(1, greedyW1.count)),
                w1GreedyLeaks: Double(greedyW1.reduce(0, +)) / Double(max(1, greedyW1.count)),
                w1NaiveClear: Double(naiveW1.filter { $0 == 0 }.count) / Double(max(1, naiveW1.count)),
                w1NaiveLeaks: Double(naiveW1.reduce(0, +)) / Double(max(1, naiveW1.count))
            )
        }

        func record(_ row: SweepRow) {
            lock.lock()
            rows.append(row)
            done += 1
            if done % 500 == 0 {
                let rate = Double(done) / max(0.001, Date().timeIntervalSince(t0))
                let eta = Double(indices.count - done) / max(0.001, rate)
                report(done, rate)
                FileHandle.standardError.write(Data(
                    String(format: "  %d/%d permutations  (%.1f/s, eta %.0fs)\n",
                           done, indices.count, rate, eta).utf8))
            }
            lock.unlock()
        }

        let calibrationCount = min(32, indices.count)
        DispatchQueue.concurrentPerform(iterations: calibrationCount) { k in
            record(processPerm(indices[k]))
        }
        let calibrationTime = Date().timeIntervalSince(t0)
        let projected = calibrationTime / Double(max(1, calibrationCount)) * Double(indices.count)
        let budget = grids.budgetHours * 3600
        var warning = ""
        if projected > budget {
            let stride = Int((projected / budget).rounded(.up)) * sampleStride
            warning = String(format: """
              ⚠ projected %.1fh exceeds the %.1fh budget — consider --sweep-stride %d, \
            more --fix pins, or fewer --sweep-seeds
            """, projected / 3600, grids.budgetHours, stride)
        }
        FileHandle.standardError.write(Data(String(format:
            "  calibration: %d perms in %.0fs → projected total %.1fh%@\n",
            calibrationCount, calibrationTime, projected / 3600,
            warning.isEmpty ? "" : "\n" + warning).utf8))

        if indices.count > calibrationCount {
            DispatchQueue.concurrentPerform(iterations: indices.count - calibrationCount) { k in
                record(processPerm(indices[calibrationCount + k]))
            }
        }

        try finish(rows: &rows, fixed: fixed, grids: grids, outPath: outPath,
                   sims: sims, t0: t0, levelName: levelName,
                   inBandLow: 0.6, inBandHigh: 0.95, store: store)
        if storeBounds {
            try deriveAndStoreBounds(fixed: fixed, space: space,
                                     rows: rows, outPath: outPath)
        }
        if let focus = grids.focus {
            try FocusReport(focus: focus, space: space).emit(rows: rows, sweepOut: outPath)
        }
        conclude(.completed)
    }

    private func deriveAndStoreBounds(
        fixed: SweepFixedInputs, space: SweepSpace,
        rows: [SweepRow], outPath: String
    ) throws {
        for kind in space.combatKinds {
            let grid = space.rangeGrid(for: kind)
            guard grid.count >= 3 else { continue }
            let dbRof = fixed.requiredLevels(for: kind)[0].fireInterval
            let gGrid = space.growthGrid(for: kind)
            let midGrowth = gGrid[gGrid.count / 2]
            let slice = try rows.filter {
                guard let rof = $0.perm.rofByKind[kind], let growth = $0.perm.upgradeGrowth[kind] else {
                    throw DbError.Db(message: "Missing simulator result attributes for '\(kind)'")
                }
                return abs(rof - dbRof) < 0.001 && abs(growth - midGrowth) < 0.001
            }
            let use = slice.isEmpty ? rows : slice
            var byRange: [Double: (win: Double, naive: Double, n: Int)] = [:]
            for r in use {
                guard let rv = r.perm.rangeByKind[kind] else {
                    throw DbError.Db(message: "Missing simulator result range for '\(kind)'")
                }
                var e = byRange[rv] ?? (0, 0, 0)
                e.win += r.winRate
                e.naive += r.w1NaiveClear
                e.n += 1
                byRange[rv] = e
            }
            let curve = byRange
                .map { (r: $0.key, win: $0.value.win / Double($0.value.n),
                        naive: $0.value.naive / Double($0.value.n)) }
                .sorted { $0.r < $1.r }
            guard let first = curve.first, let last = curve.last else { continue }
            guard let minV = curve.first(where: { $0.win >= 0.10 })?.r else {
                print("  bounds[\(kind).range]: never winnable in tested grid — nothing stored")
                continue
            }
            let ceiling = curve.first(where: { $0.win >= 0.99 && $0.naive >= 0.85 })?.r
            let maxV = max(ceiling ?? last.r, minV)
            var notes: [String] = ["\(outPath)", "slice rof=\(dbRof) growth=\(midGrowth)"]
            if first.win >= 0.10 { notes.append("floor below tested grid") }
            notes.append(ceiling == nil ? "ceiling not reached at <=\(Int(last.r))"
                                        : "ceiling: win>=99% & naiveW1>=85%")
            let derivedFrom = notes.joined(separator: "; ")
            try db.simBoundsDao.upsert(
                levelInfoId: fixed.levelID, towerKind: kind, stat: "range",
                minValue: minV, maxValue: maxV, derivedFrom: derivedFrom
            )
            print("""
              bounds[\(kind).range] stored: \(Int(minV))–\(Int(maxV)) (\(derivedFrom))
              live database only — create_db.sh seeds no run data, so re-run --store-bounds after a rebuild
            """)
        }
    }

    private func finish(
        rows: inout [SweepRow], fixed: SweepFixedInputs, grids: SweepGrids,
        outPath: String, sims: Int, t0: Date, levelName: String,
        inBandLow: Double, inBandHigh: Double, store: SweepResultStore? = nil
    ) throws {
        rows.sort { $0.perm.index < $1.perm.index }
        // The CPU path accumulates rows in memory and writes them here; the GPU
        // path has already streamed each batch into the store as it went.
        if let store, store.rowCount == 0 { try store.insert(rows) }

        let elapsed = Date().timeIntervalSince(t0)
        let actualSims = rows.reduce(0) { $0 + $1.seedsUsed * 2 }
        let inBand = rows.filter { $0.winRate >= inBandLow && $0.winRate <= inBandHigh }.count
        let hopeless = rows.filter { $0.winRate == 0 }.count
        let trivial = rows.filter { $0.winRate == 1 && $0.livesP10 >= Double($0.perm.lives) }.count

        var byMoney: [Int: (clear: Double, n: Int)] = [:]
        for row in rows {
            let e = byMoney[row.perm.money] ?? (0, 0)
            byMoney[row.perm.money] = (e.clear + row.w1NaiveClear, e.n + 1)
        }
        let moneyCurve = byMoney.map { ($0.key, $0.value.clear / Double(max(1, $0.value.n))) }
            .sorted { $0.0 < $1.0 }
        let knee = moneyCurve.first { $0.1 >= 0.90 }?.0
        let saturation = moneyCurve.first { $0.1 >= 0.99 }?.0
        let curveStr = moneyCurve
            .filter { $0.0 % 20 == 10 || $0.0 == moneyCurve.first?.0 || $0.0 == moneyCurve.last?.0 }
            .map { String(format: "%d:%.0f%%", $0.0, $0.1 * 100) }
            .joined(separator: "  ")

        print("""

        ── sweep complete: \(levelName) ──────────────────────
        simulations: \(actualSims) run of \(sims * 2) nominal (adaptive seeds saved \
        \(String(format: "%.0f%%", (1 - Double(actualSims) / Double(max(1, sims * 2))) * 100))) \
        in \(String(format: "%.0f", elapsed))s (\(String(format: "%.0f", Double(actualSims) / max(0.001, elapsed)))/s)
        output:      \(outPath)  (\(rows.count) rows)

        quick read:
          \(trivial) permutations are trivial (100% win, perfect lives at p10)
          \(inBand) land in the 60–95% win band (difficulty lives here)
          \(hopeless) are unwinnable for the greedy commander

        starting money (naive wave-1 clear rate by money, all else averaged):
          \(curveStr)
          sloppy-open survives ≥90% at \(knee.map(String.init) ?? ">max"), \
        ≥99% at \(saturation.map(String.init) ?? ">max") — the right value \
        likely sits just past the 90% knee.
        ──────────────────────────────────────────────────────
        """)
    }
}
