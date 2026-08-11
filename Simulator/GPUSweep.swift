import Foundation
import Metal

final class GPUEngine {
    let device: MTLDevice
    let queue: MTLCommandQueue
    let pipeline: MTLComputePipelineState
    var threadTickBudget = 16_000_000
    private var pool: [String: MTLBuffer] = [:]

    private func pooledBuffer(_ name: String, minLength: Int) throws -> MTLBuffer {
        if let b = pool[name], b.length >= minLength { return b }
        guard let b = device.makeBuffer(length: minLength) else {
            throw DbError.Db(message: "Metal buffer allocation failed (\(name), \(minLength) bytes)")
        }
        pool[name] = b
        return b
    }

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw DbError.Db(message: "No Metal device available")
        }
        self.device = device
        guard let queue = device.makeCommandQueue() else {
            throw DbError.Db(message: "Unable to create Metal command queue")
        }
        self.queue = queue

        let library = try Self.loadLibrary(device: device)
        guard let fn = library.makeFunction(name: "simulate") else {
            throw DbError.Db(message: "Kernel 'simulate' not found in Metal library")
        }
        self.pipeline = try device.makeComputePipelineState(function: fn)
    }

    private static func loadLibrary(device: MTLDevice) throws -> MTLLibrary {
        if let execURL = Bundle.main.executableURL {
            let lib = execURL.deletingLastPathComponent().appendingPathComponent("default.metallib")
            if FileManager.default.fileExists(atPath: lib.path),
               let library = try? device.makeLibrary(URL: lib) {
                return library
            }
        }
        let fm = FileManager.default
        let kernelPath = "Simulator/SimKernel.metal"
        let headerPath = "Simulator/SimGPUTypes.h"
        if fm.fileExists(atPath: kernelPath), fm.fileExists(atPath: headerPath) {
            let header = try String(contentsOfFile: headerPath, encoding: .utf8)
            var source = try String(contentsOfFile: kernelPath, encoding: .utf8)
            source = source.replacingOccurrences(of: "#include \"SimGPUTypes.h\"", with: header)
            return try device.makeLibrary(source: source, options: nil)
        }
        throw DbError.Db(message: "No default.metallib beside executable and no Simulator/SimKernel.metal in cwd")
    }
}

enum GPUBuild {
    static func levelGPU(level: LevelInfo, catalog: ContentCatalog) throws -> LevelGPU {
        guard level.paths.count <= Int(SIM_MAX_PATHS),
              level.paths.allSatisfy({ $0.points.count <= Int(SIM_MAX_PATH_POINTS) }),
              level.towerSlots.count <= Int(SIM_MAX_SLOTS),
              level.waves.count <= Int(SIM_MAX_WAVES),
              catalog.enemyTypes.count <= Int(SIM_MAX_ENEMY_TYPES)
        else { throw DbError.Db(message: "Level exceeds GPU caps (paths/points/slots/waves/types)") }

        var lvl = LevelGPU()
        lvl.pathCount = UInt32(level.paths.count)
        lvl.slotCount = UInt32(level.towerSlots.count)
        lvl.enemyTypeCount = UInt32(catalog.enemyTypes.count)
        lvl.numWaves = UInt32(level.waves.count)
        lvl.lives = Int32(level.numStartingLives)

        withUnsafeMutablePointer(to: &lvl) { p in
            let raw = UnsafeMutableRawPointer(p)
            let countsOff = MemoryLayout<LevelGPU>.offset(of: \.pathPointCount)!
            let totalsOff = MemoryLayout<LevelGPU>.offset(of: \.pathTotalLength)!
            let pointsOff = MemoryLayout<LevelGPU>.offset(of: \.pathPoints)!
            let cumOff = MemoryLayout<LevelGPU>.offset(of: \.pathCumulative)!
            let slotsOff = MemoryLayout<LevelGPU>.offset(of: \.slots)!
            let typesOff = MemoryLayout<LevelGPU>.offset(of: \.enemyTypes)!
            for (pi, path) in level.paths.enumerated() {
                raw.storeBytes(of: UInt32(path.points.count), toByteOffset: countsOff + pi * 4, as: UInt32.self)
                raw.storeBytes(of: Float(path.totalLength), toByteOffset: totalsOff + pi * 4, as: Float.self)
                for (i, pt) in path.points.enumerated() {
                    let off = pointsOff + (pi * Int(SIM_MAX_PATH_POINTS) + i) * MemoryLayout<simd_float2>.stride
                    raw.storeBytes(of: simd_float2(Float(pt.x), Float(pt.y)), toByteOffset: off, as: simd_float2.self)
                }
                for (i, c) in path.cumulative.enumerated() {
                    raw.storeBytes(of: Float(c), toByteOffset: cumOff + (pi * Int(SIM_MAX_PATH_POINTS) + i) * 4, as: Float.self)
                }
            }
            for (i, slot) in level.towerSlots.enumerated() {
                let off = slotsOff + i * MemoryLayout<simd_float2>.stride
                raw.storeBytes(of: simd_float2(Float(slot.position.x), Float(slot.position.y)), toByteOffset: off, as: simd_float2.self)
            }
            for (i, type) in catalog.enemyTypes.enumerated() {
                var t = EnemyTypeGPU()
                let s = type.stats
                t.maxHP = Float(s.maxHP); t.speed = Float(s.speed)
                t.cover = Float(s.cover); t.discipline = Float(s.discipline)
                t.hardiness = Float(s.hardiness)
                t.breakLo = Float(s.breakBand.lowerBound); t.breakHi = Float(s.breakBand.upperBound)
                t.damageMin = Float(s.damageMin); t.damageMax = Float(s.damageMax)
                t.gold = Int32(s.gold); t.livesCost = Int32(s.livesCost)
                var flags: UInt32 = 0
                for trait in type.traits {
                    switch trait {
                    case .wavering: flags |= UInt32(SIM_TRAIT_WAVERING)
                    case .mercenary: flags |= UInt32(SIM_TRAIT_MERCENARY)
                    case .steadyAdvance: flags |= UInt32(SIM_TRAIT_STEADY_ADVANCE)
                    case .rideDown: flags |= UInt32(SIM_TRAIT_RIDE_DOWN)
                    case let .rallyBeat(radius, rate):
                        flags |= UInt32(SIM_TRAIT_RALLY)
                        t.auraRadius = Float(radius); t.auraRate = Float(rate)
                    case let .commandAura(radius, bonus, shock):
                        flags |= UInt32(SIM_TRAIT_COMMAND)
                        t.cmdRadius = Float(radius); t.cmdBonus = Float(bonus); t.cmdShock = Float(shock)
                    default: break
                    }
                }
                t.flags = flags
                raw.storeBytes(of: t, toByteOffset: typesOff + i * MemoryLayout<EnemyTypeGPU>.stride, as: EnemyTypeGPU.self)
            }
        }

        lvl.moraleMax = Float(Tunables.moraleMax)
        lvl.baseMoraleRegen = Float(Tunables.baseMoraleRegenPerSecond)
        lvl.breakSplash = Float(Tunables.breakMoraleSplash)
        lvl.breakSplashRadius = Float(Tunables.breakSplashRadius)
        lvl.waveringSplashMult = Float(Tunables.waveringSplashMultiplier)
        lvl.shakenSpeedMult = Float(Tunables.shakenSpeedMultiplier)
        lvl.routSpeedMult = Float(Tunables.routSpeedMultiplier)
        lvl.steadyAdvanceHPGate = Float(Tunables.steadyAdvanceHPGate)
        lvl.contagionTickInterval = Float(Tunables.contagionTickInterval)
        lvl.diseaseHPPerSecond = Float(Tunables.diseaseHPPerSecond)
        lvl.diseaseHPFloorFraction = Float(Tunables.diseaseHPFloorFraction)
        lvl.diseaseMoralePerSecond = Float(Tunables.diseaseMoralePerSecond)
        lvl.contagionSpreadRadius = Float(Tunables.contagionSpreadRadius)
        lvl.contagionSpreadChance = Float(Tunables.contagionSpreadChance)
        lvl.killBountyMult = Float(Tunables.killBountyMultiplier)
        lvl.routBountyMult = Float(Tunables.routBountyMultiplier)
        lvl.captureBountyMult = Float(Tunables.captureBountyMultiplier)
        lvl.dt = Float(SimClock.dt)
        lvl.ticksPerSecond = Int32(SimClock.ticksPerSecond)
        lvl.militiaMoveSpeed = Float(MilitiaTunables.moveSpeed)
        lvl.militiaEngageScanRadius = Float(MilitiaTunables.engageScanRadius)
        lvl.militiaMeleeReach = Float(MilitiaTunables.meleeReach)
        lvl.militiaLeashRadius = Float(MilitiaTunables.leashRadius)
        lvl.militiaRallySpread = Float(MilitiaTunables.rallySpread)
        lvl.militiaEnemySwingTicks = Int32(Simulation.fireTicks(MilitiaTunables.enemySwingInterval))
        return lvl
    }

