import Foundation

public final class Simulation {
    public let catalog: ContentCatalog
    public let level: LevelInfo

    // Mutable run state.
    public private(set) var time: Double = 0
    public private(set) var tick: Int = 0
    public private(set) var gold: Int
    public private(set) var lives: Int
    public private(set) var enemies: ContiguousArray<Enemy> = []
    public private(set) var towers: [Tower?]
    public private(set) var outcome: Outcome?

    // Counters.
    public private(set) var killed = 0
    public private(set) var routed = 0
    public private(set) var captured = 0
    public private(set) var leaked = 0
    public private(set) var fatesByType: [[Int]]   // [enemyTypeIndex][EnemyFate]
    public private(set) var goldEarned = 0
    /// Per-wave max progress fraction any enemy reached (the tension trace /
    /// flatness detector: a wave that never crosses ~0.6 will bore humans too).
    public private(set) var waveMaxProgress: [Double]
    /// Per-wave leak counts (which wave the leaked enemy belonged to).
    public private(set) var leaksByWave: [Int]

    private var policy: any CommanderPolicy
    private var observers: [SimulationObserver] = []

    // RNG streams (see SeededRNG.fork for why they're separate).
    private var rngCombat: SeededRNG
    private var rngMorale: SeededRNG
    private var rngContagion: SeededRNG

    // Precomputed spawn timeline.
    private struct ScheduledSpawn {
        var time: Double
        var enemyTypeIndex: Int
        var pathIndex: Int
        var waveIndex: Int
    }
    private var schedule: [ScheduledSpawn] = []
    private var scheduleCursor = 0
    private var lastWaveAnnounced = -1
    private var nextSpawnID = 0

    // Scratch buffers, rebuilt each tick (kept as stored properties so their
    // capacity is reused instead of reallocated).
    private var positions: [Point] = []
    private var moraleRegen: [Double] = []
    private var disciplineBonus: [Double] = []
    private var contagionAccumulator: Double = 0

    /// In-flight projectiles. Homing rounds chase a spawnID and fizzle if the
    /// target dies first; ballistic shells fly to a fixed point and detonate
    /// there regardless. Order-preserving removal keeps the impact-time RNG
    /// draws identical between the CPU and GPU engines.
    private struct Projectile {
        var position: Point
        var aim: Point            // ballistic detonation point
        var targetSpawnID: Int    // -1 == ballistic
        var towerTypeIndex: Int
        var towerLevel: Int
        var removed: Bool = false
    }
    private var projectiles: [Projectile] = []

    /// Melee garrisons by tower slot. Units live here; their behavior comes
    /// from MilitiaAI — the engine only executes decisions and owns combat.
    public struct Garrison: Sendable {
        public var rallyPoint: Point
        public var units: [MilitiaUnit]
        var enemySwingTicks: [Int: Int] = [:]   // blocked enemy spawnID -> ticks to next swing
    }
    public private(set) var garrisons: [Int: Garrison] = [:]
    public private(set) var militiaKills = 0
    public private(set) var militiaDeaths = 0
    public private(set) var militiaRespawns = 0
    public private(set) var projImpacts = 0
    public private(set) var projFizzles = 0
    /// Enemy type indices that cannot be blocked (rideDown shoves infantry).
    private var blockImmune: [Bool] = []
    /// Rebuilt each militia tick: spawnIDs currently held in a fight.
    private var blockedSpawnIDs: Set<Int> = []

    // MARK: - Init

