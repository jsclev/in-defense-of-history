import Foundation

struct Options {
    var dbPath = "revwar.sqlite"
    var inMemory = false
    var levelID = UUID(uuidString: "")
    var seeds = 200
    var baseSeed: UInt64 = 1776
    var reset = false
    var blueprint: String?
    var idle = false
    var trace = false
    var sweep: String?
    var sweepOut = "sweeps/sweep.sqlite"
    var sweepStride = 1
    var sweepSeeds = 40
    var limit: Int?
    var showRuns = false
    var runStatusID: UUID?
    var fixes: [(stat: String, kind: String, value: Double)] = []
    var dimPins: [(dim: String, value: String)] = []
    var focus: (stat: String, kind: String)?
    var focusGrid: [Double]?
    var reportDir = ("~/projects/in-defense-of-history-data/SimulatorRuns" as NSString).expandingTildeInPath
    var budgetHours = 8.0
    var gpu = false
    var fineGrids = false
    var storeBounds = false
    var melee = false
    var meleeDemo: String?
    var bench: String?
    var benchSims = 1000
    var benchGPU: String?
    var gpuValidate: String?
    var validateSeeds = 2000
}

func printUsage() {
    print("""
    revsim \(BuildVersion.version) — headless balance simulator

    USAGE: revsim [options]
      --db <path>      Content database path (default: revwar.sqlite)
      --memory         Use an in-memory database (seeds fresh every run)
      --level <id>     Level id to simulate (default: concord_road)
      --seeds <n>      Number of seeds to run (default: 200)
      --seed <n>       Base seed; runs use base, base+1, ... (default: 1776)
      --reset          Delete the database file first
      --blueprint <name>  Batch-run a design blueprint (no DB, no art)
      --idle           With --blueprint: run the no-towers baseline instead
      --sweep <name>   Permutation sweep of a level. Fixed inputs (tower
                       unlocks, base stats + L1 costs, lives, wave count,
                       enemy roster) are read from the DB; starting money,
                       upgrade costs, and wave compositions are swept.
      --sweep-out <p>  SQLite output path (default: sweeps/sweep.sqlite)
      --sweep-stride <n>  Sample every nth permutation (default 1 = all)
      --sweep-seeds <n>   Seeds per permutation (default 40)
      --limit <n>      Run at most n permutations, then stop and write the
                       output as usual — the SQL LIMIT of sweeps. Applied
                       after --sweep-stride. Use it to smoke-test a command
                       before committing to the full run:
                         --limit 8 --sweep-seeds 4
                       Under --focus, n rounds down to whole focus-value
                       groups so every focus value keeps the same paired
                       sample (a partial group would skew the curves).
      --fix <stat>:<kind>=<v>  Pin a swept tower stat as a designer-fixed input
                       for this run; repeatable. Stats: range, rof, growth,
                       splash (blast radius), falloff (blast falloff exponent),
                       projspeed (projectile flight speed; 0 = hitscan).
                       e.g. --fix rof:ranged=0.8 --fix splash:areaOfEffect=100
      --fix <dim>=<v>  Pin a non-tower dimension: money, lives, curve, mix, spacing,
                       enemyspeed, enemyhp, or enemybounty (a bracket
                       position 0..1 across the sim bracket tables:
                       0 = bracket min, 0.5 = designed value, 1 = max).
                       e.g. --fix money=250 --fix mix=balanced
      --focus <stat>:<kind>  Single-variable focus study. The sweep becomes a
                       paired design: every value of the focus variable runs
                       against the identical sample of permutations of every
                       other variable, then the run emits <sweep-out>.focus.csv
                       (per-value aggregates) and <sweep-out>.focus.html
                       (charts: mean win rate with a 95% band, margin of
                       victory, and the same curve split by the hardest,
                       middle and easiest third of the other variables).
                       Tower stats take stat:kind (e.g. --focus range:ranged);
                       scalar dimensions stand alone: --focus money, lives,
                       curve, mix, spacing, enemyspeed, enemyhp, enemybounty,
                       meleehp, meleedamage. --sweep-stride samples the
                       other-variable space; the focus grid is never strided.
      --focus-grid <lo:hi:step>  Dense grid for the focus variable this run
                       (numeric stats only), e.g. --focus-grid 120:300:10.
      --report-dir <path>  Where focus reports land, named
                       focus_<variable>_<yyyy-MM-dd_HH.mm.ss>.{html,csv}
                       (default: ~/projects/in-defense-of-history-data/SimulatorRuns)
      --budget-hours <h>  Nightly budget; the run projects its length after a
                       calibration batch and warns if it will blow this (default 8)
      --melee          Field the melee line in sweep catalogs and enable the
                       meleehp/meleedamage bracket dimensions (sim_melee_unit).
                       Runs on both engines; melee kinds collapse the range/rof
                       dimensions (the flag range and cadence are DB inputs).
      --store-bounds   After the sweep, derive choice-irrelevance bounds (min:
                       below it the player always loses; max: above it sloppy
                       play always wins) and store them in sim_stat_bounds.
                       Later sweeps read stored bounds as their permutation
                       window automatically (pin overrides; static grid if none).
      --help           Show this help

    Blueprints: \(Blueprints.all.map { $0.name }.joined(separator: ", "))
    """)
}

