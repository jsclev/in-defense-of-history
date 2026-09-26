import Foundation
import OSLog

struct Options {
    var levelNumber: Int?
    var baseSeed: UInt64 = 1776
    var showRuns = false
    var runStatusID: UUID?
    var reportDir: String?
    var database: String?
    var contentDatabase: String?
    var seedStrategyPaths: [String] = []
    var metaExchangePath: String?
    var benchSims = 64
    var help = false
    var advancedHelp = false
    var moneyStudy: String?
    var moneyRange = (minimum: 590, maximum: 770, step: 5)
    var placementPlans = 100
    var upgradePolicies = 10
    var moneySeeds = 20
    var maxGameSeconds = 1800.0
    var workers = 1
    var calibrateMoney = false
    var replayMoneyPlan: (placement: Int, policy: Int, money: Int)?
    var geneticStudy: String?
    var genetic = GeneticStudyOptions()
    var geneticReplay: String?
    var balanceStudy: String?
    var balanceScenarios: [BalanceScenario] = []
    var balanceHours = 0.25
    var suppliedStartingMoney = false
}

func printUsage() {
    print("""
    LibertyLineSimulator \(BuildVersion.version)

    Usage: LibertyLineSimulator <level-number>
    Example: ~/bin/LibertyLineSimulator 15

    Starts a genetic search for that level using its database settings.
    Runs for up to 8 hours and saves results in a new SQLite database
    beside the executable. Keep this Terminal open and your Mac awake.

    --help-advanced shows optional experiment and database controls.
    """)
}

func printAdvancedUsage() {
    print("""
    LibertyLineSimulator \(BuildVersion.version) — shared game engine

    Each study creates a unique SQLite database beside this executable.
    It captures game content/maps and saves all results there; it never exports the game's SQL seed.
    --database <path>      New study database (must not exist), or existing database for --runs/--run-status.
    --content-database <path> Override the installed starter or use a previous run as input.
                          Default beside this executable: liberty-line-simulator-\(BuildVersion.version).sqlite
    --version             Print the build name used in the default database filename.

    --balance-study <name> Separate balance audit: no heroes, maximum ranged meta, authored money.
    --balance-scenarios <path> JSON array of damage/enemy-mix variants; baseline always runs first.
    --balance-hours <n>    Total allocated runtime across baseline, variants and controls (default 0.25).
                          Uses population/generations/seeds/finalists/max-evaluations below.
                          Single worker; records bounded evidence, never proves impossibility.

    --genetic-study <name> Evolve towers, reinforcements and early wave calls with the chosen heroes.
    --heroes <id[,id]>     Fix one or two authored hero UUIDs for this GA run (default: database selection).
    --hero-ai <on|off>     Set chosen heroes' AI for this experiment only (default: database settings).
    --starting-money <n>   Override the level's authored starting money for this experiment.
    --bounty-fraction <n>  Genetic experiment fraction of authored kill bounty, 0–1 (default 1).
    --fixed-meta          Keep the exact database-selected upgrades; requires its exact star group.
    --no-early-wave-calls  Control experiment: exclude early calls from candidate generation/mutation.
    --seed-strategy <path> Seed the GA with explicit strategy JSON (repeatable).
    --star-range <min:max:step> Exact stars used; default the database-earned star total only.
    --population <n>       Population cap per stars-used group (default 64), divided equally among meta selections.
    --meta-selections <n>  Active meta-selection subpopulations per group (default 8).
    --meta-min-candidates <n> Minimum distinct battle plans before a selection qualifies (default 4).
    --meta-adaptation-generations <n> Protect a new selection for this many generations (default 2).
    --meta-exchange-from <path> Compare a candidate's meta selection with nearby legal selections at the same stars used; adapt all battle plans equally.
    --generations <n>      Maximum generations including the initial one (default 300).
    --training-seeds <n>   Complete games per candidate (default 3).
    --validation-seeds <n> Unseen seeds per frozen finalist (default 64).
    --finalists <n>        Maximum distinct meta-selection finalists per group (default 8).
    --max-evaluations <n>  Total engine-game ceiling including validation (default 50000).
    --genetic-hours <n>    Wall-time budget; reserves 15% for validation (default 8).
    --workers <n>          Parallel shared-engine battle processes for GA (1–32, default automatic, up to 4).
    --genetic-replay <path> Verify a saved best-strategy.json against the same content/engine.

    --money-study <name>   Run the authored level using the iPhone battle rules.
                          Current database difficulty, campaign upgrades, tower
                          prices, abilities, waves and map remain pinned.
                          Reinforcements are used; heroes are excluded.
    --money-range <min:max:step>  Starting money only (default 590:770:5).
    --placement-plans <n>  Number of sampled placement plans (default 100).
    --upgrade-policies <n>  Ten upgrade schedules (currently exactly 10).
    --money-seeds <n>      Seeds per plan and budget (default 20).
    --seed <n>             Combat/base seed (default 1776).
    --calibrate-money      Bounded sample with JSON output and no study records.
    --bench-sims <n>       Calibration sample size.
    --max-game-seconds <n> Experiment cutoff (default 1800); unfinished runs are timeouts.
    --replay-money-plan <placement:policy:money>  Trace one plan in the game engine.
    --report-dir <path>    Optional JSON exports; all reports are also stored in the run database.
    --runs                Read saved run records. Old independent-engine runs
                          are not evidence of current game balance.
    --run-status <id>      Read one saved run.
    --help                Show simple usage.
    --help-advanced       Show this reference.

    Each worker executes complete shared-engine ticks. Legacy alternate CPU/GPU combat implementations remain removed.
    """)
}