    public init(
        level: LevelInfo,
        catalog: ContentCatalog,
        policy: any CommanderPolicy,
        seed: UInt64
    ) throws {
        self.level = level
        self.catalog = catalog
        self.policy = policy
        self.gold = level.startingMoney
        self.lives = level.numStartingLives
        self.towers = Array(repeating: nil, count: level.towerSlots.count)
        self.fatesByType = Array(
            repeating: [0, 0, 0, 0],
            count: catalog.enemyTypes.count
        )
        self.waveMaxProgress = Array(repeating: 0, count: level.waves.count)
        self.leaksByWave = Array(repeating: 0, count: level.waves.count)
        self.blockImmune = catalog.enemyTypes.map { $0.traits.contains(.rideDown) }

        let root = SeededRNG(seed: seed)
        self.rngCombat = root.fork(stream: 1)
        self.rngMorale = root.fork(stream: 2)
        self.rngContagion = root.fork(stream: 3)

        // Flatten the wave timeline once, up front.
        var sched: [ScheduledSpawn] = []
        for (wi, wave) in level.waves.enumerated() {
            for entry in wave.spawns {
                let typeIndex = try catalog.requireEnemyIndex(id: entry.enemyTypeID)
                guard entry.pathIndex >= 0, entry.pathIndex < level.paths.count else {
                    throw SimulationError.badPathIndex(entry.pathIndex, level: level.id)
                }
                for k in 0..<entry.count {
                    sched.append(ScheduledSpawn(
                        time: wave.startTime + entry.delay + Double(k) * entry.interval,
                        enemyTypeIndex: typeIndex,
                        pathIndex: entry.pathIndex,
                        waveIndex: wi
                    ))
                }
            }
        }
        // Stable sort: ties resolve by insertion order, keeping runs identical
        // across content edits that don't change timings.
        self.schedule = sched.enumerated()
            .sorted { ($0.element.time, $0.offset) < ($1.element.time, $1.offset) }
            .map { $0.element }
    }

    public enum SimulationError: Error, CustomStringConvertible {
        case badPathIndex(Int, level: UUID)

        public var description: String {
            switch self {
            case let .badPathIndex(i, level):
                return "Level '\(level)' references path index \(i) which does not exist"
            }
        }
    }

    public func addObserver(_ o: SimulationObserver) {
        observers.append(o)
    }

    private func emit(_ e: SimEvent) {
        guard !observers.isEmpty else { return }
        for o in observers { o.handle(e, atTime: time) }
    }

    // MARK: - Build API (called by policies)

    @discardableResult
    public func build(slot: Int, towerID: UUID) -> BuildResult {
        guard slot >= 0, slot < towers.count, towers[slot] == nil,
              let typeIndex = catalog.towerIndex(id: towerID),
              let first = catalog.towerTypes[typeIndex].levels.first
        else { return .invalid }
        guard gold >= first.cost else { return .needGold }
        gold -= first.cost
        towers[slot] = Tower(typeIndex: typeIndex, slotIndex: slot)
        if first.meleeUnitCount > 0 {
            let towerPos = level.towerSlots[slot].position
            let rally = defaultRallyPoint(towerPosition: towerPos, flagRange: first.range)
            garrisons[slot] = Garrison(
                rallyPoint: rally,
                units: (0..<first.meleeUnitCount).map { _ in
                    MilitiaUnit(position: towerPos, hp: first.meleeUnitHP)
                }
            )
        }
        emit(.towerBuilt(slot: slot, towerID: towerID))
        return .ok
    }

    /// Rally the garrison at a new flag position, clamped to the flag range.
    public func setRallyPoint(slot: Int, to point: Point) {
        guard var g = garrisons[slot], let tower = towers[slot] else { return }
        let towerPos = level.towerSlots[slot].position
        let flagRange = catalog.towerTypes[tower.typeIndex].levels[tower.level].range
        let d = towerPos.distance(to: point)
        g.rallyPoint = d <= flagRange ? point
            : Point.lerp(towerPos, point, flagRange / d)
        garrisons[slot] = g
    }

    /// Default flag: as close to the nearest road as the flag range allows.
    private func defaultRallyPoint(towerPosition: Point, flagRange: Double) -> Point {
        Simulation.defaultRallyPoint(towerPosition: towerPosition, flagRange: flagRange,
                                     paths: level.paths)
    }

    /// Shared with the GPU buffer builder so both engines place the flag at
    /// exactly the same point.
    public static func defaultRallyPoint(
        towerPosition: Point, flagRange: Double, paths: [Path]
    ) -> Point {
        var best = towerPosition
        var bestDist = Double.infinity
        for path in paths {
            var d = 0.0
            while d <= path.totalLength {
                let p = path.point(atDistance: d)
                let dist = p.distance(to: towerPosition)
                if dist < bestDist {
                    bestDist = dist
                    best = p
                }
                d += 12
            }
        }
        guard bestDist > flagRange else { return best }
        return Point.lerp(towerPosition, best, flagRange / bestDist)
    }