func parseOptions() throws -> Options? {
    var opts = Options()
    var args = ArraySlice(CommandLine.arguments.dropFirst())
    while let arg = args.popFirst() {
        switch arg {
        case "--db":
            guard let v = args.popFirst() else { return nil }
            opts.dbPath = v
        case "--memory":
            opts.inMemory = true
        case "--level":
            guard let v = args.popFirst() else { return nil }
            guard let uuid = UUID(uuidString: v) else {
                throw DbError.Db(message: "Unable to create UUID")
            }
            
            opts.levelID = uuid
        case "--seeds":
            guard let v = args.popFirst(), let n = Int(v), n > 0 else { return nil }
            opts.seeds = n
        case "--seed":
            guard let v = args.popFirst(), let n = UInt64(v) else { return nil }
            opts.baseSeed = n
        case "--reset":
            opts.reset = true
        case "--blueprint":
            guard let v = args.popFirst() else { return nil }
            opts.blueprint = v
        case "--idle":
            opts.idle = true
        case "--trace":
            opts.trace = true
        case "--sweep":
            guard let v = args.popFirst() else { return nil }
            opts.sweep = v
        case "--sweep-out":
            guard let v = args.popFirst() else { return nil }
            opts.sweepOut = v
        case "--sweep-stride":
            guard let v = args.popFirst(), let n = Int(v), n > 0 else { return nil }
            opts.sweepStride = n
        case "--sweep-seeds":
            guard let v = args.popFirst(), let n = Int(v), n > 0 else { return nil }
            opts.sweepSeeds = n
        case "--runs":
            opts.showRuns = true
        case "--run-status":
            guard let v = args.popFirst(), let id = UUID(uuidString: v) else { return nil }
            opts.runStatusID = id
        case "--limit":
            guard let v = args.popFirst(), let n = Int(v), n > 0 else { return nil }
            opts.limit = n
        case "--melee-demo":
            guard let v = args.popFirst() else { return nil }
            opts.meleeDemo = v
        case "--bench":
            guard let v = args.popFirst() else { return nil }
            opts.bench = v
        case "--bench-sims":
            guard let v = args.popFirst(), let n = Int(v), n > 0 else { return nil }
            opts.benchSims = n
        case "--bench-gpu":
            guard let v = args.popFirst() else { return nil }
            opts.benchGPU = v
        case "--gpu-validate":
            guard let v = args.popFirst() else { return nil }
            opts.gpuValidate = v
        case "--validate-seeds":
            guard let v = args.popFirst(), let n = Int(v), n > 0 else { return nil }
            opts.validateSeeds = n
        case "--fix":
            guard let v = args.popFirst() else { return nil }
            if v.contains(":") {
                let statAndRest = v.split(separator: ":", maxSplits: 1)
                let kindAndValue = statAndRest[1].split(separator: "=", maxSplits: 1)
                guard kindAndValue.count == 2, let value = Double(kindAndValue[1]),
                      ["range", "rof", "growth", "splash", "falloff", "projspeed"].contains(String(statAndRest[0]))
                else { return nil }
                opts.fixes.append((String(statAndRest[0]), String(kindAndValue[0]), value))
            } else {
                let dimAndValue = v.split(separator: "=", maxSplits: 1)
                guard dimAndValue.count == 2,
                      ["money", "lives", "curve", "mix", "spacing", "enemyspeed", "enemyhp", "enemybounty", "meleehp", "meleedamage"].contains(String(dimAndValue[0]))
                else { return nil }
                opts.dimPins.append((String(dimAndValue[0]), String(dimAndValue[1])))
            }
        case "--focus":
            guard let v = args.popFirst() else { return nil }
            if v.contains(":") {
                let parts = v.split(separator: ":", maxSplits: 1)
                guard parts.count == 2,
                      ["range", "rof", "growth", "splash", "falloff", "projspeed"].contains(String(parts[0]))
                else { return nil }
                opts.focus = (String(parts[0]), String(parts[1]))
            } else {
                guard ["money", "lives", "curve", "mix", "spacing", "enemyspeed", "enemyhp", "enemybounty", "meleehp", "meleedamage"].contains(v)
                else { return nil }
                opts.focus = (v, "")
            }
        case "--focus-grid":
            guard let v = args.popFirst() else { return nil }
            let parts = v.split(separator: ":").compactMap { Double($0) }
            guard parts.count == 3, parts[2] > 0, parts[1] >= parts[0] else { return nil }
            var values: [Double] = []
            var x = parts[0]
            while x <= parts[1] + parts[2] * 0.001 {
                values.append((x * 1000).rounded() / 1000)
                x += parts[2]
            }
            opts.focusGrid = values
        case "--report-dir":
            guard let v = args.popFirst() else { return nil }
            opts.reportDir = (v as NSString).expandingTildeInPath
        case "--budget-hours":
            guard let v = args.popFirst(), let h = Double(v), h > 0 else { return nil }
            opts.budgetHours = h
        case "--gpu":
            opts.gpu = true
        case "--fine-grids":
            opts.fineGrids = true
        case "--store-bounds":
            opts.storeBounds = true
        case "--melee":
            opts.melee = true
        case "--help", "-h":
            printUsage()
            exit(0)
        default:
            FileHandle.standardError.write(Data("Unknown option: \(arg)\n".utf8))
            return nil
        }
    }
    return opts
}

