import Foundation
import CoreGraphics

/// Read-only reconstruction. Consumes recorded state changes; never creates a
/// battle engine, makes a targeting decision, applies damage, or draws RNG.
final class BattleEventPlayback {
    private struct MilitiaPose {
        var position: Point
        var facing: UnitFacing = .south
        var phase = 0.0
        var walking = false
    }
    private var militiaPoses: [Int: MilitiaPose] = [:]
    private var heroPoses: [Int: HeroWalkPose] = [:]
    private var animationTick: Int64?

    func frame(block: BattleEventBlock, tick: Int64, setup: LevelReplaySetup,
               previous: LevelReplayFrame?) throws -> LevelReplayFrame {
        guard tick >= block.firstTick, tick <= block.lastTick,
              block.lastTick - block.firstTick < 256 else {
            throw DbError.Db(message: "battle events: invalid block at tick \(tick)")
        }
        let clock = try block.clockNumbers.values(at: tick)
        guard clock.count == 3, clock.allSatisfy(\.isFinite), clock[0] >= 0,
              clock[0] <= Double(tick), clock[0].rounded(.down) == clock[0],
              clock[1] >= 0, (0...1).contains(clock[2]) else {
            throw DbError.Db(message: "battle events: invalid clock at tick \(tick)")
        }
        let step = Int64(clock[0]), advances = animationTick != nil && animationTick != step
        let units = try block.units.value(at: tick), values = try block.unitNumbers.values(at: tick)
        // Old event recordings have seven values and no swing clock. Their
        // recorded movement still plays; new records also preserve real hits.
        let unitStride = values.count == units.count * 8 ? 8 : 7
        guard values.count == units.count * unitStride, values.allSatisfy(\.isFinite),
              Set(units.map { "\($0.hero):\($0.id)" }).count == units.count else {
            throw DbError.Db(message: "battle events: invalid unit data at tick \(tick)")
        }
        let state = try block.status.value(at: tick)
        var militia: [BattleEngine.MilitiaSoldier] = [], heroes: [LevelReplayFrame.Hero] = []
        var presentMilitia: Set<Int> = [], presentHeroes: Set<Int> = []
        for (index, unit) in units.enumerated() {
            let offset = index * unitStride
            let position = Point(values[offset], values[offset + 1])
            let hasTarget = values[offset + 3], respawned = values[offset + 6]
            guard (hasTarget == 0 || hasTarget == 1), (respawned == 0 || respawned == 1),
                  unit.maxHP.isFinite, unit.maxHP > 0, values[offset + 2] > 0 else {
                throw DbError.Db(message: "battle events: invalid unit \(unit.id) at tick \(tick)")
            }
            let target = Point(values[offset + 4], values[offset + 5])
            if unit.hero {
                presentHeroes.insert(unit.id)
                var pose = heroPoses[unit.id] ?? HeroWalkPose(baseAssetName: unit.baseAsset, position: position)
                if advances {
                    if respawned == 1 { pose = HeroWalkPose(baseAssetName: unit.baseAsset, position: position) }
                    pose.advance(to: position)
                    if hasTarget == 1 { pose.face(toward: target) }
                }
                heroPoses[unit.id] = pose
                let sample = pose.sample(alpha: 1)
                heroes.append(LevelReplayFrame.Hero(id: unit.id, assetName: sample.assetName,
                    baseAssetName: unit.baseAsset, position: CGPoint(x: sample.position.x, y: sample.position.y),
                    hp: values[offset + 2], maxHP: unit.maxHP, isSelected: state.selectedHero == unit.id))
            } else {
                let family: MeleeUnitFamily
                if unit.baseAsset.isEmpty {
                    // Historical events used an empty base asset for both
                    // groups. Their recorded identity retains deployment kind.
                    family = MeleeUnitFamily(recordedSoldierID: unit.id)
                } else if let recorded = MeleeUnitFamily(rawValue: unit.baseAsset),
                          recorded == MeleeUnitFamily(recordedSoldierID: unit.id) {
                    family = recorded
                } else {
                    throw DbError.Db(message: "battle events: invalid melee family '\(unit.baseAsset)' for unit \(unit.id) at tick \(tick)")
                }
                presentMilitia.insert(unit.id)
                var pose = militiaPoses[unit.id] ?? MilitiaPose(position: position)
                if advances {
                    // A respawn changes position instantly, without a walk cycle.
                    if respawned == 1 { pose.position = position }
                    let dx = position.x - pose.position.x, dy = position.y - pose.position.y
                    let moved = (dx * dx + dy * dy).squareRoot()
                    pose.walking = moved > MeleeWalkCycle.walkingThreshold
                    if pose.walking {
                        pose.facing = UnitFacing(dx: dx, dy: dy)
                        pose.phase = (pose.phase + moved).truncatingRemainder(dividingBy: MeleeWalkCycle.cycleDistance)
                    }
                }
                if hasTarget == 1, target != position {
                    pose.facing = UnitFacing(dx: target.x - position.x, dy: target.y - position.y)
                }
                pose.position = position; militiaPoses[unit.id] = pose
                let assetName: String
                if unitStride == 8 {
                    let swing = values[offset + 7]
                    guard let interval = unit.attackInterval, interval.isFinite, interval > 0,
                          interval < Double(Int.max) / Double(SimClock.ticksPerSecond),
                          swing >= 0, swing < Double(Int.max), swing.rounded(.down) == swing else {
                        throw DbError.Db(message: "battle events: invalid melee swing for unit \(unit.id) at tick \(tick)")
                    }
                    assetName = MeleeAttackCycle.assetName(family: family, facing: pose.facing, walkPhase: pose.phase,
                        isWalking: pose.walking, isFighting: hasTarget == 1,
                        swingTicksLeft: Int(swing), attackInterval: interval)
                } else {
                    assetName = MeleeWalkCycle.assetName(family: family, facing: pose.facing,
                        walkPhase: pose.phase, isWalking: pose.walking)
                }
                militia.append(BattleEngine.MilitiaSoldier(id: unit.id,
                    assetName: assetName,
                    position: CGPoint(x: position.x, y: position.y), hp: values[offset + 2], maxHP: unit.maxHP))
            }
        }
        militiaPoses = militiaPoses.filter { presentMilitia.contains($0.key) }
        heroPoses = heroPoses.filter { presentHeroes.contains($0.key) }
        animationTick = step
        return try LevelReplayFrame(events: block, tick: tick, setup: setup, previous: previous,
                                    militia: militia, heroes: heroes, clock: clock)
    }
}