    static func permGPU(
        level: LevelInfo, catalog: ContentCatalog, money: Int
    ) throws -> PermGPU {
        var perm = PermGPU()
        perm.money = Int32(money)
        perm.lives = Int32(level.numStartingLives)
        perm.kindCount = UInt32(catalog.towerTypes.count)
        guard catalog.towerTypes.count <= Int(SIM_MAX_TOWER_KINDS),
              catalog.towerTypes.allSatisfy({ $0.levels.count <= Int(SIM_MAX_TOWER_LEVELS) }),
              catalog.towerTypes.allSatisfy({ $0.levels.allSatisfy {
                  $0.meleeUnitCount <= Int(SIM_MAX_MELEE_UNITS_PER) } })
        else { throw DbError.Db(message: "Catalog exceeds GPU tower caps") }

        var sched: [(time: Double, type: Int, path: Int, wave: Int)] = []
        for (wi, wave) in level.waves.enumerated() {
            for entry in wave.spawns {
                let typeIndex = try catalog.requireEnemyIndex(id: entry.enemyTypeID)
                for k in 0..<entry.count {
                    sched.append((wave.startTime + entry.delay + Double(k) * entry.interval,
                                  typeIndex, entry.pathIndex, wi))
                }
            }
        }
        let sorted = sched.enumerated()
            .sorted { ($0.element.time, $0.offset) < ($1.element.time, $1.offset) }
            .map { $0.element }
        guard sorted.count <= Int(SIM_MAX_SPAWNS) else {
            throw DbError.Db(message: "Schedule (\(sorted.count)) exceeds SIM_MAX_SPAWNS")
        }
        perm.spawnCount = UInt32(sorted.count)

        let proto = GreedyCommander(level: level, catalog: catalog)
        perm.planLen = UInt32(min(proto.plan.count, Int(SIM_PLAN_LEN)))
        perm.w1CutoffSeconds = Float(level.waves.count > 1 ? level.waves[1].startTime + 25 : 600)

        withUnsafeMutablePointer(to: &perm) { p in
            let raw = UnsafeMutableRawPointer(p)
            let levelsOff = MemoryLayout<PermGPU>.offset(of: \.levelsPerKind)!
            let towersOff = MemoryLayout<PermGPU>.offset(of: \.towers)!
            let spawnsOff = MemoryLayout<PermGPU>.offset(of: \.spawns)!
            let orderOff = MemoryLayout<PermGPU>.offset(of: \.slotOrder)!
            let planOff = MemoryLayout<PermGPU>.offset(of: \.planKind)!

            for (k, type) in catalog.towerTypes.enumerated() {
                raw.storeBytes(of: UInt32(type.levels.count), toByteOffset: levelsOff + k * 4, as: UInt32.self)
                for (li, l) in type.levels.enumerated() {
                    var t = TowerLevelGPU()
                    t.cost = Int32(l.cost)
                    t.range = Float(l.range)
                    t.fireInterval = Float(l.fireInterval)
                    t.shotMinDamage = Float(l.shotMinDamage); t.shotMaxDamage = Float(l.shotMaxDamage)
                    t.terrorMin = Float(l.terrorMin); t.terrorMax = Float(l.terrorMax)
                    t.aoeRadius = Float(l.aoeRadius)
                    t.aoeFalloffExponent = Float(l.aoeFalloffExponent)
                    t.splashCoverPierce = Float(l.splashCoverPierce)
                    t.contagionChance = Float(l.contagionChance)
                    t.fireTicks = Int32(Simulation.fireTicks(l.fireInterval))
                    t.projectileSpeed = Float(l.projectileSpeed)
                    t.meleeUnitCount = Int32(l.meleeUnitCount)
                    t.meleeUnitHP = Float(l.meleeUnitHP)
                    t.meleeDamageMin = Float(l.meleeUnitDamageMin)
                    t.meleeDamageMax = Float(l.meleeUnitDamageMax)
                    t.meleeAttackTicks = Int32(Simulation.fireTicks(l.meleeUnitAttackInterval))
                    t.meleeRespawnTicks = Int32(Simulation.fireTicks(l.meleeUnitRespawnSeconds))
                    t.meleeHealPerSecond = Float(l.meleeUnitHealPerSecond)
                    switch l.targeting {
                    case .first: t.targeting = UInt32(SIM_TARGET_FIRST)
                    case .last: t.targeting = UInt32(SIM_TARGET_LAST)
                    case .strongest: t.targeting = UInt32(SIM_TARGET_STRONGEST)
                    case .shakiest: t.targeting = UInt32(SIM_TARGET_SHAKIEST)
                    }
                    let off = towersOff + (k * Int(SIM_MAX_TOWER_LEVELS) + li) * MemoryLayout<TowerLevelGPU>.stride
                    raw.storeBytes(of: t, toByteOffset: off, as: TowerLevelGPU.self)
                }
            }
            for (i, s) in sorted.enumerated() {
                var sp = SpawnGPU()
                sp.time = Float(s.time)
                sp.typeIndex = UInt32(s.type)
                sp.pathIndex = UInt32(s.path)
                sp.waveIndex = UInt32(s.wave)
                raw.storeBytes(of: sp, toByteOffset: spawnsOff + i * MemoryLayout<SpawnGPU>.stride, as: SpawnGPU.self)
            }
            for (i, slot) in proto.slotOrder.enumerated() where i < Int(SIM_MAX_SLOTS) {
                raw.storeBytes(of: UInt32(slot), toByteOffset: orderOff + i * 4, as: UInt32.self)
            }
            for (i, towerID) in proto.plan.enumerated() where i < Int(SIM_PLAN_LEN) {
                let kind = catalog.towerTypes.firstIndex { $0.id == towerID } ?? 0
                raw.storeBytes(of: UInt32(kind), toByteOffset: planOff + i * 4, as: UInt32.self)
            }
            let speedOff = MemoryLayout<PermGPU>.offset(of: \.enemySpeed)!
            let hpOff = MemoryLayout<PermGPU>.offset(of: \.enemyMaxHP)!
            let goldOff = MemoryLayout<PermGPU>.offset(of: \.enemyGold)!
            for (i, type) in catalog.enemyTypes.enumerated() {
                raw.storeBytes(of: Float(type.stats.speed), toByteOffset: speedOff + i * 4, as: Float.self)
                raw.storeBytes(of: Float(type.stats.maxHP), toByteOffset: hpOff + i * 4, as: Float.self)
                raw.storeBytes(of: Int32(type.stats.gold), toByteOffset: goldOff + i * 4, as: Int32.self)
            }
            if let melee = catalog.towerTypes.first(where: {
                ($0.levels.first?.meleeUnitCount ?? 0) > 0
            }), let flagRange = melee.levels.first?.range {
                let rallyOff = MemoryLayout<PermGPU>.offset(of: \.rallyPoints)!
                for (i, slot) in level.towerSlots.enumerated() {
                    let rally = Simulation.defaultRallyPoint(
                        towerPosition: slot.position, flagRange: flagRange,
                        paths: level.paths)
                    raw.storeBytes(of: simd_float2(Float(rally.x), Float(rally.y)),
                                   toByteOffset: rallyOff + i * MemoryLayout<simd_float2>.stride,
                                   as: simd_float2.self)
                }
            }
        }
        return perm
    }
}

