import Foundation
import CryptoKit

/// Ownership: experiment orchestration, GA player choices and observed result
/// comparisons only. SQLite mutations belong to BalanceExperimentDAO; combat,
/// purchases and outcomes belong to GeneticCommander/GameSimulation/BattleEngine.
@MainActor final class BalanceStudy {
    struct Search: Codable {
        let requestedGenerations: Int
        let completedGenerations: Int
        let distinctTrainingCandidates: Int
        let trainingVictories: Int
        let stoppedByLimit: Bool
        let finalists: [BalancePanel]
    }
    struct ScenarioResult: Codable {
        let scenario: BalanceScenario
        let contentSHA256: String
        let enemyCounts: [String: Int]
        let ranged: Search
        let unrestricted: Search
        let frozenBaseline: [BalancePanel]
        let frozenComparisons: [BalanceComparison]
        let adaptedComparison: BalanceComparison?
        let verdict: String
    }
    struct Audit: Codable {
        let runID: UUID
        let candidateID: Int
        let historicalStartingMoney: Int
        let historicalHeroesEnabled: Bool
        let historicalContentSHA256: String
        let historicalWinRate: Double
        let composition: BalanceComposition?
        let issue: String?
    }
    struct Report: Encodable {
        let format = "balance-analysis-v1"
        let runID: UUID
        let level: String
        let startingMoney: Int
        let heroesEnabled = false
        let reinforcementsEnabled = true
        let metaUpgrades: [MetaUpgrade]
        let executableSHA256: String
        let search: SearchSettings
        let hours: Double
        let audit: [Audit]
        var scenarios: [ScenarioResult]
        var completedEvaluations: Int
        var status: String
        let interpretation = "No win found is bounded search evidence, not proof of impossibility. Finalists are frozen using training only; paired held-out comparisons never feed adaptation. Wave replacements retain counts, routes and scheduled times but change authored enemy stats and bounties. Damage changes scale base ranged shot damage only. Other selected meta upgrades remain fixed. Search effort and incomplete panels must be checked before comparing."
    }
    /// Record only settings this tool actually uses; generic GA meta-search and
    /// hero-selection options do not describe a fixed balance experiment.
    struct SearchSettings: Encodable {
        let population: Int
        let generations: Int
        let trainingSeeds: Int
        let validationSeeds: Int
        let finalists: Int
        let maxEvaluations: Int
        let maxGameSeconds: Double
        let seed: UInt64
        let earlyWaveCalls: Bool
        init(_ options: GeneticStudyOptions) {
            population = options.population; generations = options.generations
            trainingSeeds = options.trainingSeeds; validationSeeds = options.validationSeeds
            finalists = options.finalists; maxEvaluations = options.maxEvaluations
            maxGameSeconds = options.maxGameSeconds; seed = options.seed; earlyWaveCalls = options.earlyWaveCalls
        }
    }

    private let db: Db
    private let encoder: JSONEncoder = { let e = JSONEncoder(); e.outputFormatting = [.sortedKeys, .prettyPrinted]; return e }()
    private var nextID = 0, completed = 0
    private var started = ProcessInfo.processInfo.systemUptime
    init(db: Db) { self.db = db }
    private func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private func json<T: Encodable>(_ value: T) throws -> String { String(decoding: try encoder.encode(value), as: UTF8.self) }
    private func write<T: Encodable>(_ value: T, _ url: URL) throws { try encoder.encode(value).write(to: url, options: .atomic) }