extension LevelReplayFrame {
    fileprivate init(events block: BattleEventBlock, tick: Int64, setup: LevelReplaySetup,
                     previous: LevelReplayFrame?, militia: [BattleEngine.MilitiaSoldier],
                     heroes: [Hero], clock: [Double]) throws {
        let state = try block.status.value(at: tick)
        let controls = try block.controls.value(at: tick)
        var walkers = try block.enemies.value(at: tick)
        let enemyValues = try block.enemyNumbers.values(at: tick)
        var projectiles = try block.projectiles.value(at: tick)
        let projectileValues = try block.projectileNumbers.values(at: tick)
        guard enemyValues.count == walkers.count * 8, projectileValues.count == projectiles.count * 5,
              Set(walkers.map(\.id)).count == walkers.count,
              Set(projectiles.map(\.id)).count == projectiles.count else {
            throw DbError.Db(message: "battle events: missing or duplicate entity data at tick \(tick)")
        }
        for i in walkers.indices {
            let v = Array(enemyValues[(i * 8)..<(i * 8 + 8)])
            guard v.enumerated().allSatisfy({ $0.offset == 5 ? !$0.element.isNaN && $0.element >= 0 : $0.element.isFinite }),
                  walkers[i].maxHP > 0, v[0] > 0, v[3] >= 0,
                  setup.level.paths.indices.contains(walkers[i].pathIndex) else {
                throw DbError.Db(message: "battle events: invalid enemy \(walkers[i].id) at tick \(tick)")
            }
            walkers[i].hp = v[0]; walkers[i].position = CGPoint(x: v[1], y: v[2]); walkers[i].pathDistance = v[3]
            walkers[i].morale.restoreRecordedValues(value: v[4], age: v[5], before: v[6], direction: v[7])
        }
        for i in projectiles.indices {
            let v = Array(projectileValues[(i * 5)..<(i * 5 + 5)])
            guard v.allSatisfy(\.isFinite) else { throw DbError.Db(message: "battle events: invalid projectile \(projectiles[i].id)") }
            projectiles[i].position = CGPoint(x: v[0], y: v[1]); projectiles[i].heading = v[2]
            projectiles[i].grapeshot?.remainingDistance = v[3]
            projectiles[i].solidShot?.restoreRecordedDistance(v[4])
        }
        self.tick = tick; money = state.money; lives = state.lives; wave = state.wave
        outcome = state.outcome; paused = state.paused; speed = state.speed
        _ = try PlaySpeed(speed)
        presentation = BattlePresentation(walkers: walkers, projectiles: projectiles, paths: setup.level.paths,
            previousWalkerDistances: previous.map { Dictionary(uniqueKeysWithValues: $0.presentation.walkers.map { ($0.id, $0.pathDistance) }) } ?? [:],
            previousProjectilePositions: previous.map { Dictionary(uniqueKeysWithValues: $0.presentation.projectiles.map { ($0.id, $0.position) }) } ?? [:])
        towers = try block.towers.value(at: tick); towerTuning = try block.tuning.value(at: tick)
        guard Set(towers.map(\.slotIndex)) == Set(towerTuning.keys) else {
            throw DbError.Db(message: "battle events: missing tower tuning at tick \(tick)")
        }
        self.militia = militia; self.heroes = heroes
        impacts = try block.impacts.value(at: tick); obstacles = try block.obstacles.value(at: tick)
        rallies = state.rallies; slowingTowerSlots = state.slowingSlots
        damageBySlot = state.damage; targetingSecondsBySlot = state.targeting; shotsBySlot = state.shots
        selectedSlot = state.selectedSlot; selectedTower = state.selectedTower; selectedHero = state.selectedHero
        hud = try setup.hudLayout == nil ? nil : LevelHUDState(events: controls, state: state, setup: setup, tick: tick,
            cooldown: ReinforcementCooldown(remainingSeconds: clock[1], remainingFraction: clock[2]))
    }
}