guard let opts = try parseOptions() else {
    printUsage()
    exit(2)
}

if opts.showRuns || opts.runStatusID != nil {
    do {
        let runs = try SimulatorRunDAO()
        let list = try opts.runStatusID.map { id in try runs.get(id: id).map { [$0] } ?? [] }
            ?? runs.recent(limit: 15)
        if list.isEmpty {
            print("no simulator runs recorded")
        } else {
            let df = DateFormatter()
            df.dateFormat = "MM-dd HH:mm:ss"
            print("run id                                status      progress"
                + "                       rate      started         level / focus")
            for r in list {
                let bar = { () -> String in
                    let w = 16
                    let filled = max(0, min(w, Int((r.percentComplete / 100 * Double(w)).rounded())))
                    return String(repeating: "#", count: filled)
                        + String(repeating: ".", count: w - filled)
                }()
                let eta = r.estimatedSecondsRemaining.map {
                    $0 >= 3600 ? String(format: " eta %.1fh", $0 / 3600)
                               : String(format: " eta %.0fm", $0 / 60)
                } ?? ""
                print(String(format: "%@  %-10@  %@ %5.1f%%  %8.0f/s  %@  %@%@",
                             r.id.uuidString, r.status as NSString, bar, r.percentComplete,
                             r.iterationsPerSecond, df.string(from: r.startedAt),
                             "\(r.levelName)\(r.focus.isEmpty ? "" : " / " + r.focus)", eta))
                print(String(format: "  %@ of %@ permutations%@",
                             r.completedIterations.formatted(), r.totalIterations.formatted(),
                             r.reportPath.map { "  report: " + $0 } ?? ""))
            }
        }
    } catch {
        print("Unable to read simulator runs: \(error)")
        exit(1)
    }
    exit(0)
}

