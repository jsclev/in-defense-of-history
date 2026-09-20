import Foundation

struct Options {
    var baseSeed: UInt64 = 1776
    var showRuns = false
    var runStatusID: UUID?
    var reportDir = ("~/projects/td/in-defense-of-history-data/SimulatorRuns" as NSString).expandingTildeInPath
    var benchSims = 64
    var help = false
    var moneyStudy: String?
    var moneyRange = (minimum: 100, maximum: 800, step: 5)
    var placementPlans = 100
    var upgradePolicies = 10
    var moneySeeds = 20
    var maxGameSeconds = 1800.0
    var workers = 1
    var calibrateMoney = false
    var replayMoneyPlan: (placement: Int, policy: Int, money: Int)?
}

func printUsage() {
    print("""
    revsim \(BuildVersion.version) — shared game engine

    --money-study <name>   Run the authored level using the iPhone battle rules.
                          Current database difficulty, campaign upgrades, tower
                          prices, abilities, waves and map remain pinned.
                          Heroes are excluded for the requested tower-only study.
    --money-range <min:max:step>  Starting money only (default 100:800:5).
    --placement-plans <n>  Number of sampled placement plans (default 100).
    --upgrade-policies <n>  Ten upgrade schedules (currently exactly 10).
    --money-seeds <n>      Seeds per plan and budget (default 20).
    --seed <n>             Combat/base seed (default 1776).
    --calibrate-money      Bounded sample with JSON output and no study records.
    --bench-sims <n>       Calibration sample size.
    --max-game-seconds <n> Experiment cutoff (default 1800); unfinished runs are timeouts.
    --replay-money-plan <placement:policy:money>  Trace one plan in the game engine.
    --report-dir <path>    JSON report destination outside the source checkout.
    --runs                Read saved run records. Old independent-engine runs
                          are not evidence of current game balance.
    --run-status <id>      Read one saved run.
    --help                Show this help.

    The shared engine currently executes serially. Legacy CPU/GPU combat implementations have been removed.
    """)
}

func parseOptions() throws -> Options? {
    var opts = Options()
    var args = ArraySlice(CommandLine.arguments.dropFirst())
    while let arg = args.popFirst() {
        switch arg {
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
        default:
            FileHandle.standardError.write(Data("Unknown option: \(arg)\n".utf8))
            return nil
        }
    }
    return opts
}

let store: SimulatorStore
do {
    store = try SimulatorStore()
} catch {
    FileHandle.standardError.write(Data("revsim: unable to open the content database: \(error)\n".utf8))
    exit(1)
}

guard let opts = try parseOptions() else {
    printUsage()
    exit(2)
}
if opts.help {
    printUsage()
    exit(0)
}

if opts.moneyStudy == nil && !opts.showRuns && opts.runStatusID == nil {
    FileHandle.standardError.write(Data("Specify --money-study, --runs or --run-status. Only the shared battle engine is available.\n".utf8))
    exit(2)
}

if let name = opts.moneyStudy {
    do {
        if let replay = opts.replayMoneyPlan {
            try MainActor.assumeIsolated { try AuthoredMoneySweep(db: store.db).replay(levelName: name, placement: replay.placement,
                policy: replay.policy, money: replay.money, seed: opts.baseSeed, maxSeconds: opts.maxGameSeconds, directory: opts.reportDir) }
            exit(0)
        }
        let grid = try MoneyStudyGrid(minimum: opts.moneyRange.minimum, maximum: opts.moneyRange.maximum,
            step: opts.moneyRange.step, placementPlans: opts.placementPlans,
            upgradePolicies: opts.upgradePolicies, combatSeeds: opts.moneySeeds)
        try MainActor.assumeIsolated { try AuthoredMoneySweep(db: store.db).run(levelName: name, grid: grid, baseSeed: opts.baseSeed,
            workers: opts.workers, maxSeconds: opts.maxGameSeconds, calibrationRuns: opts.calibrateMoney ? opts.benchSims : nil,
            directory: opts.reportDir) }
        exit(0)
    } catch {
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
    } catch {
        print("Unable to read simulator runs: \(error)")
        exit(1)
    }
    exit(0)
}
