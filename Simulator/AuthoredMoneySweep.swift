import Foundation
import CryptoKit

/// Every supported balance run executes the iPhone's shared battle engine.
@MainActor
final class AuthoredMoneySweep {
    let db: Db
    init(db: Db) { self.db = db }

    private func load(_ name: String) throws -> AuthoredMoneyStudy {
        guard let id = try db.levelInfoDao.getIdBy(levelName: name) else {
            throw DbError.Db(message: "Unknown authored level '\(name)'")
        }
        return try AuthoredMoneyStudy(db: db, levelID: id)
    }

    private func snapshot(_ study: AuthoredMoneyStudy) throws -> Data {
        let encoder = JSONEncoder()
        func json<T: Encodable>(_ value: T) throws -> Any {
            try JSONSerialization.jsonObject(with: encoder.encode(value))
        }
        let loadout = study.battle.playerUpgrades.loadout
        let upgrades: [[String: Any]] = loadout.catalog.upgrades.map { definition in
            ["id": definition.id.rawValue, "selected": loadout.selected.contains(definition.id),
             "parameters": Dictionary(uniqueKeysWithValues: definition.parameters.map { ($0.key.rawValue, $0.value) })]
        }
        let content: [String: Any] = [
            "engine": "shared-game-engine", "level": try json(study.level),
            "unlocks": Dictionary(uniqueKeysWithValues: study.battle.unlocks.map { ($0.key.rawValue, $0.value) }),
            "canvas": try json(study.battle.virtualCanvas),
            "towers": try json(study.catalog.towerTypes),
            "enemies": try json(study.battle.enemies), "combatRules": try json(study.arsenal.combatRules),
            "difficulty": study.difficulty.name, "enemyHPMultiplier": study.difficulty.enemyHPMultiplier,
            "campaignUpgrades": upgrades, "heroes": false,
            "reinforcementConfig": ["cooldownSeconds": study.battle.reinforcementConfig.cooldownSeconds,
                "timeToLiveSeconds": study.battle.reinforcementConfig.timeToLiveSeconds]]
        return try JSONSerialization.data(withJSONObject: content, options: [.sortedKeys])
    }