struct GPUBatchResult {
    var results: [SimResultGPU]
    var seedsPerPerm: Int
}

extension GPUEngine {
    func run(
        level: LevelGPU,
        perms: [PermGPU],
        seedsPerPerm: Int,
        baseSeed: UInt64,
        mode: UInt32,
        maxSeconds: Float = 600,
        sliceTicks: Int = 960
    ) throws -> GPUBatchResult {
        var lastError: Error?
        for attempt in 0..<4 {
            do {
                return try runOnce(level: level, perms: perms, seedsPerPerm: seedsPerPerm,
                                   baseSeed: baseSeed, mode: mode,
                                   maxSeconds: maxSeconds, sliceTicks: sliceTicks)
            } catch {
                lastError = error
                let msg = "\(error)"
                let watchdog = msg.contains("Impacting Interactivity") || msg.contains("IOGPUCommandQueue")
                let allocation = msg.contains("buffer allocation")
                guard watchdog || allocation else { throw error }
                if watchdog { threadTickBudget = max(250_000, threadTickBudget / 2) }
                usleep(allocation ? 500_000 : 100_000)
                FileHandle.standardError.write(Data(
                    "  gpu: \(watchdog ? "watchdog kill" : "allocation failure") (attempt \(attempt + 1)); rerunning batch\n".utf8))
            }
        }
        throw lastError ?? DbError.Db(message: "GPU batch failed after retries")
    }

    private func runOnce(
        level: LevelGPU,
        perms: [PermGPU],
        seedsPerPerm: Int,
        baseSeed: UInt64,
        mode: UInt32,
        maxSeconds: Float,
        sliceTicks: Int
    ) throws -> GPUBatchResult {
        let threads = perms.count * seedsPerPerm
        guard threads > 0 else { return GPUBatchResult(results: [], seedsPerPerm: seedsPerPerm) }

        var lvl = level
        let lvlBuf = try pooledBuffer("level", minLength: MemoryLayout<LevelGPU>.stride)
        lvlBuf.contents().copyMemory(from: &lvl, byteCount: MemoryLayout<LevelGPU>.stride)
        let permLen = MemoryLayout<PermGPU>.stride * perms.count
        let permBuf = try pooledBuffer("perm", minLength: permLen)
        perms.withUnsafeBytes {
            permBuf.contents().copyMemory(from: $0.baseAddress!, byteCount: permLen)
        }
        let resultLen = MemoryLayout<SimResultGPU>.stride * threads
        let resultBuf = try pooledBuffer("result", minLength: resultLen)
        let stateLen = MemoryLayout<SimStateGPU>.stride * threads
        let stateBuf = try pooledBuffer("state", minLength: stateLen)
        memset(stateBuf.contents(), 0, stateLen)
        memset(resultBuf.contents(), 0, resultLen)

        var dp = DispatchParamsGPU()
        dp.permCount = UInt32(perms.count)
        dp.seedsPerPerm = UInt32(seedsPerPerm)
        dp.mode = mode
        dp.sliceTicks = UInt32(sliceTicks)
        dp.baseSeed = baseSeed
        dp.maxSeconds = maxSeconds

        let maxTicks = Int(maxSeconds) * Int(SimClock.ticksPerSecond)
        let maxSlices = maxTicks / sliceTicks + 2
        let resultPtr = resultBuf.contents().bindMemory(to: SimResultGPU.self, capacity: threads)

        let threadsPerCmd = max(1024, threadTickBudget / sliceTicks)

        for _ in 0..<maxSlices {
            try autoreleasepool {
                var cmds: [MTLCommandBuffer] = []
                var base = 0
                while base < threads {
                    let chunk = min(threadsPerCmd, threads - base)
                    dp.threadBase = UInt32(base)
                    guard let cmd = queue.makeCommandBuffer(),
                          let enc = cmd.makeComputeCommandEncoder()
                    else { throw DbError.Db(message: "Metal encoder creation failed") }
                    enc.setComputePipelineState(pipeline)
                    enc.setBuffer(lvlBuf, offset: 0, index: 0)
                    enc.setBuffer(permBuf, offset: 0, index: 1)
                    enc.setBytes(&dp, length: MemoryLayout<DispatchParamsGPU>.stride, index: 2)
                    enc.setBuffer(resultBuf, offset: 0, index: 3)
                    enc.setBuffer(stateBuf, offset: 0, index: 4)
                    // 64, not the pipeline maximum. Simulations diverge hard - 62s to 191s of
                    // game time - and a threadgroup only retires when its slowest thread
                    // finishes, so wide groups strand lanes. Measured on an idle machine:
                    // 640 wide is 1.36x SLOWER than 64 (58.5s vs 43.2s over 40k permutations).
                    let tgWidth = min(pipeline.maxTotalThreadsPerThreadgroup, 64)
                    enc.dispatchThreads(
                        MTLSize(width: chunk, height: 1, depth: 1),
                        threadsPerThreadgroup: MTLSize(width: tgWidth, height: 1, depth: 1)
                    )
                    enc.endEncoding()
                    cmd.commit()
                    cmds.append(cmd)
                    base += chunk
                }
                cmds.last?.waitUntilCompleted()
                for cmd in cmds {
                    if let error = cmd.error {
                        throw DbError.Db(message: "GPU execution failed: \(error)")
                    }
                }
            }
            var unfinished = 0
            for i in 0..<threads where resultPtr[i].outcome == 0 { unfinished += 1 }
            if unfinished == 0 { break }
        }

        return GPUBatchResult(
            results: Array(UnsafeBufferPointer(start: resultPtr, count: threads)),
            seedsPerPerm: seedsPerPerm
        )
    }
}