func parseOptions() throws -> Options? {
    var opts = Options()
    var suppliedWorkers = false
    var args = ArraySlice(CommandLine.arguments.dropFirst())
    while let arg = args.popFirst() {
        switch arg {
        case "--database":
            guard let value = args.popFirst() else { return nil }
            opts.database = value
        case "--content-database":
            guard let value = args.popFirst() else { return nil }
            opts.contentDatabase = value
        case "--balance-study":
            guard let value = args.popFirst() else { return nil }
            opts.balanceStudy = value
        case "--balance-scenarios":
            guard let path = args.popFirst() else { return nil }
            opts.balanceScenarios = try JSONDecoder().decode([BalanceScenario].self,
                from: Data(contentsOf: URL(fileURLWithPath: path)))
        case "--balance-hours":
            guard let value = args.popFirst(), let hours = Double(value), hours.isFinite, hours > 0 else { return nil }
            opts.balanceHours = hours
        case "--genetic-study":
            guard let value = args.popFirst() else { return nil }
            opts.geneticStudy = value
        case "--genetic-replay":
            guard let value = args.popFirst() else { return nil }
            opts.geneticReplay = value
        case "--heroes":
            guard let value = args.popFirst() else { return nil }
            let fields = value.split(separator: ",", omittingEmptySubsequences: false)
            let ids = fields.compactMap { UUID(uuidString: String($0)) }
            guard (1...HeroSelection.maxSelected).contains(fields.count), ids.count == fields.count,
                  Set(ids).count == ids.count else { return nil }
            opts.genetic.selectedHeroIDs = ids
        case "--hero-ai":
            guard let value = args.popFirst(), ["on", "off"].contains(value) else { return nil }
            opts.genetic.heroAIEnabled = value == "on"
        case "--bounty-fraction":
            guard let value = args.popFirst(), let fraction = Double(value), fraction.isFinite, (0...1).contains(fraction) else { return nil }
            opts.genetic.bountyFraction = fraction
        case "--fixed-meta": opts.genetic.fixedMeta = true
        case "--no-early-wave-calls": opts.genetic.earlyWaveCalls = false
        case "--seed-strategy":
            guard let path = args.popFirst() else { return nil }
            opts.seedStrategyPaths.append(path)
        case "--meta-exchange-from":
            guard let path = args.popFirst() else { return nil }
            opts.metaExchangePath = path
        case "--star-range":
            guard let value = args.popFirst() else { return nil }
            let fields = value.split(separator: ":", omittingEmptySubsequences: false)
            guard fields.count == 3, let minimum = Int(fields[0]), let maximum = Int(fields[1]),
                  let step = Int(fields[2]), minimum >= 0, maximum >= minimum, step > 0 else { return nil }
            opts.genetic.starMinimum = minimum; opts.genetic.starMaximum = maximum; opts.genetic.starStep = step
        case "--starting-money", "--population", "--generations", "--training-seeds", "--validation-seeds", "--finalists", "--max-evaluations", "--meta-selections", "--meta-min-candidates", "--meta-adaptation-generations":
            guard let value = args.popFirst(), let number = Int(value), number > 0 else { return nil }
            switch arg {
            case "--starting-money": opts.genetic.money = number; opts.suppliedStartingMoney = true
            case "--population": opts.genetic.population = number
            case "--generations": opts.genetic.generations = number
            case "--training-seeds": opts.genetic.trainingSeeds = number
            case "--validation-seeds": opts.genetic.validationSeeds = number
            case "--finalists": opts.genetic.finalists = number
            case "--meta-selections": opts.genetic.metaSelections = number
            case "--meta-min-candidates": opts.genetic.minimumMetaCandidates = number
            case "--meta-adaptation-generations": opts.genetic.metaAdaptationGenerations = number
            default: opts.genetic.maxEvaluations = number
            }
        case "--genetic-hours":
            guard let value = args.popFirst(), let number = Double(value), number.isFinite, number > 0 else { return nil }
            opts.genetic.hours = number
        case "--money-study":
            guard let v = args.popFirst() else { return nil }
            opts.moneyStudy = v
        case "--money-range":
            guard let v = args.popFirst() else { return nil }
            let pieces = v.split(separator: ":").compactMap { Int($0) }
            guard pieces.count == 3 else { return nil }
            opts.moneyRange = (pieces[0], pieces[1], pieces[2])
        case "--placement-plans":
            guard let v = args.popFirst(), let n = Int(v), n > 0 else { return nil }
            opts.placementPlans = n
        case "--upgrade-policies":
            guard let v = args.popFirst(), let n = Int(v), n == 10 else { return nil }
            opts.upgradePolicies = n
        case "--money-seeds":
            guard let v = args.popFirst(), let n = Int(v), n > 0 else { return nil }
            opts.moneySeeds = n
        case "--max-game-seconds":
            guard let value = args.popFirst(), let seconds = Double(value), seconds.isFinite, seconds > 0 else { return nil }
            opts.maxGameSeconds = seconds
        case "--workers":
            guard let v = args.popFirst(), let n = Int(v), n > 0 else { return nil }
            opts.workers = n
            suppliedWorkers = true
        case "--calibrate-money": opts.calibrateMoney = true
        case "--replay-money-plan":
            guard let v = args.popFirst() else { return nil }
            let parts = v.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 3, parts[0] >= 0, (0..<10).contains(parts[1]), parts[2] > 0 else { return nil }
            opts.replayMoneyPlan = (parts[0], parts[1], parts[2])
        case "--seed":
            guard let v = args.popFirst(), let n = UInt64(v) else { return nil }
            opts.baseSeed = n
        case "--runs": opts.showRuns = true
        case "--run-status":
            guard let value = args.popFirst(), let id = UUID(uuidString: value) else { return nil }
            opts.runStatusID = id
        case "--report-dir":
            guard let value = args.popFirst() else { return nil }
            opts.reportDir = value
        case "--bench-sims":
            guard let value = args.popFirst(), let count = Int(value), count > 0 else { return nil }
            opts.benchSims = count
        case "--help", "-h":
            opts.help = true
        case "--help-advanced":
            opts.advancedHelp = true
        default:
            guard opts.levelNumber == nil, !arg.isEmpty,
                  arg.utf8.allSatisfy({ (48...57).contains($0) }),
                  let number = Int(arg), number > 0 else {
                FileHandle.standardError.write(Data("Expected one positive level number; unexpected argument: \(arg)\n".utf8))
                return nil
            }
            opts.levelNumber = number
        }
    }
    if !suppliedWorkers, opts.levelNumber != nil || opts.geneticStudy != nil {
        opts.workers = min(4, max(1, ProcessInfo.processInfo.activeProcessorCount - 1))
    }
    return opts
}