    @discardableResult
    public func upgrade(slot: Int) -> BuildResult {
        guard slot >= 0, slot < towers.count, var tower = towers[slot] else { return .invalid }
        let type = catalog.towerTypes[tower.typeIndex]
        let nextLevel = tower.level + 1
        guard nextLevel < type.levels.count else { return .invalid }
        let cost = type.levels[nextLevel].cost
        guard gold >= cost else { return .needGold }
        gold -= cost
        tower.level = nextLevel
        towers[slot] = tower
        emit(.towerUpgraded(slot: slot, level: nextLevel))
        return .ok
    }

    // MARK: - Run

    /// Runs to completion (or the safety cap) and reports.
    public func run(maxSeconds: Double = 900) -> SimulationResult {
        while outcome == nil, time < maxSeconds {
            step()
        }
        if outcome == nil { outcome = .timeout }
        return makeResult()
    }

    // MARK: - Tick

    public func step() {
        guard outcome == nil else { return }
        let dt = SimClock.dt

        // 1. Policy.
        policy.tick(time: time, sim: self)

        // 2. Spawns.
        while scheduleCursor < schedule.count, schedule[scheduleCursor].time <= time {
            let s = schedule[scheduleCursor]
            scheduleCursor += 1
            if s.waveIndex > lastWaveAnnounced {
                lastWaveAnnounced = s.waveIndex
                emit(.waveStarted(index: s.waveIndex))
            }
            let type = catalog.enemyTypes[s.enemyTypeIndex]
            let threshold = Tunables.moraleMax
                * rngMorale.double(in: type.stats.breakBand)
            let enemy = Enemy(
                spawnID: nextSpawnID,
                typeIndex: s.enemyTypeIndex,
                waveIndex: s.waveIndex,
                pathIndex: s.pathIndex,
                type: type,
                shakenThreshold: threshold
            )
            nextSpawnID += 1
            enemies.append(enemy)
            emit(.enemySpawned(spawnID: enemy.spawnID, typeID: type.id))
        }

        let n = enemies.count
        if n > 0 {
            // 3. Position cache.
            positions.removeAll(keepingCapacity: true)
            positions.reserveCapacity(n)
            for i in 0..<n {
                let path = level.paths[enemies[i].pathIndex]
                positions.append(path.point(atDistance: enemies[i].distance))
            }

            // 4. Auras.
            moraleRegen.removeAll(keepingCapacity: true)
            disciplineBonus.removeAll(keepingCapacity: true)
            for _ in 0..<n {
                moraleRegen.append(Tunables.baseMoraleRegenPerSecond)
                disciplineBonus.append(0)
            }
            for i in 0..<n where !enemies[i].removed {
                for trait in catalog.enemyTypes[enemies[i].typeIndex].traits {
                    switch trait {
                    case let .rallyBeat(radius, rate):
                        let r2 = radius * radius
                        for j in 0..<n where j != i && !enemies[j].removed {
                            if positions[i].squaredDistance(to: positions[j]) <= r2 {
                                moraleRegen[j] += rate
                            }
                        }
                    case let .commandAura(radius, bonus, _):
                        let r2 = radius * radius
                        for j in 0..<n where j != i && !enemies[j].removed {
                            if positions[i].squaredDistance(to: positions[j]) <= r2 {
                                disciplineBonus[j] = max(disciplineBonus[j], bonus)
                            }
                        }
                    default:
                        break
                    }
                }
            }

            // 5. Towers fire.
            for slot in 0..<towers.count {
                guard var tower = towers[slot] else { continue }
                let ranged = catalog.towerTypes[tower.typeIndex].levels[tower.level]
                guard ranged.shotMax > 0 || ranged.terrorMax > 0 || ranged.contagionChance > 0 else {
                    continue   // melee garrisons fight in their own step
                }
                tower.cooldown -= 1
                if tower.cooldown <= 0 {
                    let type = catalog.towerTypes[tower.typeIndex]
                    let lvl = type.levels[tower.level]
                    if let target = selectTarget(
                        from: level.towerSlots[slot].position,
                        range: lvl.range,
                        targeting: lvl.targeting
                    ) {
                        emit(.towerFired(slot: slot, target: positions[target]))
                        if lvl.projectileSpeed > 0 {
                            launch(from: level.towerSlots[slot].position,
                                   at: target, typeIndex: tower.typeIndex,
                                   towerLevel: tower.level)
                        } else {
                            fire(level: lvl, at: target)
                        }
                        tower.cooldown = Simulation.fireTicks(lvl.fireInterval)
                    }
                }
                towers[slot] = tower
            }

            // 5b. Projectiles fly; collision applies damage at impact.
            stepProjectiles(dt: dt)

            // 5c. Militia garrisons: AI decides, engine executes.
            stepMilitia(dt: dt)

            // 6. Contagion.
            contagionAccumulator += dt
            if contagionAccumulator >= Tunables.contagionTickInterval {
                contagionAccumulator -= Tunables.contagionTickInterval
                contagionTick(interval: Tunables.contagionTickInterval)
            }

            // 7. Morale resolution (with break cascades).
            resolveMorale(dt: dt)

            // 8. Movement & exits.
            for i in 0..<enemies.count where !enemies[i].removed {
                var e = enemies[i]
                let stats = catalog.enemyTypes[e.typeIndex].stats
                let path = level.paths[e.pathIndex]
                if blockedSpawnIDs.contains(e.spawnID), e.state != .broken {
                    enemies[i] = e
                    continue   // held in melee: stands and fights
                }
                switch e.state {
                case .broken:
                    e.distance -= stats.speed * Tunables.routSpeedMultiplier * dt
                    if e.distance <= 0 {
                        remove(&e, fate: .routed)
                    }
                case .shaken, .steady:
                    let mult = (e.state == .shaken) ? Tunables.shakenSpeedMultiplier : 1.0
                    e.distance += stats.speed * mult * dt
                    let progress = e.distance / path.totalLength
                    if progress > waveMaxProgress[e.waveIndex] {
                        waveMaxProgress[e.waveIndex] = min(progress, 1.0)
                    }
                    if e.distance >= path.totalLength {
                        lives -= stats.livesCost
                        remove(&e, fate: .leaked)
                    }
                }
                enemies[i] = e
            }
        }

        // 9. Compaction (order-preserving, in place — no per-tick allocation).
        var w = 0
        for i in 0..<enemies.count where !enemies[i].removed {
            if w != i { enemies[w] = enemies[i] }
            w += 1
        }
        if w < enemies.count { enemies.removeLast(enemies.count - w) }

        // 10. End conditions.
        if lives <= 0 {
            outcome = .defeat
        } else if scheduleCursor == schedule.count && enemies.isEmpty {
            outcome = .victory
        }

        time += dt
        tick += 1
    }