    func run(levelName: String, scenarios variants: [BalanceScenario], options: GeneticStudyOptions,
             hours: Double, directory: String) throws {
        guard hours.isFinite, hours > 0, hours <= 24, options.workers == 1,
              options.bountyFraction == 1, options.selectedHeroIDs == nil, options.heroAIEnabled == nil,
              options.metaExchangeFrom == nil, options.starMinimum == nil, options.starMaximum == nil else {
            throw DbError.Db(message: "balance study requires 0–24 hours, one worker, authored bounty, no heroes or meta-search overrides")
        }
        try options.validate(groups: 1)
        guard variants.count <= 64, Set(variants.map(\.id)).count == variants.count,
              !variants.contains(where: { $0.id == "baseline" }) else {
            throw DbError.Db(message: "balance study: duplicate/reserved scenario IDs or more than 64 variants")
        }
        for variant in variants { try variant.validate() }
        guard let levelID = try db.levelInfoDao.getIdBy(levelName: levelName) else {
            throw DbError.Db(message: "Unknown balance-study level '\(levelName)'")
        }
        let pinned = try BountyExperimentDAO.contentCopy(of: db, fraction: 1)
        defer { pinned.close() }
        let original = try AuthoredMoneyStudy(db: pinned, levelID: levelID)
        let baseline = try BalanceAnalysis.maximizingRanged(in: original)
        let baselineDigest = hash(try baseline.replaySnapshot(db: pinned))
        let selected = baseline.battle.playerUpgrades.loadout.selected.sorted { $0.rawValue < $1.rawValue }
        let historical = try db.geneticSolutionDao.analysisCandidates(levelID: levelID)
        var audit: [Audit] = [], seeds: [GeneticStrategy] = options.seedStrategies
        for record in historical {
            let composition = try? BalanceComposition(strategy: record.candidate.strategy, study: original)
            audit.append(Audit(runID: record.runID, candidateID: record.candidate.id,
                historicalStartingMoney: record.context.startingMoney, historicalHeroesEnabled: record.heroesEnabled,
                historicalContentSHA256: record.context.contentSHA256, historicalWinRate: record.candidate.fitness.winRate,
                composition: composition, issue: composition == nil ? "unknown_or_invalid_historical_plan" : composition?.singleKind.map { "single_type_plan:\($0)" }))
            if composition != nil {
                seeds.append(try record.candidate.strategy.selectingMetaUpgrades(selected, in: baseline))
            }
        }
        seeds = try seeds.map { try $0.selectingMetaUpgrades(selected, in: baseline) }
        let output = URL(fileURLWithPath: directory, isDirectory: true).standardizedFileURL.resolvingSymlinksInPath()
        let checkout = Db.authoredDatabaseURL.deletingLastPathComponent().deletingLastPathComponent().resolvingSymlinksInPath().path
        guard output.path != checkout, !output.path.hasPrefix(checkout + "/") else {
            throw DbError.Db(message: "balance reports must be outside the source checkout")
        }
        let reportURL = output.appendingPathComponent("balance-report.json")
        guard !FileManager.default.fileExists(atPath: reportURL.path) else {
            throw DbError.Db(message: "balance study: use a new report directory")
        }
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let executable = hash(try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[0])))
        let scenarios = [BalanceScenario.baseline] + variants
        let stageCount = scenarios.count * 2 + variants.count
        let secondsPerStage = hours * 3600 / Double(stageCount)
        let evaluationsPerStage = options.maxEvaluations / stageCount
        guard evaluationsPerStage >= options.population * options.trainingSeeds + options.finalists * options.validationSeeds else {
            throw DbError.Db(message: "balance study: max-evaluations must cover initial population and validation in each of \(stageCount) stages")
        }
        let dao = try MoneyStudyDAO(db: db)
        let runID = try db.simulatorRunDao.begin(levelName: levelName, focus: "balance analysis: ranged only, no heroes, maximum marksmanship",
                                               totalIterations: options.maxEvaluations, outputPath: db.path)
        var report = Report(runID: runID, level: levelName, startingMoney: baseline.level.startingMoney,
            metaUpgrades: selected, executableSHA256: executable, search: SearchSettings(options), hours: hours,
            audit: audit, scenarios: [], completedEvaluations: 0, status: "running")
        try dao.begin(runID: runID, configuration: json(report),
                      contentSHA256: baselineDigest, plans: "{}")
        started = ProcessInfo.processInfo.systemUptime
        var baselineFinalists: [BalancePanel] = []
        do {
            try write(report, reportURL)
            for scenario in scenarios {
                if scenario.id != "baseline", !baselineFinalists.contains(where: { $0.victories > 0 }) {
                    report.status = "baseline_not_established"; break
                }
                guard hash(try baseline.replaySnapshot(db: pinned)) == baselineDigest else {
                    throw DbError.Db(message: "balance study: external map content changed during the experiment")
                }
                let copy = try BalanceExperimentDAO.contentCopy(of: pinned, levelID: levelID, scenario: scenario)
                defer { copy.close() }
                let study = try BalanceAnalysis.maximizingRanged(in: AuthoredMoneyStudy(db: copy, levelID: levelID))
                let content = try study.replaySnapshot(db: copy, heroesEnabled: false)
                try content.write(to: output.appendingPathComponent("\(scenario.id)-content.json"), options: .atomic)
                let restricted = try study.restrictingTowers(to: [.ranged])
                let trainingSeeds = (0..<options.trainingSeeds).map { options.seed &+ UInt64($0) }
                let validationSeeds = (0..<options.validationSeeds).map { options.seed &+ 1_000_000 &+ UInt64($0) }
                var frozen: [BalancePanel] = []
                if scenario.id != "baseline" {
                    let deadline = ProcessInfo.processInfo.systemUptime + secondsPerStage
                    for panel in baselineFinalists {
                        if let replayed = try evaluate(panel.candidate.strategy, study: restricted, seeds: validationSeeds,
                            generation: 0, panel: 2, options: options, runID: runID, dao: dao, deadline: deadline) {
                            frozen.append(replayed)
                        }
                    }
                }
                print("Balance \(scenario.id): ranged-only search; authored money \(study.level.startingMoney), heroes off")
                let warmSeeds = baselineFinalists.map { $0.candidate.strategy } + seeds
                let ranged = try search(study: restricted, seeds: warmSeeds.filter {
                    (try? BalanceComposition(strategy: $0, study: restricted)) != nil
                }, options: options, runID: runID, dao: dao, trainingSeeds: trainingSeeds, validationSeeds: validationSeeds,
                    seconds: secondsPerStage, evaluationCap: evaluationsPerStage)
                if scenario.id == "baseline" { baselineFinalists = ranged.finalists }
                print("Balance \(scenario.id): unrestricted control")
                let mixed = try search(study: study, seeds: ranged.finalists.map { $0.candidate.strategy } + seeds,
                    options: options, runID: runID, dao: dao, trainingSeeds: trainingSeeds, validationSeeds: validationSeeds,
                    seconds: secondsPerStage, evaluationCap: evaluationsPerStage)
                let counts = Dictionary(uniqueKeysWithValues: study.battle.enemies.map { enemy in
                    (enemy.key, study.level.waves.flatMap(\.spawns).filter { $0.enemyTypeID == enemy.id }.reduce(0) { $0 + $1.count })
                })
                let comparisons = zip(baselineFinalists, frozen).map {
                    BalanceComparison(baseline: $0.candidate.evaluations, variant: $1.candidate.evaluations)
                }
                let verdict = scenario.id == "baseline"
                    ? (ranged.finalists.contains { $0.victories > 0 } ? "ranged_baseline_confirmed" : "baseline_not_established")
                    : BalanceAnalysis.verdict(baselineWon: baselineFinalists.contains { $0.victories > 0 },
                        trainingVictories: ranged.trainingVictories,
                        ranged: ranged.finalists, mixed: mixed.finalists,
                        expectedFinalists: options.finalists, expectedSeeds: options.validationSeeds,
                        frozen: frozen, expectedFrozen: baselineFinalists.count)
                let adapted = baselineFinalists.first.flatMap { base in ranged.finalists.first.map {
                    BalanceComparison(baseline: base.candidate.evaluations, variant: $0.candidate.evaluations)
                } }
                report.scenarios.append(ScenarioResult(scenario: scenario, contentSHA256: hash(content), enemyCounts: counts,
                    ranged: ranged, unrestricted: mixed, frozenBaseline: frozen, frozenComparisons: comparisons,
                    adaptedComparison: adapted, verdict: verdict))
                report.completedEvaluations = completed
                try write(report, reportURL)
                try dao.recordAdaptiveCheckpoint(runID: runID, json: json(report))
                print("Balance \(scenario.id): \(verdict); \(completed) total games")
            }
            if report.status == "running" { report.status = "completed" }
            report.completedEvaluations = completed
            try write(report, reportURL)
            try dao.recordAdaptiveCheckpoint(runID: runID, json: json(report))
            try dao.finishAdaptive(runID: runID, completed: completed, reportPath: reportURL.path)
            print("Balance report: \(reportURL.path)")
        } catch {
            report.status = "failed: \(error)"; report.completedEvaluations = completed
            try? write(report, reportURL)
            db.simulatorRunDao.finish(id: runID, status: .failed, reportPath: reportURL.path, errorMessage: String(describing: error))
            throw error
        }
    }

    private func evaluate(_ strategy: GeneticStrategy, study: AuthoredMoneyStudy, seeds: [UInt64], generation: Int,
                          panel: Int, options: GeneticStudyOptions, runID: UUID, dao: MoneyStudyDAO,
                          deadline: Double) throws -> BalancePanel? {
        try strategy.validate(study: study)
        var values: [GeneticEvaluation] = [], counts: [String: [String: Int]] = [:]
        for seed in seeds {
            guard ProcessInfo.processInfo.systemUptime < deadline, completed < options.maxEvaluations else { break }
            var built: [String: Int] = [:]
            let value = try GeneticCommander.evaluate(strategy, recording: .database(db.levelRunDao, .simulator),
                content: study.battle, money: study.level.startingMoney, seed: seed, maxSeconds: options.maxGameSeconds,
                heroesEnabled: false, towerObserver: { towers in
                    for tower in towers { built[tower.kind.rawValue, default: 0] += 1 }
                })
            if let allowed = study.allowedTowerKinds {
                guard built.keys.allSatisfy({ key in allowed.contains { $0.rawValue == key } }) else {
                    throw DbError.Db(message: "balance search built a forbidden tower kind")
                }
            }
            values.append(value); counts[String(seed)] = built; completed += 1
        }
        guard !values.isEmpty else { return nil }
        let candidate = GeneticCandidate(id: nextID, generation: generation,
            starsUsed: study.battle.playerUpgrades.loadout.spentStars, strategy: strategy, evaluations: values)
        nextID += 1
        let result = BalancePanel(candidate: candidate, builtTowersBySeed: counts)
        try dao.insert([MoneyStudyResultRow(money: study.level.startingMoney, placementPlan: candidate.id,
            upgradePolicy: panel, results: values.map(\.result), evidenceJSON: json(result))],
            runID: runID, completed: completed, rate: Double(completed) / max(0.001, ProcessInfo.processInfo.systemUptime - started))
        return result
    }

    private func search(study: AuthoredMoneyStudy, seeds: [GeneticStrategy], options: GeneticStudyOptions,
                        runID: UUID, dao: MoneyStudyDAO, trainingSeeds: [UInt64], validationSeeds: [UInt64],
                        seconds: Double, evaluationCap: Int) throws -> Search {
        let start = ProcessInfo.processInfo.systemUptime, initialCount = completed
        let searchDeadline = start + seconds * 0.8, deadline = start + seconds
        let trainingCap = evaluationCap - options.finalists * validationSeeds.count
        let seedPanel = try BalanceAnalysis.initialSeeds(seeds, limit: options.population / 2)
        let upgrades = study.battle.playerUpgrades.loadout.selected.sorted { $0.rawValue < $1.rawValue }
        var rng = SeededRNG(seed: options.seed).fork(stream: 515)
        var archive: [GeneticCandidate] = [], seen: Set<Data> = []
        var generations = 0, trainingVictories = 0
        func admit(_ strategy: GeneticStrategy, generation: Int) throws {
            guard seen.insert(try encoder.encode(strategy)).inserted else { return }
            if let panel = try evaluate(strategy, study: study, seeds: trainingSeeds, generation: generation,
                panel: 0, options: options, runID: runID, dao: dao, deadline: searchDeadline) {
                trainingVictories += panel.victories
                // Incomplete panels are recorded, but cannot win finalist seats.
                if panel.candidate.evaluations.count == trainingSeeds.count { archive.append(panel.candidate) }
            }
        }
        for generation in 0..<options.generations {
            let parents = Array(GeneticCandidate.ranked(archive).prefix(options.population))
            var filled = 0
            for index in 0..<options.population {
                guard ProcessInfo.processInfo.systemUptime < searchDeadline,
                      completed - initialCount + trainingSeeds.count <= trainingCap else { break }
                var strategy: GeneticStrategy
                if generation == 0 {
                    if index < seedPanel.count { strategy = seedPanel[index] }
                    else {
                        let plan = try MoneyStudyPlan(study: study, placementIndex: index,
                            upgradePolicyIndex: index % 10, seed: options.seed)
                        strategy = GeneticStrategy(plan: plan, metaUpgrades: upgrades,
                            reinforcements: .random(paths: study.level.paths, rng: &rng))
                        if options.earlyWaveCalls { strategy.earlyWaves.mutate(waveCount: study.level.numWaves, rng: &rng) }
                    }
                } else {
                    guard !parents.isEmpty else { break }
                    func parent() -> GeneticStrategy {
                        let a = parents[Int.random(in: parents.indices, using: &rng)]
                        let b = parents[Int.random(in: parents.indices, using: &rng)]
                        return a.fitness < b.fitness ? b.strategy : a.strategy
                    }
                    strategy = GeneticStrategy.crossover(parent(), parent(), slots: study.level.towerSlots.count, rng: &rng)
                    strategy.mutate(study: study, metaChoices: [upgrades], rng: &rng,
                        earlyWaveCallsEnabled: options.earlyWaveCalls, metaMutationEnabled: false)
                }
                if !options.earlyWaveCalls { strategy.earlyWaves = .automatic }
                try admit(strategy, generation: generation); filled += 1
            }
            if filled == options.population { generations += 1 } else { break }
            if let best = GeneticCandidate.ranked(archive).first {
                print("  generation \(generation + 1): \(archive.count) plans, best training win rate \(best.fitness.winRate)")
            }
        }
        let frozen = Array(GeneticCandidate.ranked(archive).prefix(options.finalists))
        var finalists: [BalancePanel] = []
        for candidate in frozen {
            if let result = try evaluate(candidate.strategy, study: study, seeds: validationSeeds,
                generation: candidate.generation, panel: 1, options: options, runID: runID, dao: dao, deadline: deadline) {
                finalists.append(result)
            }
        }
        return Search(requestedGenerations: options.generations, completedGenerations: generations,
            distinctTrainingCandidates: archive.count, trainingVictories: trainingVictories,
            stoppedByLimit: generations < options.generations, finalists: finalists)
    }
}