enum GPUHarness {
    static func makeInputs(
        db: Db, levelName: String, fieldMelee: Bool = false
    ) throws -> (fixed: SweepFixedInputs, space: SweepSpace, base: LevelInfo) {
        var fixed = try SweepFixedInputs.load(db: db, levelName: levelName)
        fixed.fieldMelee = fieldMelee
        let base = try SweepFixedInputs.designLevel(db: db, levelName: levelName, fixed: fixed)
        let space = SweepSpace(grids: SweepGrids(), fixed: fixed, slotCount: base.towerSlots.count)
        return (fixed, space, base)
    }

    static func levelFor(perm: SweepPermutation, fixed: SweepFixedInputs, base: LevelInfo)
        -> (LevelInfo, ContentCatalog) {
        let catalog = SweepCatalog.make(perm: perm, fixed: fixed)
        let waves = SweepWaves.make(perm: perm, fixed: fixed, pathCount: base.paths.count)
        let level = LevelInfo(
            id: base.id, name: base.name, campaign: base.campaign,
            startedAt: base.startedAt, endedAt: base.endedAt,
            startingMoney: perm.money, numStartingLives: perm.lives,
            playableRect: base.playableRect,
            paths: base.paths, towerSlots: base.towerSlots, waves: waves
        )
        return (level, catalog)
    }

    static func bench(db: Db, levelName: String, sims: Int) throws {
        let (fixed, space, base) = try makeInputs(db: db, levelName: levelName)
        let perm = space.permutation(at: space.permutationCount / 2)
        let (level, catalog) = levelFor(perm: perm, fixed: fixed, base: base)
        let lvlGPU = try GPUBuild.levelGPU(level: level, catalog: catalog)
        let permGPU = try GPUBuild.permGPU(level: level, catalog: catalog, money: perm.money)

        let engine = try GPUEngine()
        _ = try engine.run(level: lvlGPU, perms: [permGPU], seedsPerPerm: 256,
                           baseSeed: 1776, mode: UInt32(SIM_MODE_GREEDY))
        let t0 = Date()
        let batch = try engine.run(level: lvlGPU, perms: [permGPU], seedsPerPerm: sims,
                                   baseSeed: 1776, mode: UInt32(SIM_MODE_GREEDY))
        let dt = Date().timeIntervalSince(t0)
        let wins = batch.results.filter { $0.outcome == SIM_OUTCOME_VICTORY }.count
        let overflow = batch.results.filter { $0.spawnOverflow > 0 }.count
        print(String(format: """

        ── bench GPU: %@ (%@) ─────────────────────
        %d sims in %.2fs  →  %.0f sims/s
        8-hour night at this rate: %.0fM sims
        sanity: %.1f%% wins, %d spawn-overflow flags (must be 0)
        ──────────────────────────────────────────
        """, levelName, engine.device.name, sims, dt, Double(sims) / dt,
        Double(sims) / dt * 8 * 3600 / 1_000_000,
        Double(wins) / Double(max(1, sims)) * 100, overflow))
    }

    static func validate(db: Db, levelName: String, seeds: Int) throws {
        let engine = try GPUEngine()
        var failures = try probeSuite(db: db, engine: engine, levelName: levelName,
                                      seeds: seeds, fieldMelee: false)
        let inputs = try SweepFixedInputs.load(db: db, levelName: levelName)
        let hasMelee = inputs.unlocks.keys.contains {
            (inputs.towerLevels[$0]?.first?.meleeUnitCount ?? 0) > 0
        }
        if hasMelee {
            failures += try meleeDuelProbe(db: db, engine: engine, levelName: levelName,
                                           seeds: seeds)
            failures += try probeSuite(db: db, engine: engine, levelName: levelName,
                                       seeds: seeds, fieldMelee: true)
        } else {
            print("  (no melee kind unlocked for this level — melee probes skipped)")
        }
        failures += try artilleryProbe(db: db, engine: engine, levelName: levelName, seeds: seeds)
        print(failures == 0
              ? "  all probes agree within sampling error — GPU engine validated ✓\n"
              : "  ⚠ \(failures) probe(s) disagree — GPU engine NOT valid, do not sweep with --gpu\n")
        if failures > 0 { exit(1) }
    }