    // MARK: - Militia

    private func stepMilitia(dt: Double) {
        guard !garrisons.isEmpty else { return }

        // Who is claimed (engaged or fought) by any unit right now?
        var claimed: Set<Int> = []
        for (_, g) in garrisons.sorted(by: { $0.key < $1.key }) {
            for u in g.units where u.targetSpawnID >= 0 {
                claimed.insert(u.targetSpawnID)
            }
        }

        // Index enemies by spawnID once.
        var bySpawnID: [Int: Int] = [:]
        for i in 0..<enemies.count where !enemies[i].removed {
            bySpawnID[enemies[i].spawnID] = i
        }

        blockedSpawnIDs.removeAll(keepingCapacity: true)

        for slot in garrisons.keys.sorted() {
            guard var g = garrisons[slot], let tower = towers[slot] else { continue }
            let stats = catalog.towerTypes[tower.typeIndex].levels[tower.level]
            let towerPos = level.towerSlots[slot].position

            // Free enemies near this post: alive, steady/shaken, blockable, unclaimed.
            var free: [(spawnID: Int, position: Point)] = []
            for i in 0..<enemies.count where !enemies[i].removed {
                let e = enemies[i]
                guard e.state != .broken, !blockImmune[e.typeIndex],
                      !claimed.contains(e.spawnID) else { continue }
                free.append((e.spawnID, positions[i]))
            }

            for ui in 0..<g.units.count {
                var unit = g.units[ui]
                var targetPos: Point? = nil
                if unit.targetSpawnID >= 0, let ei = bySpawnID[unit.targetSpawnID],
                   enemies[ei].state != .broken {
                    targetPos = positions[ei]
                }
                let offset = MilitiaAI.formationOffset(index: ui, of: g.units.count)
                let context = MilitiaContext(
                    freeEnemies: free,
                    targetPosition: targetPos,
                    rallyPoint: Point(g.rallyPoint.x + offset.x, g.rallyPoint.y + offset.y),
                    towerPosition: towerPos
                )
                if unit.swingTicksLeft > 0 { unit.swingTicksLeft -= 1 }

                switch MilitiaAI.decide(unit, context: context) {
                case .idle:
                    if unit.state == .returning { unit.state = .holding }
                case .countdownRespawn:
                    unit.respawnTicksLeft -= 1
                case .respawn:
                    unit = MilitiaUnit(position: towerPos, hp: stats.meleeUnitHP)
                    militiaRespawns += 1
                case .heal:
                    unit.hp = min(stats.meleeUnitHP, unit.hp + stats.meleeUnitHealPerSecond * dt)
                case let .move(toward):
                    let d = unit.position.distance(to: toward)
                    let step = MilitiaTunables.moveSpeed * dt
                    unit.position = d <= step ? toward : Point.lerp(unit.position, toward, step / d)
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
                    if let ei = bySpawnID[targetSpawnID] {
                        var e = enemies[ei]
                        let roll = rngCombat.double(in: stats.meleeUnitDamageMin...stats.meleeUnitDamageMax)
                        e.hp -= roll * (1.0 - catalog.enemyTypes[e.typeIndex].stats.cover)
                        if e.hp <= 0 {
                            remove(&e, fate: .killed)
                            militiaKills += 1
                            unit.state = .holding
                            unit.targetSpawnID = -1
                            g.enemySwingTicks[targetSpawnID] = nil
                        }
                        enemies[ei] = e
                    }
                    unit.swingTicksLeft = Simulation.fireTicks(stats.meleeUnitAttackInterval)
                case .disengage:
                    if unit.targetSpawnID >= 0 {
                        claimed.remove(unit.targetSpawnID)
                        g.enemySwingTicks[unit.targetSpawnID] = nil
                    }
                    unit.state = .returning
                    unit.targetSpawnID = -1
                }

                // Fights hold the enemy in place and draw return blows.
                if unit.state == .fighting, unit.targetSpawnID >= 0,
                   let ei = bySpawnID[unit.targetSpawnID], !enemies[ei].removed {
                    blockedSpawnIDs.insert(unit.targetSpawnID)
                    var swing = g.enemySwingTicks[unit.targetSpawnID]
                        ?? Simulation.fireTicks(MilitiaTunables.enemySwingInterval)
                    swing -= 1
                    if swing <= 0 {
                        let es = catalog.enemyTypes[enemies[ei].typeIndex].stats
                        unit.hp -= rngCombat.double(in: es.damageMin...es.damageMax)
                        swing = Simulation.fireTicks(MilitiaTunables.enemySwingInterval)
                        if unit.hp <= 0 {
                            militiaDeaths += 1
                            claimed.remove(unit.targetSpawnID)
                            blockedSpawnIDs.remove(unit.targetSpawnID)
                            g.enemySwingTicks[unit.targetSpawnID] = nil
                            unit.state = .dead
                            unit.targetSpawnID = -1
                            unit.respawnTicksLeft =
                                Simulation.fireTicks(stats.meleeUnitRespawnSeconds)
                        }
                    }
                    g.enemySwingTicks[unit.targetSpawnID >= 0 ? unit.targetSpawnID : -1] =
                        unit.targetSpawnID >= 0 ? swing : nil
                }

                g.units[ui] = unit
            }
            garrisons[slot] = g
        }
    }