// Private worker entry point: transport only; all evaluation stays in the
// shared commander/engine and all persistence stays behind DAOs.
if CommandLine.arguments.count == 2, CommandLine.arguments[1] == "--version" {
    print(BuildVersion.version)
    exit(0)
}
if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--prepare-starter-database" {
    do {
        try SimulatorStore.prepareStarter(source: URL(fileURLWithPath: CommandLine.arguments[2]),
                                          destination: URL(fileURLWithPath: CommandLine.arguments[3]))
        exit(0)
    } catch {
        SimulatorLog.database.error("Starter database preparation failed: \(String(describing: error), privacy: .private)")
        FileHandle.standardError.write(Data("Starter database error: \(error)\n".utf8))
        exit(1)
    }
}
if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--genetic-worker" {
    do {
        try MainActor.assumeIsolated { try GeneticBattleWorker.run(configuration: CommandLine.arguments[2]) }
        exit(0)
    } catch {
        SimulatorLog.worker.error("Worker process failed: \(String(describing: error), privacy: .private)")
        FileHandle.standardError.write(Data("genetic worker error: \(error)\n".utf8))
        exit(1)
    }
}

var opts: Options
do {
    guard let parsed = try parseOptions() else {
        SimulatorLog.cli.error("Invalid command-line arguments; expected a positive level number or valid optional controls")
        printUsage()
        exit(2)
    }
    opts = parsed
} catch {
    SimulatorLog.cli.error("Unable to read command-line options: \(String(describing: error), privacy: .private)")
    FileHandle.standardError.write(Data("LibertyLineSimulator: \(error)\n".utf8))
    exit(2)
}
if opts.advancedHelp {
    printAdvancedUsage()
    exit(0)
}
if opts.help || CommandLine.arguments.count == 1 {
    printUsage()
    exit(0)
}
SimulatorLog.cli.notice("CLI started; build=\(BuildVersion.version, privacy: .public) pid=\(ProcessInfo.processInfo.processIdentifier)")