    private static func probeSuite(
        db: Db, engine: GPUEngine, levelName: String, seeds: Int, fieldMelee: Bool
    ) throws -> Int {
        let (fixed, space, base) = try makeInputs(db: db, levelName: levelName,
                                                  fieldMelee: fieldMelee)
        let count = space.permutationCount

        var contested: [Int] = []
        var hopeless: [Int] = []
        var easy: [Int] = []
        var scan = 0
        let scanStride = max(1, count / 400)
        while (contested.count < 2 || hopeless.count < 1 || easy.count < 2), scan < count {
            let perm = space.permutation(at: scan)
            let (level, catalog) = levelFor(perm: perm, fixed: fixed, base: base)
            let proto = GreedyCommander(level: level, catalog: catalog)
            var wins = 0
            for s in 0..<12 {
                guard let sim = try? Simulation(level: level, catalog: catalog,
                                                policy: proto, seed: 1776 &+ UInt64(s))
                else { continue }
                if sim.run(maxSeconds: 600).outcome == .victory { wins += 1 }
            }
            if wins == 0 { if hopeless.count < 1 { hopeless.append(scan) } }
            else if wins == 12 { if easy.count < 2 { easy.append(scan) } }
            else if contested.count < 2 { contested.append(scan) }
            scan += scanStride
        }
        let probes = (contested + hopeless + easy)

        print("\n── GPU vs CPU validation: \(levelName), \(seeds) seeds per side\(fieldMelee ? ", melee fielded" : "") ──")
        var failures = 0
        for pi in probes {
            let perm = space.permutation(at: pi)
            let (level, catalog) = levelFor(perm: perm, fixed: fixed, base: base)

            let proto = GreedyCommander(level: level, catalog: catalog)
            var cpuWins = 0
            var cpuLives = 0.0
            var cpuTension = 0.0
            var cpuLeaksByWave = Array(repeating: 0.0, count: fixed.numWaves)
            var cpuMilitia = (kills: 0.0, deaths: 0.0, respawns: 0.0)
            for s in 0..<seeds {
                guard let sim = try? Simulation(
                    level: level, catalog: catalog, policy: proto,
                    seed: 1776 &+ UInt64(s)
                ) else { continue }
                let r = sim.run(maxSeconds: 600)
                if r.outcome == .victory { cpuWins += 1 }
                cpuLives += Double(r.livesRemaining)
                cpuTension += r.waveMaxProgress.max() ?? 0
                for (w, leak) in r.leaksByWave.enumerated() where w < fixed.numWaves {
                    cpuLeaksByWave[w] += Double(leak)
                }
                cpuMilitia.kills += Double(sim.militiaKills)
                cpuMilitia.deaths += Double(sim.militiaDeaths)
                cpuMilitia.respawns += Double(sim.militiaRespawns)
            }

            let w1Cutoff = level.waves.count > 1 ? level.waves[1].startTime + 25 : 600
            var cpuW1Clear = 0
            for s in 0..<seeds {
                guard let sim = try? Simulation(
                    level: level, catalog: catalog,
                    policy: NaiveCommander(level: level, catalog: catalog, seed: 1776 &+ UInt64(s)),
                    seed: 1776 &+ UInt64(s)
                ) else { continue }
                if sim.run(maxSeconds: w1Cutoff).leaksByWave.first == 0 { cpuW1Clear += 1 }
            }

            let lvlGPU = try GPUBuild.levelGPU(level: level, catalog: catalog)
            let permGPU = try GPUBuild.permGPU(level: level, catalog: catalog, money: perm.money)
            let batch = try engine.run(level: lvlGPU, perms: [permGPU], seedsPerPerm: seeds,
                                       baseSeed: 1776, mode: UInt32(SIM_MODE_GREEDY))
            let naive = try engine.run(level: lvlGPU, perms: [permGPU], seedsPerPerm: seeds,
                                       baseSeed: 1776, mode: UInt32(SIM_MODE_NAIVE_W1))
            let gpuWins = batch.results.filter { $0.outcome == SIM_OUTCOME_VICTORY }.count
            let gpuLives = batch.results.reduce(0.0) { $0 + Double($1.livesRemaining) }
            let gpuTension = batch.results.reduce(0.0) { $0 + Double(maxProgress($1)) }
            let overflow = batch.results.filter { $0.spawnOverflow > 0 }.count
            let gpuW1Clear = naive.results.filter { leaksWave0($0) == 0 }.count

            let n = Double(seeds)
            let pC = Double(cpuWins) / n
            let pG = Double(gpuWins) / n
            let pPool = (Double(cpuWins) + Double(gpuWins)) / (2 * n)
            let se = (2 * pPool * (1 - pPool) / n).squareRoot()
            let winSigma = se > 0 ? abs(pC - pG) / se : 0
            let livesDelta = abs(cpuLives - gpuLives) / n
            let tensionDelta = abs(cpuTension - gpuTension) / n
            let w1C = Double(cpuW1Clear) / n
            let w1G = Double(gpuW1Clear) / n
            let w1Pool = (w1C + w1G) / 2
            let w1SE = (2 * w1Pool * (1 - w1Pool) / n).squareRoot()
            let w1Sigma = w1SE > 0 ? abs(w1C - w1G) / w1SE : 0
            var militiaOK = true
            var militiaNote = ""
            if fieldMelee {
                let gpuMilitia = batch.results.reduce(into: (0.0, 0.0, 0.0)) {
                    $0.0 += Double($1.militiaKills)
                    $0.1 += Double($1.militiaDeaths)
                    $0.2 += Double($1.militiaRespawns)
                }
                let pairs = [(cpuMilitia.kills, gpuMilitia.0),
                             (cpuMilitia.deaths, gpuMilitia.1),
                             (cpuMilitia.respawns, gpuMilitia.2)]
                militiaOK = pairs.allSatisfy { c, g in
                    abs(c - g) / n <= max(1.5, 0.25 * max(c, g) / n)
                }
                militiaNote = String(
                    format: "  militia k/d/r %.1f•%.1f•%.1f / %.1f•%.1f•%.1f",
                    cpuMilitia.kills / n, cpuMilitia.deaths / n, cpuMilitia.respawns / n,
                    gpuMilitia.0 / n, gpuMilitia.1 / n, gpuMilitia.2 / n)
            }

            var gpuLeaksByWave = Array(repeating: 0.0, count: fixed.numWaves)
            for r in batch.results {
                withUnsafeBytes(of: r.leaksByWave) { raw in
                    let arr = raw.bindMemory(to: UInt32.self)
                    for w in 0..<fixed.numWaves { gpuLeaksByWave[w] += Double(arr[w]) }
                }
            }
            let perWaveLeakDeltaMax = (0..<fixed.numWaves)
                .map { abs(cpuLeaksByWave[$0] - gpuLeaksByWave[$0]) / n }
                .max() ?? 0
            let projOverflow = batch.results.reduce(0) { $0 + Int($1.projOverflow) }

            let oneEnemyClass = livesDelta < 1.0 && perWaveLeakDeltaMax < 1.0
                && tensionDelta < 0.05 && w1Sigma < 4 && militiaOK
            let pass = (winSigma < 4 || oneEnemyClass) && livesDelta < 2.0
                && tensionDelta < 0.05 && w1Sigma < 4 && overflow == 0
                && projOverflow == 0 && militiaOK
            if !pass { failures += 1 }
            let verdict = !pass ? "FAIL"
                : (winSigma >= 4 ? "PASS (one-enemy fp32 class)" : "PASS")
            print(String(format: "  perm %6ld: win %.3f/%.3f (%.1fσ)  lives Δ%.2f  tension Δ%.3f  naiveW1 %.3f/%.3f (%.1fσ)%@  %@",
                         pi, pC, pG, winSigma, livesDelta, tensionDelta, w1C, w1G, w1Sigma,
                         militiaNote, verdict))
            if w1Sigma >= 4 {
                var pairs: [String] = []
                for s2 in 0..<min(24, seeds) {
                    guard let sim = try? Simulation(
                        level: level, catalog: catalog,
                        policy: NaiveCommander(level: level, catalog: catalog, seed: 1776 &+ UInt64(s2)),
                        seed: 1776 &+ UInt64(s2)
                    ) else { continue }
                    let cpuLeak = sim.run(maxSeconds: w1Cutoff).leaksByWave.first ?? 0
                    let gpuLeak = Int(leaksWave0(naive.results[s2]))
                    pairs.append("s\(s2):\(cpuLeak)/\(gpuLeak)")
                }
                print("    per-seed naive w1 leaks cpu/gpu: \(pairs.joined(separator: " "))")
                let nc = NaiveCommander(level: level, catalog: catalog, seed: 1776)
                print("    cpu naive slotOrder seed0: \(nc.slotOrder)")
            }
            if livesDelta >= 0.5 || winSigma >= 4 {
                let diffs = (0..<fixed.numWaves).map { w in
                    String(format: "w%d %.2f/%.2f", w + 1, cpuLeaksByWave[w] / n, gpuLeaksByWave[w] / n)
                }.joined(separator: "  ")
                print("    per-wave mean leaks cpu/gpu: \(diffs)")
            }
            if fieldMelee && !pass {
                var lines: [String] = []
                for s in 0..<min(12, seeds) {
                    guard let sim = try? Simulation(
                        level: level, catalog: catalog, policy: proto,
                        seed: 1776 &+ UInt64(s)
                    ) else { continue }
                    let r = sim.run(maxSeconds: 600)
                    let g = batch.results[s]
                    let gLeaks = withUnsafeBytes(of: g.leaksByWave) { raw -> [Int] in
                        let arr = raw.bindMemory(to: UInt32.self)
                        return (0..<fixed.numWaves).map { Int(arr[$0]) }
                    }
                    let gProg = progressArray(g, count: fixed.numWaves)
                    let firstDiff = (0..<fixed.numWaves).first {
                        r.leaksByWave[$0] != gLeaks[$0]
                            || abs(r.waveMaxProgress[$0] - gProg[$0]) > 0.02
                    }
                    lines.append(String(
                        format: "    s%d cpu %@ L%d k%d d%d r%d %.0fs | gpu %@ L%d k%d d%d r%d %.0fs | leaks %@/%@ diverge %@",
                        s, r.outcome == .victory ? "W" : "L", r.livesRemaining,
                        sim.militiaKills, sim.militiaDeaths, sim.militiaRespawns, r.seconds,
                        g.outcome == SIM_OUTCOME_VICTORY ? "W" : "L", g.livesRemaining,
                        g.militiaKills, g.militiaDeaths, g.militiaRespawns, g.seconds,
                        r.leaksByWave.map(String.init).joined(separator: "."),
                        gLeaks.map(String.init).joined(separator: "."),
                        firstDiff.map { "w\($0 + 1)" } ?? "-"))
                }
                print(lines.joined(separator: "\n"))
            }
        }
        return failures
    }