if let levelName = opts.meleeDemo {
    do {
        let db = Db(dbPath: Db.getAbsolutePathToDb(dbFilename: "in_defense_of_history", fullRefresh: false),
                    fullRefresh: false)
        let fixed = try SweepFixedInputs.load(db: db, levelName: levelName)
        var base = try SweepFixedInputs.designLevel(db: db, levelName: levelName, fixed: fixed)
        let space = SweepSpace(grids: SweepGrids(), fixed: fixed, slotCount: base.towerSlots.count)
        let perm = space.permutation(at: space.permutationCount / 2)
        base.waves = SweepWaves.make(perm: perm, fixed: fixed, pathCount: base.paths.count)

        let rangedID = UUID(uuidString: "5e0e91a1-0001-4000-8000-000000000001")!
        let meleeID = UUID(uuidString: "5e0e91a1-0004-4000-8000-000000000004")!
        var towers: [TowerType] = []
        if let r = fixed.towerLevels["ranged"] {
            towers.append(TowerType(id: rangedID, name: "ranged", levels: Array(r.prefix(2))))
        }
        if let m = fixed.towerLevels["melee"] {
            towers.append(TowerType(id: meleeID, name: "melee", levels: Array(m.prefix(2))))
        }
        let catalog = ContentCatalog(enemyTypes: fixed.roster, towerTypes: towers)
        let order = GreedyCommander(level: base, catalog: catalog).slotOrder

        func run(withMelee: Bool, seed: UInt64) -> (SimulationResult, Simulation) {
            var steps: [ScriptedBuildOrder.Step] = [
                .init(time: 1, action: .build(slot: order[0], towerID: rangedID)),
                .init(time: 2, action: .build(slot: order[2], towerID: rangedID)),
            ]
            if withMelee {
                steps.append(.init(time: 3, action: .build(slot: order[1], towerID: meleeID)))
                steps.append(.init(time: 4, action: .build(slot: order[3], towerID: meleeID)))
            } else {
                steps.append(.init(time: 3, action: .build(slot: order[1], towerID: rangedID)))
                steps.append(.init(time: 4, action: .build(slot: order[3], towerID: rangedID)))
            }
            let sim = try! Simulation(level: base, catalog: catalog,
                                      policy: ScriptedBuildOrder(steps: steps), seed: seed)
            return (sim.run(maxSeconds: 600), sim)
        }

        print("\n── melee demo: \(levelName) (2 ranged + 2 melee vs 4 ranged, 20 seeds) ──")
        var mLeaks = 0, rLeaks = 0, mWins = 0, rWins = 0
        var kills = 0, deaths = 0, respawns = 0
        for s in 0..<20 {
            let (mr, ms) = run(withMelee: true, seed: 1776 &+ UInt64(s))
            let (rr, _) = run(withMelee: false, seed: 1776 &+ UInt64(s))
            mLeaks += mr.leaked; rLeaks += rr.leaked
            mWins += mr.outcome == .victory ? 1 : 0
            rWins += rr.outcome == .victory ? 1 : 0
            kills += ms.militiaKills; deaths += ms.militiaDeaths; respawns += ms.militiaRespawns
        }
        print("""
        with melee:    \(mWins)/20 wins, \(mLeaks) total leaks
        without melee: \(rWins)/20 wins, \(rLeaks) total leaks
        militia over 20 runs: \(kills) kills, \(deaths) deaths, \(respawns) respawns
        """)

        let (_, sim) = run(withMelee: true, seed: 1776)
        for (slot, g) in sim.garrisons.sorted(by: { $0.key < $1.key }) {
            let states = g.units.map { "\($0.state)" }.joined(separator: ", ")
            print("garrison @slot \(slot): rally (\(Int(g.rallyPoint.x)), \(Int(g.rallyPoint.y)))  end states: \(states)")
        }
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("melee-demo error: \(error)\n".utf8))
        exit(1)
    }
}