    private func launch(from origin: Point, at target: Int, typeIndex: Int, towerLevel: Int) {
        let lvl = catalog.towerTypes[typeIndex].levels[towerLevel]
        projectiles.append(Projectile(
            position: origin,
            aim: positions[target],
            targetSpawnID: lvl.aoeRadius > 0 ? -1 : enemies[target].spawnID,
            towerTypeIndex: typeIndex,
            towerLevel: towerLevel
        ))
    }

    private func stepProjectiles(dt: Double) {
        guard !projectiles.isEmpty else { return }
        for pi in 0..<projectiles.count {
            var p = projectiles[pi]
            let lvl = catalog.towerTypes[p.towerTypeIndex].levels[p.towerLevel]
            let travel = lvl.projectileSpeed * dt

            var destination = p.aim
            var targetIndex = -1
            if p.targetSpawnID >= 0 {
                // Homing: chase the target's current position; fizzle if gone.
                for i in 0..<enemies.count where !enemies[i].removed
                    && enemies[i].spawnID == p.targetSpawnID {
                    targetIndex = i
                    break
                }
                guard targetIndex >= 0 else {
                    p.removed = true
                    projectiles[pi] = p
                    projFizzles += 1
                    continue
                }
                destination = positions[targetIndex]
            }

            let dist = p.position.distance(to: destination)
            if dist <= travel {
                projImpacts += 1
                if p.targetSpawnID >= 0 {
                    applyVolley(lvl, to: targetIndex, isPrimary: true, blastFraction: nil)
                } else {
                    detonate(lvl, at: destination)
                }
                p.removed = true
            } else {
                p.position = Point.lerp(p.position, destination, travel / dist)
            }
            projectiles[pi] = p
        }
        if projectiles.contains(where: { $0.removed }) {
            projectiles.removeAll { $0.removed }
        }
    }