    static func meleeDuelProbe(db: Db, engine: GPUEngine, levelName: String,
                               seeds: Int) throws -> Int {
        let (fixed, space, base) = try makeInputs(db: db, levelName: levelName, fieldMelee: true)
        guard let meleeLevels = fixed.towerLevels["melee"],
              (meleeLevels.first?.meleeUnitCount ?? 0) > 0 else {
            print("  (no melee line in DB — duel probes skipped)")
            return 0
        }
        let midPerm = space.permutation(at: space.permutationCount / 2)
        let (level, _) = levelFor(perm: midPerm, fixed: fixed, base: base)
        let catalog = ContentCatalog(
            enemyTypes: fixed.roster,
            towerTypes: [TowerType(id: SweepCatalog.kindIDs["melee"]!, name: "melee",
                                   levels: Array(meleeLevels.prefix(2)))]
        )
        guard let walker = fixed.roster.first(where: { $0.name == "Loyalist Militia" })
            ?? fixed.roster.first else { return 0 }
        let regular = fixed.roster.first { $0.name == "Redcoat Regular" } ?? walker
        let c1 = meleeLevels[0].cost
        let c2 = meleeLevels.count > 1 ? meleeLevels[1].cost : 0
        let scenarios: [(name: String, money: Int, waves: [Wave])] = [
            ("6v1g", c1, [Wave(startTime: 5, spawns: [
                SpawnEntry(enemyTypeID: walker.id, count: 6, interval: 2)])]),
            ("6v2g", 2 * c1, [Wave(startTime: 5, spawns: [
                SpawnEntry(enemyTypeID: walker.id, count: 6, interval: 2)])]),
            ("12v1g", c1, [Wave(startTime: 5, spawns: [
                SpawnEntry(enemyTypeID: walker.id, count: 12, interval: 1.4)])]),
            ("mixed types", 2 * c1, [Wave(startTime: 5, spawns: [
                SpawnEntry(enemyTypeID: walker.id, count: 4, interval: 2),
                SpawnEntry(enemyTypeID: regular.id, count: 3, interval: 2.6, delay: 1),
            ])]),
            ("2 waves + gap", c1, [
                Wave(startTime: 5, spawns: [
                    SpawnEntry(enemyTypeID: walker.id, count: 3, interval: 2)]),
                Wave(startTime: 90, spawns: [
                    SpawnEntry(enemyTypeID: walker.id, count: 3, interval: 2)]),
            ]),
            ("4g + upgrades", 4 * c1 + c2 + 40, [Wave(startTime: 5, spawns: [
                SpawnEntry(enemyTypeID: walker.id, count: 8, interval: 1.4)])]),
        ]
        let rangedBase = Array((fixed.towerLevels["ranged"] ?? []).prefix(2))
        var rangedMeleeScenarios: [(name: String, money: Int, waves: [Wave],
                                    catalog: ContentCatalog)] = []
        if !rangedBase.isEmpty {
            let bigWave = [Wave(startTime: 5, spawns: [
                SpawnEntry(enemyTypeID: walker.id, count: 6, interval: 1.4),
                SpawnEntry(enemyTypeID: regular.id, count: 4, interval: 2.2, delay: 1),
            ])]
            let money = 2 * rangedBase[0].cost + c1 + 60
            let hitscan = rangedBase.map { l -> TowerLevel in
                var l = l
                l.projectileSpeed = 0
                return l
            }
            var projectile = rangedBase
            if projectile[0].projectileSpeed <= 0 {
                for i in projectile.indices { projectile[i].projectileSpeed = 425 }
            }
            for (name, levels) in [("r+m hitscan", hitscan), ("r+m projectile", projectile)] {
                rangedMeleeScenarios.append((
                    name, money, bigWave,
                    ContentCatalog(
                        enemyTypes: fixed.roster,
                        towerTypes: [
                            TowerType(id: SweepCatalog.kindIDs["ranged"]!, name: "ranged",
                                      levels: levels),
                            TowerType(id: SweepCatalog.kindIDs["melee"]!, name: "melee",
                                      levels: Array(meleeLevels.prefix(2))),
                        ])))
            }
        }
        let allScenarios = scenarios.map { ($0.name, $0.money, $0.waves, catalog) }
            + rangedMeleeScenarios.map { ($0.name, $0.money, $0.waves, $0.catalog) }
        var failures = 0
        for (scenario, money, waves, catalog) in allScenarios {
            let duelLevel = LevelInfo(
                id: level.id, name: level.name, campaign: level.campaign,
                startedAt: level.startedAt, endedAt: level.endedAt,
                startingMoney: money, numStartingLives: 50,
                playableRect: level.playableRect,
                paths: level.paths, towerSlots: level.towerSlots, waves: waves
            )
            let duelProto = GreedyCommander(level: duelLevel, catalog: catalog)
            let duelLvlGPU = try GPUBuild.levelGPU(level: duelLevel, catalog: catalog)
            let duelPermGPU = try GPUBuild.permGPU(level: duelLevel, catalog: catalog,
                                                   money: money)
            let duelBatch = try engine.run(level: duelLvlGPU, perms: [duelPermGPU],
                                           seedsPerPerm: seeds,
                                           baseSeed: 1776, mode: UInt32(SIM_MODE_GREEDY))
            var duelExact = 0
            var duelLines: [String] = []
            for s in 0..<seeds {
                guard let sim = try? Simulation(level: duelLevel, catalog: catalog,
                                                policy: duelProto, seed: 1776 &+ UInt64(s))
                else { continue }
                let r = sim.run(maxSeconds: 600)
                let g = duelBatch.results[s]
                let match = sim.militiaKills == Int(g.militiaKills)
                    && sim.militiaDeaths == Int(g.militiaDeaths)
                    && r.leaked == Int(g.leaked)
                    && abs(r.seconds - Double(g.seconds)) < 0.5
                if match { duelExact += 1 }
                else if duelLines.count < 6 {
                    duelLines.append(String(
                        format: "s%d cpu k%d d%d r%d leak%d %.1fs | gpu k%d d%d r%d leak%d %.1fs",
                        s, sim.militiaKills, sim.militiaDeaths, sim.militiaRespawns,
                        r.leaked, r.seconds,
                        g.militiaKills, g.militiaDeaths, g.militiaRespawns,
                        g.leaked, g.seconds))
                }
            }
            let pass = Double(duelExact) >= 0.99 * Double(seeds)
            if !pass { failures += 1 }
            print("  duel probe [\(scenario)]: \(duelExact)/\(seeds) seeds exact-match\(pass ? "" : "  FAIL")")
            for l in duelLines { print("    \(l)") }
        }
        return failures
    }