    private func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private func write(_ value: Any, at url: URL) throws {
        try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic)
    }

    func replay(levelName: String, placement: Int, policy: Int, money: Int,
                seed: UInt64, maxSeconds: Double, directory: String) throws {
        let study = try load(levelName)
        let plan = try MoneyStudyPlan(study: study, placementIndex: placement, upgradePolicyIndex: policy, seed: 1776)
        let sim = try GameSimulation(content: study.battle, startingMoney: money, heroesEnabled: false, seed: seed)
        let trace = MoneyReplayTrace()
        sim.addObserver(trace)
        let result = try sim.run(steps: plan.steps, maxSeconds: maxSeconds)
        let output = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let content = try snapshot(study)
        try content.write(to: output.appendingPathComponent("content.json"), options: .atomic)
        let report: [String: Any] = ["engine": "shared-game-engine", "placement": placement,
            "policy": policy, "money": money, "seed": seed, "planSeed": 1776,
            "contentSHA256": hash(content), "campaignMetaUpgrades": true,
            "result": try JSONSerialization.jsonObject(with: JSONEncoder().encode(result)),
            "events": trace.events, "finalState": state(sim),
            "shotsBySlot": Dictionary(uniqueKeysWithValues: sim.shotsBySlot.map { (String($0.key), $0.value) }),
            "demolitionDetonations": sim.demolitionDetonations, "earnedMetaStars": sim.earnedMetaStars]
        let path = output.appendingPathComponent("replay-\(placement)-\(policy)-\(money)-\(seed).json")
        try write(report, at: path)
        print("Shared game replay: \(result.outcome), \(result.seconds)s, \(result.killed) killed, \(result.leaked) leaked. \(path.path)")
    }

    private func state(_ sim: GameSimulation) -> [String: Any] {
        ["time": sim.time, "gold": sim.gold, "lives": sim.lives,
         "towers": sim.towers.map { tower -> [String: Any] in
             ["slot": tower.slot, "kind": tower.kind.rawValue, "tier": tower.level,
              "branch": tower.branch, "damage": tower.damage]
         }]
    }

    func run(levelName: String, grid: MoneyStudyGrid, baseSeed: UInt64,
             workers: Int, maxSeconds: Double, calibrationRuns: Int?, directory: String) throws {
        guard grid.upgradePolicies == 10, workers > 0, maxSeconds.isFinite, maxSeconds > 0 else {
            throw DbError.Db(message: "money study requires ten upgrade schedules and a positive worker count")
        }
        let study = try load(levelName)
        let plans = try (0..<grid.placementPlans).flatMap { placement in
            try (0..<grid.upgradePolicies).map { policy in
                try MoneyStudyPlan(study: study, placementIndex: placement, upgradePolicyIndex: policy, seed: baseSeed)
            }
        }
        let content = try snapshot(study)
        let digest = hash(content)
        let planJSON: [[String: Any]] = plans.map { plan in
            ["placement": plan.placementIndex, "upgradePolicy": plan.upgradePolicyIndex,
             "steps": plan.steps.map { step -> [String: Any] in
                 var record: [String: Any] = ["time": step.time]
                 switch step.action {
                 case let .build(slot, id): record.merge(["action": "build", "slot": slot, "towerID": id.uuidString]) { _, new in new }
                 case let .upgrade(slot): record.merge(["action": "upgrade", "slot": slot]) { _, new in new }
                 case let .purchaseUpgrade(slot, pathID): record.merge(["action": "purchaseUpgrade", "slot": slot, "pathID": pathID]) { _, new in new }
                 }
                 return record
             }]
        }
        let configuration: [String: Any] = ["level": study.level.name, "levelID": study.level.id.uuidString,
            "mode": "shared-game-engine", "heroes": false, "campaignMetaUpgrades": true,
            "selectedCampaignUpgrades": study.battle.playerUpgrades.loadout.selected.map(\.rawValue).sorted(),
            "reinforcementCommands": false, "earlyWaveCalls": false,
            "moneyValues": grid.money, "placementPlans": grid.placementPlans,
            "upgradePolicies": grid.upgradePolicies, "combatSeeds": grid.combatSeeds,
            "baseSeed": baseSeed, "totalRuns": grid.runCount, "workers": 1, "requestedWorkers": workers,
            "maxSimulationSeconds": maxSeconds, "contentSHA256": digest,
            "buildVersion": BuildVersion.version, "difficulty": study.difficulty.name,
            "enemyHPMultiplier": study.difficulty.enemyHPMultiplier,
            "authoredStartingMoney": study.level.startingMoney,
            "paths": study.level.paths.count, "slots": study.level.towerSlots.count,
            "waves": study.level.waves.count, "towerVariants": Set(study.towerPaths.flatMap(\.tierIDs)).count,
            "note": "Shared game rules. Sampled command schedules; no claim of optimal play."]
        let output = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try write(configuration, at: output.appendingPathComponent("configuration.json"))
        try content.write(to: output.appendingPathComponent("content.json"), options: .atomic)
        try write(planJSON, at: output.appendingPathComponent("plans.json"))
        let groups = grid.money.count * plans.count
        let calibration = calibrationRuns != nil
        let requested = min(calibrationRuns ?? grid.runCount, grid.runCount)
        guard requested > 0 else { throw DbError.Db(message: "money study: calibration count must be positive") }
        let jobs = calibration ? (requested + grid.combatSeeds - 1) / grid.combatSeeds : groups
        let dao = try MoneyStudyDAO(db: db)
        var runID: UUID?
        if !calibration {
            let started = try db.simulatorRunDao.begin(levelName: study.level.name,
                focus: "shared game engine; tower-only; authored campaign upgrades", totalIterations: grid.runCount, outputPath: db.path)
            runID = started
            do {
                try dao.begin(runID: started,
                    configuration: String(decoding: JSONSerialization.data(withJSONObject: configuration, options: [.sortedKeys]), as: UTF8.self),
                    contentSHA256: digest,
                    plans: String(decoding: JSONSerialization.data(withJSONObject: planJSON, options: [.sortedKeys]), as: UTF8.self))
                try Data(started.uuidString.utf8).write(to: output.appendingPathComponent("run-id.txt"), options: .atomic)
            } catch {
                db.simulatorRunDao.finish(id: started, status: .failed, errorMessage: String(describing: error)); throw error
            }
        }
        print("\(calibration ? "Calibration" : "Started shared-game study"): \(study.level.name), \(requested.formatted()) simulations; one serial game-engine worker")
        print("\(study.difficulty.name) ×\(study.difficulty.enemyHPMultiplier) HP; \(study.battle.playerUpgrades.loadout.selected.count) selected campaign upgrades; heroes excluded")
        fflush(stdout)
        var completed = 0, victories = 0, defeats = 0, timeouts = 0, detonations = 0
        var simulatedSeconds = 0.0
        var attacks: [String: Int] = [:]
        var pending: [MoneyStudyResultRow] = []
        let startedAt = Date()
        var lastLog = startedAt
        do {
            for job in 0..<jobs {
                let index = calibration ? job * groups / jobs : job
                let money = grid.money[index / plans.count]
                let plan = plans[index % plans.count]
                let seeds = calibration ? min(grid.combatSeeds, requested - job * grid.combatSeeds) : grid.combatSeeds
                var samples: [SimulationResult] = []
                for seedIndex in 0..<seeds {
                    let sim = try GameSimulation(content: study.battle, startingMoney: money, heroesEnabled: false,
                        seed: baseSeed &+ UInt64(seedIndex))
                    samples.append(try sim.run(steps: plan.steps, maxSeconds: maxSeconds))
                    for (mode, count) in sim.shotsByMode { attacks[mode.rawValue, default: 0] += count }
                    detonations += sim.demolitionDetonations
                }
                let report = BatchReport(results: samples)
                completed += seeds; victories += report.victories; defeats += report.defeats; timeouts += report.timeouts
                simulatedSeconds += samples.reduce(0) { $0 + $1.seconds }
                let now = Date(), elapsed = Date().timeIntervalSince(startedAt)
                if let runID {
                    pending.append(MoneyStudyResultRow(money: money, placementPlan: plan.placementIndex,
                        upgradePolicy: plan.upgradePolicyIndex, results: samples))
                    if pending.count >= 32 || now.timeIntervalSince(lastLog) >= 15 {
                        try dao.insert(pending, runID: runID, completed: completed, rate: Double(completed) / elapsed)
                        pending.removeAll(keepingCapacity: true)
                    }
                }
                if now.timeIntervalSince(lastLog) >= 15 {
                    let rate = Double(completed) / elapsed
                    print(String(format: "%d/%d runs; %.1f/s, ETA %.2fh; %d wins, %d defeats, %d timeouts",
                        completed, requested, rate, Double(requested - completed) / rate / 3600, victories, defeats, timeouts))
                    fflush(stdout); lastLog = now
                }
            }
            guard completed == requested else { throw DbError.Db(message: "money study: incomplete work count") }
            if let runID {
                try dao.insert(pending, runID: runID, completed: completed, rate: Double(completed) / Date().timeIntervalSince(startedAt))
                let summary = try dao.summary(runID: runID)
                guard summary.count == grid.money.count, summary.allSatisfy({ ($0["runs"] as? Int) == grid.strategyCount * grid.combatSeeds }) else {
                    throw DbError.Db(message: "money study: persisted counts disagree with the requested grid")
                }
                let path = output.appendingPathComponent("summary.json")
                try write(summary, at: path)
                db.simulatorRunDao.finish(id: runID, status: .completed, reportPath: path.path)
            }
        } catch {
            if let runID { db.simulatorRunDao.finish(id: runID, status: .failed, errorMessage: String(describing: error)) }
            throw error
        }
        let elapsed = Date().timeIntervalSince(startedAt)
        let rate = Double(completed) / elapsed
        let measurement: [String: Any] = ["engine": "shared-game-engine", "runs": completed,
            "elapsedSeconds": elapsed, "simulationsPerSecond": rate,
            "projectedFullRunHours": Double(grid.runCount) / rate / 3600,
            "victories": victories, "defeats": defeats, "timeouts": timeouts,
            "meanSimulationSeconds": simulatedSeconds / Double(completed), "attacksByMode": attacks,
            "demolitionDetonations": detonations, "calibration": calibration]
        try write(measurement, at: output.appendingPathComponent(calibration ? "calibration.json" : "completion.json"))
        print(String(format: "Completed %d shared-game runs in %.2fs (%.1f/s): %d wins, %d defeats, %d timeouts.",
            completed, elapsed, rate, victories, defeats, timeouts))
    }
}

private final class MoneyReplayTrace: SimulationObserver {
    var events: [[String: Any]] = []
    func handle(_ event: SimEvent, atTime time: Double) {
        var row: [String: Any] = ["time": time]
        switch event {
        case let .waveStarted(index): row["event"] = "wave"; row["wave"] = index + 1
        case let .towerBuilt(slot, id): row["event"] = "build"; row["slot"] = slot; row["towerID"] = id.uuidString
        case let .towerUpgraded(slot, level): row["event"] = "upgrade"; row["slot"] = slot; row["tier"] = level
        case let .enemyRemoved(id, type, fate): row["event"] = fate.rawValue; row["spawnID"] = id; row["typeID"] = type.uuidString
        default: return
        }
        events.append(row)
    }
}