extension LevelHUDState {
    fileprivate init(events controls: BattleEventControls, state: BattleEventStatus, setup: LevelReplaySetup,
                     tick: Int64, cooldown: ReinforcementCooldown) throws {
        heroes = try controls.heroes.enumerated().map { index, id in
            guard let hero = setup.heroes.first(where: { $0.id == id }) else {
                throw DbError.Db(message: "battle events: missing hero \(id) in recorded setup")
            }
            let role: HeroSelection.Role = index == 0 ? .primary : .secondary
            return HeroButton(id: hero.id, portrait: hero.iconImageName,
                label: "\(role.title), \(hero.shortName), ranking \(hero.ranking)",
                isAvailable: controls.availableHeroes.contains(hero.id), isSelected: controls.selectedHero == hero.id)
        }
        reinforcementCooldown = cooldown; canCallReinforcements = controls.canReinforce
        isPlacingReinforcements = controls.placingReinforcements
        lives = state.lives; money = state.money; wave = controls.wave; waveCount = setup.level.waves.count
        isPaused = state.paused; seconds = Double(tick) * (1 / Double(setup.ticksPerSecond))
        activated = LevelHUDControl.allCases.filter {
            guard let start = controls.activationTicks[$0] else { return false }
            return Double(tick - start) * (1 / Double(setup.ticksPerSecond)) < Self.activationSeconds
        }
        callWavePositions = controls.wavePositions; nextWave = controls.nextWave
        countdownSeconds = controls.countdown; callWaveSelection = controls.waveSelection
    }
}