let store: SimulatorStore
let reports: SimulatorReports
var numberedLevelID: UUID?
do {
    let modes = [opts.geneticStudy, opts.balanceStudy, opts.moneyStudy].compactMap { $0 }.count
        + (opts.levelNumber == nil ? 0 : 1)
    let inspecting = opts.showRuns || opts.runStatusID != nil
    guard modes == (inspecting ? 0 : 1) else {
        throw DbError.Db(message: "Pass one level number, for example: LibertyLineSimulator 15. Do not combine study modes.")
    }
    if inspecting {
        guard let path = opts.database else {
            throw DbError.Db(message: "Use --database <run.sqlite> with --runs or --run-status")
        }
        store = try SimulatorStore(existing: URL(fileURLWithPath: path), readOnly: true)
    } else {
        let content = try opts.contentDatabase.map { URL(fileURLWithPath: $0) }
            ?? SimulatorDatabase.starter(beside: SimulatorStore.executableURL, buildName: BuildVersion.version)
        // Resolve against the installed input before creating any result file.
        // Carry its UUID into the GA so duplicate display names cannot redirect it.
        let numberedLevel = try opts.levelNumber.map { number in
            let input = try SimulatorStore(existing: content, readOnly: true)
            defer { input.db.close() }
            return try input.db.levelInfoDao.getBy(number: number)
        }
        store = try SimulatorStore(destination: opts.database.map { URL(fileURLWithPath: $0) },
                                   content: content)
        if let level = numberedLevel, let number = opts.levelNumber {
            numberedLevelID = level.id
            opts.geneticStudy = level.name
            SimulatorLog.cli.notice("Selected level; number=\(number) levelID=\(level.id.uuidString, privacy: .public) name=\(level.name, privacy: .public)")
            print("Starting GA for level \(number): \(level.name)")
        }
        print("Content database: \(content.path)")
        print("Simulator database: \(store.db.path)")
        let decoder = MetaUpgradesFactory.decoder(catalog: try store.db.metaUpgradeDao.get())
        opts.genetic.seedStrategies = try opts.seedStrategyPaths.map {
            try decoder.decode(GeneticStrategy.self, from: Data(contentsOf: URL(fileURLWithPath: $0)))
        }
        if let path = opts.metaExchangePath {
            opts.genetic.metaExchangeFrom = try decoder.decode(GeneticStrategy.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        }
    }
    reports = try SimulatorReports(db: store.db, directory: inspecting ? nil : opts.reportDir)
} catch {
    SimulatorLog.cli.error("Simulator setup failed; requestedLevel=\(opts.levelNumber ?? 0) detail=\(String(describing: error), privacy: .private)")
    FileHandle.standardError.write(Data("LibertyLineSimulator: \(error)\n".utf8))
    exit(1)
}

if let name = opts.balanceStudy {
    do {
        guard opts.moneyStudy == nil, opts.geneticStudy == nil, opts.geneticReplay == nil,
              !opts.suppliedStartingMoney else {
            throw DbError.Db(message: "Balance analysis is a separate mode and uses authored starting money; remove other study modes and --starting-money")
        }
        var configuration = opts.genetic
        configuration.seed = opts.baseSeed; configuration.maxGameSeconds = opts.maxGameSeconds
        configuration.workers = opts.workers
        // The balance tool has no starting-money dimension. Record the DAO
        // value even in the generic options metadata.
        guard let id = try store.db.levelInfoDao.getIdBy(levelName: name) else {
            throw DbError.Db(message: "Unknown balance-study level '\(name)'")
        }
        configuration.money = try AuthoredMoneyStudy(db: store.db, levelID: id).level.startingMoney
        try MainActor.assumeIsolated {
            try BalanceStudy(db: store.db, reports: reports).run(levelName: name, scenarios: opts.balanceScenarios,
                options: configuration, hours: opts.balanceHours)
        }
        SimulatorLog.cli.notice("Balance study command completed")
        exit(0)
    } catch {
        SimulatorLog.study.error("Balance study failed; level=\(name, privacy: .public) detail=\(String(describing: error), privacy: .private)")
        FileHandle.standardError.write(Data("balance-study error: \(error)\n".utf8)); exit(1)
    }
}

if opts.moneyStudy == nil && opts.geneticStudy == nil && !opts.showRuns && opts.runStatusID == nil {
    SimulatorLog.cli.error("No study or inspection command selected")
    FileHandle.standardError.write(Data("Pass a level number, for example: LibertyLineSimulator 15\n".utf8))
    exit(2)
}

if let name = opts.geneticStudy {
    do {
        guard opts.moneyStudy == nil else { throw DbError.Db(message: "Select one experiment mode") }
        var configuration = opts.genetic
        configuration.seed = opts.baseSeed; configuration.maxGameSeconds = opts.maxGameSeconds
        configuration.workers = opts.workers
        try MainActor.assumeIsolated {
            let study = GeneticStudy(db: store.db, reports: reports)
            if let replay = opts.geneticReplay { try study.replay(levelName: name, document: replay) }
            else if let id = numberedLevelID { try study.run(levelID: id, options: configuration) }
            else { try study.run(levelName: name, options: configuration) }
        }
        SimulatorLog.cli.notice("Genetic study command completed")
        exit(0)
    } catch {
        SimulatorLog.ga.error("Genetic study command failed; level=\(name, privacy: .public) detail=\(String(describing: error), privacy: .private)")
        FileHandle.standardError.write(Data("genetic-study error: \(error)\n".utf8))
        exit(1)
    }
}

if let name = opts.moneyStudy {
    do {
        if let replay = opts.replayMoneyPlan {
            try MainActor.assumeIsolated { try AuthoredMoneySweep(db: store.db, reports: reports).replay(levelName: name, placement: replay.placement,
                policy: replay.policy, money: replay.money, seed: opts.baseSeed, maxSeconds: opts.maxGameSeconds) }
            SimulatorLog.cli.notice("Money study replay completed")
            exit(0)
        }
        let grid = try MoneyStudyGrid(minimum: opts.moneyRange.minimum, maximum: opts.moneyRange.maximum,
            step: opts.moneyRange.step, placementPlans: opts.placementPlans,
            upgradePolicies: opts.upgradePolicies, combatSeeds: opts.moneySeeds)
        try MainActor.assumeIsolated { try AuthoredMoneySweep(db: store.db, reports: reports).run(levelName: name, grid: grid, baseSeed: opts.baseSeed,
            workers: opts.workers, maxSeconds: opts.maxGameSeconds, calibrationRuns: opts.calibrateMoney ? opts.benchSims : nil) }
        SimulatorLog.cli.notice("Money study command completed")
        exit(0)
    } catch {
        SimulatorLog.study.error("Money study failed; level=\(name, privacy: .public) detail=\(String(describing: error), privacy: .private)")
        FileHandle.standardError.write(Data("money-study error: \(error)\n".utf8))
        exit(1)
    }
}

if opts.showRuns || opts.runStatusID != nil {
    do {
        let runs = store.db.simulatorRunDao
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
                if let message = r.errorMessage, !message.isEmpty { print("  \(message)") }
            }
        }
        SimulatorLog.cli.info("Run inspection completed; records=\(list.count)")
    } catch {
        SimulatorLog.cli.error("Run inspection failed: \(String(describing: error), privacy: .private)")
        print("Unable to read simulator runs: \(error)")
        exit(1)
    }
    exit(0)
}