    /// Ballistic detonation: the blast happens where the shell lands, against
    /// enemies there NOW — no primary target, so no contagion application.
    private func detonate(_ lvl: TowerLevel, at center: Point) {
        let r2 = lvl.aoeRadius * lvl.aoeRadius
        for i in 0..<enemies.count where !enemies[i].removed {
            let d2 = positions[i].squaredDistance(to: center)
            if d2 <= r2 {
                let t = pow(min(1.0, d2.squareRoot() / lvl.aoeRadius), lvl.aoeFalloffExponent)
                applyVolley(lvl, to: i, isPrimary: false, blastFraction: t)
            }
        }
    }

    /// Fire cadence in whole engine ticks, computed in Double once so both
    /// engines agree exactly (0.8s at 30tps == 24 ticks, never 25).
    public static func fireTicks(_ fireInterval: Double) -> Int {
        max(1, Int((fireInterval * Double(SimClock.ticksPerSecond)).rounded()))
    }

    // MARK: - Targeting & damage

    private func selectTarget(from origin: Point, range: Double, targeting: Targeting) -> Int? {
        let r2 = range * range
        var best: Int? = nil
        var bestKey = -Double.infinity
        for i in 0..<enemies.count where !enemies[i].removed {
            guard positions[i].squaredDistance(to: origin) <= r2 else { continue }
            let e = enemies[i]
            let key: Double
            switch targeting {
            case .first: key = e.distance
            case .last: key = -e.distance
            case .strongest: key = e.hp
            case .shakiest:
                // Prefer units that can still be broken; already-Broken units
                // rank behind everything else.
                key = e.state == .broken ? -1_000_000 : -e.morale
            }
            if key > bestKey {
                bestKey = key
                best = i
            }
        }
        return best
    }

    private func fire(level lvl: TowerLevel, at primary: Int) {
        if lvl.aoeRadius > 0 {
            let center = positions[primary]
            let r2 = lvl.aoeRadius * lvl.aoeRadius
            for i in 0..<enemies.count where !enemies[i].removed {
                let d2 = positions[i].squaredDistance(to: center)
                if d2 <= r2 {
                    // KR blast model: max damage at the impact center falling
                    // to min at the edge; no roll — distance is the roll.
                    let t = pow(min(1.0, d2.squareRoot() / lvl.aoeRadius), lvl.aoeFalloffExponent)
                    applyVolley(lvl, to: i, isPrimary: i == primary, blastFraction: t)
                }
            }
        } else {
            applyVolley(lvl, to: primary, isPrimary: true, blastFraction: nil)
        }
    }