    private static func artilleryProbe(
        db: Db, engine: GPUEngine, levelName: String, seeds: Int
    ) throws -> Int {
        let (fixed, space, base) = try makeInputs(db: db, levelName: levelName)
        var failures = 0
        if let aoeLevels = fixed.towerLevels["areaOfEffect"], !aoeLevels.isEmpty {
            let midPerm = space.permutation(at: space.permutationCount / 2)
            let (level, _) = levelFor(perm: midPerm, fixed: fixed, base: base)
            let rangedLevels = Array((fixed.towerLevels["ranged"] ?? []).prefix(2))
            var towers: [TowerType] = [
                TowerType(id: SweepCatalog.kindIDs["areaOfEffect"]!, name: "areaOfEffect",
                          levels: Array(aoeLevels.prefix(3))),
            ]
            if !rangedLevels.isEmpty {
                towers.append(TowerType(id: SweepCatalog.kindIDs["ranged"]!, name: "ranged",
                                        levels: rangedLevels))
            }
            let catalog = ContentCatalog(enemyTypes: fixed.roster, towerTypes: towers)
            let proto = GreedyCommander(level: level, catalog: catalog)
            var cpuWins = 0
            var cpuLives = 0.0
            for s in 0..<seeds {
                guard let sim = try? Simulation(level: level, catalog: catalog,
                                                policy: proto, seed: 1776 &+ UInt64(s))
                else { continue }
                let r = sim.run(maxSeconds: 600)
                if r.outcome == .victory { cpuWins += 1 }
                cpuLives += Double(r.livesRemaining)
            }
            let lvlGPU = try GPUBuild.levelGPU(level: level, catalog: catalog)
            let permGPU = try GPUBuild.permGPU(level: level, catalog: catalog, money: midPerm.money)
            let batch = try engine.run(level: lvlGPU, perms: [permGPU], seedsPerPerm: seeds,
                                       baseSeed: 1776, mode: UInt32(SIM_MODE_GREEDY))
            let gpuWins = batch.results.filter { $0.outcome == SIM_OUTCOME_VICTORY }.count
            let gpuLives = batch.results.reduce(0.0) { $0 + Double($1.livesRemaining) }
            let n = Double(seeds)
            let pC = Double(cpuWins) / n
            let pG = Double(gpuWins) / n
            let pPool = (pC + pG) / 2
            let se = (2 * pPool * (1 - pPool) / n).squareRoot()
            let sigma = se > 0 ? abs(pC - pG) / se : 0
            let livesDelta = abs(cpuLives - gpuLives) / n
            let pass = sigma < 4 && livesDelta < 2.0
            if !pass { failures += 1 }
            print(String(format: "  artillery blast probe: win %.3f/%.3f (%.1fσ)  lives Δ%.2f  %@",
                         pC, pG, sigma, livesDelta, pass ? "PASS" : "FAIL"))
        }
        return failures
    }