if let level = opts.benchGPU {
    do {
        let db = Db(dbPath: Db.getAbsolutePathToDb(dbFilename: "in_defense_of_history", fullRefresh: false),
                    fullRefresh: false)
        try GPUHarness.bench(db: db, levelName: level, sims: opts.benchSims)
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("bench-gpu error: \(error)\n".utf8))
        exit(1)
    }
}

if let level = opts.gpuValidate {
    do {
        let db = Db(dbPath: Db.getAbsolutePathToDb(dbFilename: "in_defense_of_history", fullRefresh: false),
                    fullRefresh: false)
        try GPUHarness.validate(db: db, levelName: level, seeds: opts.validateSeeds)
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("gpu-validate error: \(error)\n".utf8))
        exit(1)
    }
}

if let benchLevel = opts.bench {
    do {
        let db = Db(dbPath: Db.getAbsolutePathToDb(dbFilename: "in_defense_of_history", fullRefresh: false),
                    fullRefresh: false)
        try Sweep.bench(db: db, levelName: benchLevel, sims: opts.benchSims)
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("bench error: \(error)\n".utf8))
        exit(1)
    }
}

if let sweepLevel = opts.sweep {
    do {
        let db = Db(dbPath: Db.getAbsolutePathToDb(dbFilename: "in_defense_of_history", fullRefresh: false),
                    fullRefresh: false)
        var grids = SweepGrids()
        grids.seedsPerPermutation = opts.sweepSeeds
        grids.baseSeed = opts.baseSeed
        if opts.fineGrids {
            grids.upgradeGrowth = Array(stride(from: 1.2, through: 2.2, by: 0.1)).map { ($0 * 10).rounded() / 10 }
            // Range is deliberately absent: it always walks every integer in
            // sim_tower_range, so there is no coarse version of it to refine.
            grids.rofGrids = [
                "ranged": Array(stride(from: 0.5, through: 1.2, by: 0.05)).map { ($0 * 100).rounded() / 100 },
                "special": Array(stride(from: 0.8, through: 1.8, by: 0.1)).map { ($0 * 10).rounded() / 10 },
                "areaOfEffect": Array(stride(from: 1.6, through: 3.2, by: 0.1)).map { ($0 * 10).rounded() / 10 },
            ]
            grids.splashGrids = ["areaOfEffect": Array(stride(from: 70.0, through: 130, by: 5))]
            grids.falloffGrid = [0.5, 0.75, 1.0, 1.5, 2.0, 3.0]
            grids.boundsStep = 10
            grids.enemySpeedGrid = Array(stride(from: 0.0, through: 1.0, by: 0.125))
            grids.enemyHpGrid = Array(stride(from: 0.0, through: 1.0, by: 0.125))
            grids.enemyBountyGrid = Array(stride(from: 0.0, through: 1.0, by: 0.125))
            grids.livesGrid = [1, 5, 10, 15, 20, 25, 30, 40, 50]
        }
        for fix in opts.fixes {
            switch fix.stat {
            case "range": grids.fixedRange[fix.kind] = fix.value
            case "rof": grids.fixedRof[fix.kind] = fix.value
            case "growth": grids.fixedGrowth[fix.kind] = fix.value
            case "splash": grids.fixedSplash[fix.kind] = fix.value
            case "falloff": grids.fixedFalloff[fix.kind] = fix.value
            case "projspeed": grids.fixedProjSpeed[fix.kind] = fix.value
            default: break
            }
        }
        for pin in opts.dimPins {
            switch pin.dim {
            case "money": grids.fixedMoney = Int(pin.value)
            case "lives": grids.fixedLives = Int(pin.value)
            case "curve": grids.fixedCurve = pin.value
            case "mix": grids.fixedMix = pin.value
            case "spacing": grids.fixedSpacing = pin.value
            case "enemyspeed": grids.fixedEnemySpeed = Double(pin.value)
            case "enemyhp": grids.fixedEnemyHp = Double(pin.value)
            case "enemybounty": grids.fixedEnemyBounty = Double(pin.value)
            case "meleehp": grids.fixedMeleeHp = Double(pin.value)
            case "meleedamage": grids.fixedMeleeDamage = Double(pin.value)
            default: break
            }
        }
        if let focus = opts.focus {
            let pinnedStat = opts.fixes.contains { $0.stat == focus.stat && $0.kind == focus.kind }
            let pinnedDim = opts.dimPins.contains { $0.dim == focus.stat }
            if pinnedStat || pinnedDim {
                FileHandle.standardError.write(Data("cannot --focus and --fix the same variable\n".utf8))
                exit(2)
            }
            grids.focus = SweepFocus(stat: focus.stat, kind: focus.kind)
            if let values = opts.focusGrid {
                switch focus.stat {
                case "range": grids.rangeGridOverride[focus.kind] = values
                case "rof": grids.rofGrids[focus.kind] = values
                case "growth": grids.upgradeGrowth = values
                case "splash": grids.splashGrids[focus.kind] = values
                case "falloff": grids.falloffGrid = values
                case "projspeed": grids.projSpeedGrids[focus.kind] = values
                case "money": grids.moneyGridOverride = values.map { Int($0) }
                case "lives": grids.livesGrid = values.map { Int($0) }
                case "enemyspeed": grids.enemySpeedGrid = values
                case "enemyhp": grids.enemyHpGrid = values
                case "enemybounty": grids.enemyBountyGrid = values
                case "meleehp": grids.meleeHpGrid = values
                case "meleedamage": grids.meleeDamageGrid = values
                default:
                    FileHandle.standardError.write(Data("--focus-grid does not apply to \(focus.stat)\n".utf8))
                    exit(2)
                }
            }
        } else if opts.focusGrid != nil {
            FileHandle.standardError.write(Data("--focus-grid requires --focus\n".utf8))
            exit(2)
        }
        grids.reportDir = opts.reportDir
        grids.limit = opts.limit
        grids.budgetHours = opts.budgetHours
        try Sweep.run(db: db, levelName: sweepLevel, grids: grids,
                      stride: opts.sweepStride, outPath: opts.sweepOut,
                      useGPU: opts.gpu, storeBounds: opts.storeBounds,
                      fieldMelee: opts.melee)
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("sweep error: \(error)\n".utf8))
        exit(1)
    }
}