    private func applyVolley(
        _ lvl: TowerLevel, to index: Int, isPrimary: Bool, blastFraction: Double?
    ) {
        var e = enemies[index]
        guard !e.removed else { return }
        let stats = catalog.enemyTypes[e.typeIndex].stats

        // Shot vs cover. Splash pierces part of the cover (KR: half).
        if lvl.shotMax > 0 {
            let damage: Double
            let effCover: Double
            if let t = blastFraction {
                damage = lvl.shotMax - (lvl.shotMax - lvl.shotMin) * t
                effCover = stats.cover * (1.0 - lvl.splashCoverPierce)
            } else {
                damage = rngCombat.double(in: lvl.shotMin...lvl.shotMax)
                effCover = stats.cover
            }
            e.hp -= damage * (1.0 - effCover)
        }

        // Terror vs discipline (aura bonus caps at full immunity).
        if lvl.terrorMax > 0 {
            let effDiscipline = min(1.0, stats.discipline + disciplineBonus[index])
            if effDiscipline < 1.0 {
                let terror: Double
                if let t = blastFraction {
                    terror = lvl.terrorMax - (lvl.terrorMax - lvl.terrorMin) * t
                } else {
                    terror = rngCombat.double(in: lvl.terrorMin...lvl.terrorMax)
                }
                e.morale -= terror * (1.0 - effDiscipline)
            }
        }

        // Contagion application (primary target only) vs hardiness.
        if isPrimary, lvl.contagionChance > 0, !e.infected {
            if rngCombat.chance(lvl.contagionChance * (1.0 - stats.hardiness)) {
                e.infected = true
            }
        }

        if e.hp <= 0 {
            kill(&e)
        }
        enemies[index] = e
    }

    // MARK: - Contagion

    private func contagionTick(interval: Double) {
        let n = enemies.count
        // Drain phase: HP down to the floor, then morale pressure instead.
        for i in 0..<n where !enemies[i].removed && enemies[i].infected {
            var e = enemies[i]
            let stats = catalog.enemyTypes[e.typeIndex].stats
            let floor = stats.maxHP * Tunables.diseaseHPFloorFraction
            if e.hp > floor {
                e.hp = max(floor, e.hp - Tunables.diseaseHPPerSecond * interval)
            } else {
                let effDiscipline = min(1.0, stats.discipline + disciplineBonus[i])
                if effDiscipline < 1.0 {
                    e.morale -= Tunables.diseaseMoralePerSecond * interval * (1.0 - effDiscipline)
                }
            }
            enemies[i] = e
        }
        // Spread phase: proximity transmission. Slows clump enemies; clumped
        // enemies infect each other faster — the epidemic-amplifier interaction.
        let r2 = Tunables.contagionSpreadRadius * Tunables.contagionSpreadRadius
        for i in 0..<n where !enemies[i].removed && enemies[i].infected {
            for j in 0..<n where j != i && !enemies[j].removed && !enemies[j].infected {
                guard positions[i].squaredDistance(to: positions[j]) <= r2 else { continue }
                let hardiness = catalog.enemyTypes[enemies[j].typeIndex].stats.hardiness
                if rngContagion.chance(Tunables.contagionSpreadChance * (1.0 - hardiness)) {
                    enemies[j].infected = true
                }
            }
        }
    }

    // MARK: - Morale

    private func resolveMorale(dt: Double) {
        let n = enemies.count

        // Regen and Shaken transitions.
        for i in 0..<n where !enemies[i].removed {
            var e = enemies[i]
            if e.state != .broken {
                e.morale = min(Tunables.moraleMax, e.morale + moraleRegen[i] * dt)
                let stats = catalog.enemyTypes[e.typeIndex].stats
                let steadyGate = e.isSteadyAdvance
                    && e.hp > stats.maxHP * Tunables.steadyAdvanceHPGate
                if e.state == .steady, e.morale <= e.shakenThreshold, !steadyGate {
                    e.state = .shaken
                } else if e.state == .shaken, e.morale > e.shakenThreshold {
                    e.state = .steady   // rallied back above threshold
                }
            }
            enemies[i] = e
        }

        // Break cascade: breaking units splash morale damage, which can break
        // neighbours in the same tick — iterate until quiescent. Bounded by n.
        var anyBroke = true
        while anyBroke {
            anyBroke = false
            for i in 0..<n where !enemies[i].removed {
                var e = enemies[i]
                guard e.state != .broken, e.morale <= 0 else { continue }
                anyBroke = true
                e.state = .broken

                // Splash to neighbours.
                let mult = e.isWavering ? Tunables.waveringSplashMultiplier : 1.0
                let splash = Tunables.breakMoraleSplash * mult
                let r2 = Tunables.breakSplashRadius * Tunables.breakSplashRadius
                for j in 0..<n where j != i && !enemies[j].removed && enemies[j].state != .broken {
                    guard positions[i].squaredDistance(to: positions[j]) <= r2 else { continue }
                    let stats = catalog.enemyTypes[enemies[j].typeIndex].stats
                    let effDiscipline = min(1.0, stats.discipline + disciplineBonus[j])
                    enemies[j].morale -= splash * (1.0 - effDiscipline)
                }

                // Mercenaries surrender on the spot rather than routing.
                if e.isMercenary {
                    remove(&e, fate: .captured)
                }
                enemies[i] = e
            }
        }
    }