    static func sweepRows(
        db: Db, fixed: SweepFixedInputs, base: LevelInfo, space: SweepSpace,
        indices: [Int], grids: SweepGrids, store: SweepResultStore? = nil,
        onProgress: ((Int, Double) -> Void)? = nil
    ) throws -> [SweepRow] {
        let engine = try GPUEngine()
        var rows: [SweepRow] = []
        rows.reserveCapacity(indices.count)
        let permBatchSize = 4096
        let probe = min(grids.probeSeeds, grids.seedsPerPermutation)
        let extra = grids.seedsPerPermutation - probe
        let t0 = Date()


        var batchStart = 0
        while batchStart < indices.count {
            try autoreleasepool {
            let batchIdx = Array(indices[batchStart..<min(batchStart + permBatchSize, indices.count)])
            let perms = batchIdx.map { space.permutation(at: $0) }
            guard let firstPerm = perms.first else {
                throw DbError.Db(message: "Empty permutation batch")
            }
            let (level0, catalog0) = levelFor(perm: firstPerm, fixed: fixed, base: base)
            let lvl = try GPUBuild.levelGPU(level: level0, catalog: catalog0)
            var permsGPU = [PermGPU](repeating: PermGPU(), count: perms.count)
            var buildError: Error?
            let errLock = NSLock()
            permsGPU.withUnsafeMutableBufferPointer { buf in
                DispatchQueue.concurrentPerform(iterations: perms.count) { k in
                    let (level, catalog) = levelFor(perm: perms[k], fixed: fixed, base: base)
                    do {
                        buf[k] = try GPUBuild.permGPU(level: level, catalog: catalog,
                                                      money: perms[k].money)
                    } catch {
                        errLock.lock(); buildError = error; errLock.unlock()
                    }
                }
            }
            if let buildError { throw buildError }

            let probeBatch = try engine.run(level: lvl, perms: permsGPU, seedsPerPerm: probe,
                                            baseSeed: grids.baseSeed, mode: UInt32(SIM_MODE_GREEDY))
            var contested: [Int] = []
            for (pi, _) in perms.enumerated() {
                let rs = probeBatch.results[(pi * probe)..<((pi + 1) * probe)]
                let allPerfect = rs.allSatisfy {
                    $0.outcome == SIM_OUTCOME_VICTORY && $0.leaked == 0
                        && $0.livesRemaining == Int32(perms[pi].lives)
                }
                let allLost = rs.allSatisfy { $0.outcome == SIM_OUTCOME_DEFEAT }
                if !(allPerfect || allLost) { contested.append(pi) }
            }
            func extraRound(_ mode: UInt32) throws -> [Int: [SimResultGPU]] {
                var byPerm: [Int: [SimResultGPU]] = [:]
                guard extra > 0, !contested.isEmpty else { return byPerm }
                let permChunk = max(1, 250_000 / extra)
                var start = 0
                while start < contested.count {
                    let chunk = Array(contested[start..<min(start + permChunk, contested.count)])
                    let full = try engine.run(level: lvl, perms: chunk.map { permsGPU[$0] },
                                              seedsPerPerm: extra,
                                              baseSeed: grids.baseSeed &+ UInt64(probe),
                                              mode: mode)
                    for (k, pi) in chunk.enumerated() {
                        byPerm[pi] = Array(full.results[(k * extra)..<((k + 1) * extra)])
                    }
                    start += permChunk
                }
                return byPerm
            }
            let extraByPerm = try extraRound(UInt32(SIM_MODE_GREEDY))
            let naiveProbe = try engine.run(level: lvl, perms: permsGPU, seedsPerPerm: probe,
                                            baseSeed: grids.baseSeed, mode: UInt32(SIM_MODE_NAIVE_W1))
            let naiveExtraByPerm = try extraRound(UInt32(SIM_MODE_NAIVE_W1))

            var batchRows: [SweepRow] = []
            batchRows.reserveCapacity(perms.count)
            for (pi, perm) in perms.enumerated() {
                var greedy = Array(probeBatch.results[(pi * probe)..<((pi + 1) * probe)])
                if let more = extraByPerm[pi] { greedy += more }
                var naive = Array(naiveProbe.results[(pi * probe)..<((pi + 1) * probe)])
                if let more = naiveExtraByPerm[pi] { naive += more }
                batchRows.append(makeRow(perm: perm, fixed: fixed, greedy: greedy, naive: naive))
            }
            rows += batchRows
            store?.insert(batchRows)

            batchStart += permBatchSize
            let rate = Double(rows.count) / max(0.001, Date().timeIntervalSince(t0))
            onProgress?(rows.count, rate)
            FileHandle.standardError.write(Data(
                String(format: "  gpu: %d/%d permutations (%.0f/s)\n",
                       rows.count, indices.count, rate).utf8))
            }
        }
        return rows
    }

    private static func makeRow(
        perm: SweepPermutation, fixed: SweepFixedInputs,
        greedy: [SimResultGPU], naive: [SimResultGPU]
    ) -> SweepRow {
        let n = Double(max(1, greedy.count))
        let wins = greedy.filter { $0.outcome == SIM_OUTCOME_VICTORY }.count
        let lives = greedy.map { Double($0.livesRemaining) }
        let removedK = greedy.reduce(0) { $0 + Int($1.killed) }
        let removedR = greedy.reduce(0) { $0 + Int($1.routed) }
        let removedC = greedy.reduce(0) { $0 + Int($1.captured) }
        let removed = removedK + removedR + removedC
        var tMean = 0.0, tPeak = 0.0, tFinal = 0.0
        for r in greedy {
            let waves = progressArray(r, count: fixed.numWaves)
            tMean += waves.isEmpty ? 0 : waves.reduce(0, +) / Double(waves.count)
            tPeak += waves.max() ?? 0
            tFinal += waves.last ?? 0
        }
        let greedyW1 = greedy.map { Int(leaksWave0($0)) }
        let naiveW1 = naive.map { Int(leaksWave0($0)) }
        return SweepRow(
            perm: perm,
            seedsUsed: greedy.count,
            winRate: Double(wins) / n,
            livesP10: Percentile.of(lives, 10),
            livesP50: Percentile.of(lives, 50),
            livesP90: Percentile.of(lives, 90),
            meanLeaked: greedy.reduce(0.0) { $0 + Double($1.leaked) } / n,
            routShare: removed == 0 ? 0 : Double(removedR + removedC) / Double(removed),
            tensionMean: tMean / n,
            tensionPeak: tPeak / n,
            tensionFinal: tFinal / n,
            meanSeconds: greedy.reduce(0.0) { $0 + Double($1.seconds) } / n,
            w1GreedyClear: Double(greedyW1.filter { $0 == 0 }.count) / Double(max(1, greedyW1.count)),
            w1GreedyLeaks: Double(greedyW1.reduce(0, +)) / Double(max(1, greedyW1.count)),
            w1NaiveClear: Double(naiveW1.filter { $0 == 0 }.count) / Double(max(1, naiveW1.count)),
            w1NaiveLeaks: Double(naiveW1.reduce(0, +)) / Double(max(1, naiveW1.count))
        )
    }

    private static func progressArray(_ r: SimResultGPU, count: Int) -> [Double] {
        withUnsafeBytes(of: r.waveMaxProgress) { raw in
            let arr = raw.bindMemory(to: Float.self)
            return (0..<min(count, Int(SIM_MAX_WAVES))).map { Double(arr[$0]) }
        }
    }

    private static func leaksWave0(_ r: SimResultGPU) -> UInt32 {
        withUnsafeBytes(of: r.leaksByWave) { $0.bindMemory(to: UInt32.self)[0] }
    }

    private static func maxProgress(_ r: SimResultGPU) -> Float {
        var m: Float = 0
        withUnsafeBytes(of: r.waveMaxProgress) { raw in
            let arr = raw.bindMemory(to: Float.self)
            for i in 0..<Int(SIM_MAX_WAVES) { m = max(m, arr[i]) }
        }
        return m
    }
}