if let bpName = opts.blueprint {
    guard let bp = Blueprints.named(bpName) else {
        FileHandle.standardError.write(Data("Unknown blueprint '\(bpName)'. Known: \(Blueprints.all.map { $0.name }.joined(separator: ", "))\n".utf8))
        exit(2)
    }
    let level = bp.makeLevel()
    let catalog = DesignArsenal.catalog()

    if opts.trace {
        final class Tracer: SimulationObserver {
            let catalog: ContentCatalog
            init(catalog: ContentCatalog) { self.catalog = catalog }
            func handle(_ event: SimEvent, atTime time: Double) {
                let t = String(format: "%7.1fs", time)
                switch event {
                case let .waveStarted(i): print("\(t)  ── wave \(i + 1)")
                case let .towerBuilt(slot, id):
                    let name = catalog.towerTypes[catalog.towerIndex(id: id)!].name
                    print("\(t)  build \(name) @ slot \(slot)")
                case let .towerUpgraded(slot, lvl): print("\(t)  upgrade slot \(slot) -> L\(lvl + 1)")
                case let .enemyRemoved(_, id, fate):
                    guard fate != .killed else { return }
                    let name = catalog.enemyTypes[catalog.enemyIndex(id: id)!].name
                    print("\(t)  \(name) \(fate.rawValue)")
                default: break
                }
            }
        }
        let sim = try Simulation(
            level: level, catalog: catalog,
            policy: opts.idle ? IdleCommander() : bp.scriptedSolution(),
            seed: opts.baseSeed
        )
        sim.addObserver(Tracer(catalog: catalog))
        let r = sim.run()
        print("outcome: \(r.outcome)  lives \(r.livesRemaining)/\(bp.lives)  " +
              "shot \(r.killed) routed \(r.routed) captured \(r.captured) leaked \(r.leaked)")
        exit(0)
    }

    let report = try Batch.run(
        level: level,
        catalog: catalog,
        baseSeed: opts.baseSeed,
        count: opts.seeds
    ) { _ -> any CommanderPolicy in
        if opts.idle { return IdleCommander() }
        return bp.scriptedSolution()
    }

    func pct(_ v: Double) -> String { String(format: "%5.1f%%", v * 100) }
    func bar(_ v: Double, width: Int = 30) -> String {
        let n = max(0, min(width, Int((v * Double(width)).rounded())))
        return String(repeating: "█", count: n) + String(repeating: "·", count: width - n)
    }

    let waveStarts = level.waves.map { String(format: "%.0f", $0.startTime) }.joined(separator: " ")
    let meanSeconds = report.results.map(\.seconds).reduce(0, +) / Double(max(1, report.runs))
    print("""

    ── design lab: \(bp.name) ─────────────────────────────
    policy:      \(opts.idle ? "idle (no towers)" : "intended solution (\(bp.intendedSolution.count) steps)")
    runs:        \(report.runs) seeds from \(opts.baseSeed)
    win rate:    \(pct(report.winRate))  (\(report.victories)W / \(report.defeats)L / \(report.timeouts)T)
    lives p10/p50/p90:  \(String(format: "%.0f / %.0f / %.0f", report.livesPercentile(10), report.livesPercentile(50), report.livesPercentile(90)))  of \(bp.lives)
    mean length: \(String(format: "%.0f", meanSeconds))s   waves start at: \(waveStarts)
    fates:       \(report.totalKilled) shot, \(report.totalRouted) routed, \(report.totalCaptured) captured, \(report.totalLeaked) leaked
    rout share:  \(pct(report.routShare)) of removals came from morale

    tension (mean max progress per wave; ramps = good, flat = dull):
    """)
    for (i, v) in report.meanWaveMaxProgress.enumerated() {
        print(String(format: "      w%02d  %@ %4.0f%%", i + 1, bar(v), v * 100))
    }
    print("    ──────────────────────────────────────────────────────\n")
    exit(0)
}