    // MARK: - Removal & economy

    private func kill(_ e: inout Enemy) {
        // Killing a routing unit still pays full — finishing routers is the
        // sharpshooter's payoff.
        remove(&e, fate: .killed)
    }

    private func remove(_ e: inout Enemy, fate: EnemyFate) {
        guard !e.removed else { return }
        e.removed = true
        let type = catalog.enemyTypes[e.typeIndex]
        let base = Double(type.stats.gold)
        let earned: Int
        switch fate {
        case .killed:
            killed += 1
            earned = Int((base * Tunables.killBountyMultiplier).rounded())
        case .routed:
            routed += 1
            earned = Int((base * Tunables.routBountyMultiplier).rounded())
        case .captured:
            captured += 1
            earned = Int((base * Tunables.captureBountyMultiplier).rounded())
        case .leaked:
            leaked += 1
            if e.waveIndex < leaksByWave.count {
                leaksByWave[e.waveIndex] += 1
            }
            earned = 0
        }
        gold += earned
        goldEarned += earned
        fatesByType[e.typeIndex][fateIndex(fate)] += 1

        // Command aura holders shock their own side when they fall.
        for trait in type.traits {
            if case let .commandAura(radius, _, deathShock) = trait, fate == .killed {
                deathShockSplash(around: e, radius: radius, amount: deathShock)
            }
        }
        emit(.enemyRemoved(spawnID: e.spawnID, typeID: type.id, fate: fate))
    }

    private func deathShockSplash(around e: Enemy, radius: Double, amount: Double) {
        guard let origin = positionOf(e) else { return }
        let r2 = radius * radius
        for j in 0..<enemies.count where !enemies[j].removed && enemies[j].state != .broken {
            guard j < positions.count else { continue }
            guard positions[j].squaredDistance(to: origin) <= r2 else { continue }
            let stats = catalog.enemyTypes[enemies[j].typeIndex].stats
            let effDiscipline = min(1.0, stats.discipline + disciplineBonus[j])
            enemies[j].morale -= amount * (1.0 - effDiscipline)
        }
    }

    private func positionOf(_ e: Enemy) -> Point? {
        guard e.pathIndex < level.paths.count else { return nil }
        return level.paths[e.pathIndex].point(atDistance: e.distance)
    }

    private func fateIndex(_ f: EnemyFate) -> Int {
        switch f {
        case .killed: return 0
        case .routed: return 1
        case .captured: return 2
        case .leaked: return 3
        }
    }

    // MARK: - Result

    private func makeResult() -> SimulationResult {
        var perType: [UUID: SimulationResult.TypeFates] = [:]
        for (i, type) in catalog.enemyTypes.enumerated() {
            let f = fatesByType[i]
            if f[0] + f[1] + f[2] + f[3] > 0 {
                perType[type.id] = SimulationResult.TypeFates(
                    killed: f[0], routed: f[1], captured: f[2], leaked: f[3]
                )
            }
        }
        return SimulationResult(
            outcome: outcome ?? .timeout,
            seconds: time,
            livesRemaining: max(0, lives),
            goldRemaining: gold,
            goldEarned: goldEarned,
            killed: killed,
            routed: routed,
            captured: captured,
            leaked: leaked,
            fatesByTypeID: perType,
            waveMaxProgress: waveMaxProgress,
            leaksByWave: leaksByWave
        )
    }
}