do {
    if opts.reset && !opts.inMemory {
        try? FileManager.default.removeItem(atPath: opts.dbPath)
    }

    let db = Db(dbPath: Db.getAbsolutePathToDb(dbFilename: "in_defense_of_history", fullRefresh: false), fullRefresh: false)
    
    guard let levelInfoId = UUID(uuidString: "be3cf809-f71e-4209-bc4d-8b25b0b5f2a0") else {
        throw DbError.Db(message: "Unable to get level info id")
    }
    
    let levelInfo = try db.levelInfoDao.getBy(id: levelInfoId)

    let minutemanPost = TowerType(
        id: UUID(),
        name: "Minuteman Post",
        levels: [
            TowerLevel(cost: 70, range: 140, fireInterval: 0.9, shotMinDamage: 4, shotMaxDamage: 7),
            TowerLevel(cost: 90, range: 150, fireInterval: 0.85, shotMinDamage: 7, shotMaxDamage: 11),
        ]
    )
    let enemyTypes = try db.enemyTypeDao.getAll()
    let catalog = ContentCatalog(enemyTypes: enemyTypes, towerTypes: [minutemanPost])

    let sim = try Simulation(
        level: levelInfo,
        catalog: catalog,
        policy: IdleCommander(),
        seed: opts.baseSeed
    )

    guard !levelInfo.towerSlots.isEmpty else {
        throw DbError.Db(message: "Level '\(levelInfo.name)' has no tower slots to place a tower in.")
    }
    let goldBefore = sim.gold
    let buildResult = sim.build(slot: 0, towerID: minutemanPost.id)
    guard buildResult == .ok else {
        throw DbError.Db(message: "Failed to place \(minutemanPost.name) in slot 0: \(buildResult)")
    }

    let occupiedSlots = sim.towers.filter { $0 != nil }.count

    print("""

    ── revsim ────────────────────────────────────────────
    level:        \(levelInfo.name) [\(levelInfo.id)]
    playable:     \(levelInfo.playableRect)
    enemies:      \(enemyTypes.count) types loaded from roster
    tower slots:  \(levelInfo.towerSlots.count)
    tower built:  \(minutemanPost.name) → slot 0 (\(occupiedSlots)/\(levelInfo.towerSlots.count) occupied)
    gold:         \(goldBefore) → \(sim.gold)  (lives: \(sim.lives))
    initialized:  wave 1  (waves loaded: \(levelInfo.waves.count), paths loaded: \(levelInfo.paths.count))
    ──────────────────────────────────────────────────────

    """)

    guard let path = levelInfo.paths.first else {
        throw DbError.Db(message: "Level '\(levelInfo.name)' has no path to walk. Seed level_path_point first.")
    }
    let walker = enemyTypes.first(where: { $0.name == "Redcoat Regular" }) ?? enemyTypes[0]
    let speed = walker.stats.speed
    let timer = Timer(tickDuration: .zero)
    let ticksPerSecond = Int64(SimClock.ticksPerSecond)

    func fmt(_ v: Double, _ d: Int = 1) -> String { String(format: "%.\(d)f", v) }
    func sample(distance: Double) {
        let p = path.point(atDistance: distance)
        let pct = path.totalLength > 0 ? distance / path.totalLength * 100 : 0
        let t = Double(timer.tick) * SimClock.dt
        print("  t=\(fmt(t))s  tick \(String(format: "%4d", timer.tick))  "
            + "dist \(String(format: "%7.1f", distance)) (\(String(format: "%3.0f", pct))%)  "
            + "pos (\(fmt(p.x)), \(fmt(p.y)))")
    }

    print("""
    ── enemy walk (engine Timer, unbounded) ──────────────
    enemy:   \(walker.name)  (speed \(fmt(speed, 0)) units/s)
    path:    \(path.points.count) points, length \(fmt(path.totalLength)) units
    clock:   \(SimClock.ticksPerSecond) ticks/s of game time (dt \(fmt(SimClock.dt, 4))s), pacing unbounded

    """)

    var distance = 0.0
    sample(distance: distance)
    var nextSampleTick = ticksPerSecond
    while distance < path.totalLength {
        let tick = timer.waitForNextTick()
        distance = min(path.totalLength, Double(tick) * SimClock.dt * speed)
        if tick >= nextSampleTick {
            sample(distance: distance)
            nextSampleTick += ticksPerSecond
        }
    }
    if timer.tick % ticksPerSecond != 0 { sample(distance: distance) }

    print("""

    arrived at exit in \(fmt(Double(timer.tick) * SimClock.dt))s (\(timer.tick) ticks)
    ──────────────────────────────────────────────────────

    """)
} catch {
    FileHandle.standardError.write(Data("revsim error: \(error)\n".utf8))
    exit(1)
}
