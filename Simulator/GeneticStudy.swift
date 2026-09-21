import Foundation
import CryptoKit

struct GeneticStudyOptions: Codable {
    var money = 660
    var population = 64 // Per exact star-spend group.
    var generations = 300
    var trainingSeeds = 3
    var validationSeeds = 64
    var finalists = 8 // Per exact star-spend group.
    var maxEvaluations = 50_000
    var hours = 8.0
    var maxGameSeconds = 1800.0
    var seed: UInt64 = 1776
    var starMinimum = 0
    var starMaximum: Int?
    var starStep = 1
    var bountyFraction = 1.0
    var fixedMeta = false
    var earlyWaveCalls = true
    var seedStrategies: [GeneticStrategy] = []

    func starValues(earned: Int) throws -> [Int] {
        let maximum = starMaximum ?? earned
        guard starMinimum >= 0, maximum >= starMinimum, maximum <= earned, starStep > 0,
              (maximum - starMinimum) % starStep == 0 else {
            throw DbError.Db(message: "genetic study: star range must be exact nonnegative steps within the database's \(earned) earned stars")
        }
        return Array(stride(from: starMinimum, through: maximum, by: starStep))
    }

    func validate(groups: Int) throws {
        guard money > 0, (4...1024).contains(population), (1...100_000).contains(generations),
              (1...1000).contains(trainingSeeds), (1...10_000).contains(validationSeeds),
              (1...population).contains(finalists),
              maxEvaluations >= groups * (population * trainingSeeds + finalists * validationSeeds),
              bountyFraction.isFinite, (0...1).contains(bountyFraction), seedStrategies.count <= population,
              hours.isFinite, hours > 0, hours <= 24, maxGameSeconds.isFinite, maxGameSeconds > 0 else {
            throw DbError.Db(message: "genetic study: invalid budget; evaluation ceiling must cover initial populations and validation for all \(groups) reachable star groups")
        }
    }
}

private struct GeneticCandidate: Codable {
    let id: Int
    let generation: Int
    let starsUsed: Int
    let strategy: GeneticStrategy
    let evaluations: [GeneticEvaluation]
    var fitness: GeneticFitness { GeneticFitness(evaluations) }
}

private struct GeneticReplayDocument: Codable {
    let format: String
    let contentSHA256: String
    let executableSHA256: String
    let money: Int
    let maxGameSeconds: Double
    let starsUsed: Int
    let bountyFraction: Double
    let strategy: GeneticStrategy
    let expected: GeneticEvaluation
}

/// Search coordination and recording only. All battle evaluation goes through
/// GeneticCommander -> GameSimulation -> the game's player-facing engine APIs.
@MainActor final class GeneticStudy {
    private let db: Db
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; return encoder
    }()
    init(db: Db) { self.db = db }
    private func encoded<T: Encodable>(_ value: T) throws -> String { String(decoding: try encoder.encode(value), as: UTF8.self) }
    private func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private func write<T: Encodable>(_ value: T, to url: URL) throws { try encoder.encode(value).write(to: url, options: .atomic) }
    private func executableHash() throws -> String { hash(try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[0]))) }
    private func load(_ name: String, bountyFraction: Double) throws -> AuthoredMoneyStudy {
        guard let id = try db.levelInfoDao.getIdBy(levelName: name) else { throw DbError.Db(message: "Unknown authored level '\(name)'") }
        let experiment = try BountyExperimentDAO.contentCopy(of: db, fraction: bountyFraction)
        defer { experiment.close() }
        return try AuthoredMoneyStudy(db: experiment, levelID: id)
    }

    func replay(levelName: String, document: String, directory: String) throws {
        let replay = try JSONDecoder().decode(GeneticReplayDocument.self, from: Data(contentsOf: URL(fileURLWithPath: document)))
        let study = try load(levelName, bountyFraction: replay.bountyFraction)
        let content = try AuthoredMoneySweep(db: db).snapshot(study)
        guard replay.format == "genetic-replay-v5", replay.contentSHA256 == hash(content),
              replay.executableSHA256 == (try executableHash()) else {
            throw DbError.Db(message: "Replay content or engine executable differs from the recorded experiment; retain the original binary for older replay formats")
        }
        try replay.strategy.validate(study: study)
        guard try replay.strategy.playerState(in: study.battle).loadout.spentStars == replay.starsUsed else {
            throw DbError.Db(message: "Replay starsUsed differs from its selected meta upgrades")
        }
        let actual = try GeneticCommander.evaluate(replay.strategy, content: study.battle, money: replay.money,
            seed: replay.expected.seed, maxSeconds: replay.maxGameSeconds)
        guard actual == replay.expected else {
            throw DbError.Db(message: "Genetic replay differs from its recorded engine outcome/economy trace")
        }
        let output = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try write(actual, to: output.appendingPathComponent("verified-replay.json"))
        print("Verified exact genetic replay: \(replay.starsUsed) stars, \(actual.result.outcome), \(actual.result.livesRemaining) lives, \(actual.wavesStarted) waves, \(actual.reinforcementDeployments.count) reinforcement deployments")
    }

    func run(levelName: String, options: GeneticStudyOptions, directory: String) throws {
        let study = try load(levelName, bountyFraction: options.bountyFraction)
        let meta = try GeneticMetaSearch(player: study.battle.playerUpgrades)
        let requestedStars = try options.starValues(earned: meta.earnedStars)
        let active = study.battle.playerUpgrades.loadout
        if options.fixedMeta && requestedStars != [active.spentStars] {
            throw DbError.Db(message: "fixed meta requires exactly the database's \(active.spentStars)-star spending group")
        }
        let choicesByStars = options.fixedMeta
            ? [active.spentStars: [active.selected.sorted { $0.rawValue < $1.rawValue }]] : meta.choicesByStars
        let starGroups = requestedStars.filter { choicesByStars[$0] != nil }
        try options.validate(groups: starGroups.count)
        for strategy in options.seedStrategies {
            try strategy.validate(study: study)
            guard options.earlyWaveCalls || strategy.earlyWaves.decisions.allSatisfy({ $0.policy == .automatic }) else {
                throw DbError.Db(message: "early-wave calls are disabled but a seed strategy calls early")
            }
            let state = try strategy.playerState(in: study.battle)
            guard starGroups.contains(state.loadout.spentStars), !options.fixedMeta || state.loadout.selected == active.selected else {
                throw DbError.Db(message: "seed strategy does not match requested star groups or fixed database meta selection")
            }
        }
        let content = try AuthoredMoneySweep(db: db).snapshot(study)
        let digest = hash(content), executable = try executableHash()
        let output = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        guard !FileManager.default.fileExists(atPath: output.appendingPathComponent("run-id.txt").path) else {
            throw DbError.Db(message: "Use a new report directory; an experiment already exists here")
        }
        try content.write(to: output.appendingPathComponent("content.json"), options: .atomic)
        let trainingSeeds = (0..<options.trainingSeeds).map { options.seed &+ UInt64($0) }
        let validationSeeds = (0..<options.validationSeeds).map { options.seed &+ 1_000_000 &+ UInt64($0) }
        let configuration: [String: Any] = [
            "algorithm": "genetic-v5", "options": try JSONSerialization.jsonObject(with: encoder.encode(options)),
            "bountyFraction": options.bountyFraction, "fixedMeta": options.fixedMeta,
            "engine": "shared-game-engine", "level": study.level.name, "contentSHA256": digest,
            "executableSHA256": executable, "buildVersion": BuildVersion.version,
            "heroes": false, "reinforcementCommands": true, "earlyWaveCalls": options.earlyWaveCalls,
            "difficulty": study.difficulty.name, "earnedStars": meta.earnedStars,
            "requestedStarsUsed": requestedStars, "reachableStarsUsed": starGroups,
            "databaseSelectedUpgrades": study.battle.playerUpgrades.loadout.selected.map(\.rawValue).sorted(),
            "trainingSeeds": trainingSeeds, "validationSeeds": validationSeeds,
            "fitnessOrder": ["complete-level win rate", "victory lives", "waves reached", "survival on defeats"],
            "sampling": "Separate populations, elites and finalists for exact stars spent. Full battles; no early-wave pruning. Meta selections are candidate genes, not fixed global effects.",
            "searchTimeFraction": 0.85, "placementPlanMeaning": "globally unique genome ID",
            "upgradePolicyMeaning": ["0": "training panel", "1": "held-out panel"],
            "decisionScope": "meta upgrade selection; builds, upgrade branches, ability purchases, order, earliest wave/time, saving; reinforcement target priority and deliberate hold; per-wave early-call delay, visible countdown and enemy-count preference; default rally/obstacle sites and nearest ready demolition site"]
        let configData = try JSONSerialization.data(withJSONObject: configuration, options: [.sortedKeys, .prettyPrinted])
        try configData.write(to: output.appendingPathComponent("configuration.json"), options: .atomic)
        let dao = try MoneyStudyDAO(db: db)
        let runID = try db.simulatorRunDao.begin(levelName: study.level.name,
            focus: "genetic by stars; \(options.money) coins; \(requestedStars.count) spend groups", totalIterations: options.maxEvaluations, outputPath: db.path)
        let start = ProcessInfo.processInfo.systemUptime
        let deadline = start + options.hours * 3600, searchDeadline = start + options.hours * 3600 * 0.85
        var completed = 0, cacheHits = 0, nextID = 0, completedGenerations = 0
        var cache: [String: GeneticCandidate] = [:]
        var archive: [Int: [GeneticCandidate]] = [:], best: [Int: GeneticCandidate] = [:]
        var population: [Int: [GeneticCandidate]] = [:]
        var rng = SeededRNG(seed: options.seed).fork(stream: 91)
        var initialChoices = choicesByStars
        for stars in starGroups { initialChoices[stars]!.shuffle(using: &rng) }
        let trainingCap = options.maxEvaluations - starGroups.count * options.finalists * options.validationSeeds
        var lastLog = start

        func ranked(_ candidates: [GeneticCandidate]) -> [GeneticCandidate] {
            candidates.sorted { $0.fitness == $1.fitness ? $0.id < $1.id : $0.fitness > $1.fitness }
        }
        func initialStrategy(stars: Int, index: Int, immigrant: Bool = false) throws -> GeneticStrategy {
            let seeds = try options.seedStrategies.filter { try $0.playerState(in: study.battle).loadout.spentStars == stars }
            if !immigrant && index < seeds.count { return seeds[index] }
            let choices = initialChoices[stars]!
            let active = study.battle.playerUpgrades.loadout
            let selection = !immigrant && index == 0 && active.spentStars == stars
                ? active.selected.sorted { $0.rawValue < $1.rawValue }
                : choices[immigrant ? Int.random(in: choices.indices, using: &rng) : index % choices.count]
            // Initial placement heuristics see this candidate's actual effects.
            let selectedStudy = try study.selectingMetaUpgrades(Set(selection))
            let plan = try MoneyStudyPlan(study: selectedStudy,
                placementIndex: immigrant ? Int.random(in: 0..<1_000_000, using: &rng) : (index == 0 ? 7 : index - 1),
                upgradePolicyIndex: immigrant ? Int.random(in: 0..<10, using: &rng) : (index == 0 ? 2 : (index - 1) % 10), seed: options.seed)
            var strategy = GeneticStrategy(plan: plan, metaUpgrades: selection,
                reinforcements: !immigrant && index == 0 ? .immediate : .random(paths: study.level.paths, rng: &rng),
                earlyWaves: options.earlyWaveCalls && (immigrant || index > 0)
                    ? .random(waveCount: study.level.numWaves, rng: &rng) : .automatic)
            if index > 0 && index % 3 == 0 {
                for i in strategy.decisions.indices { strategy.decisions[i].saveForPurchase = true }
            }
            return strategy
        }
        func evaluate(_ strategy: GeneticStrategy, generation: Int, stars: Int) throws -> GeneticCandidate? {
            try strategy.validate(study: study)
            guard try strategy.playerState(in: study.battle).loadout.spentStars == stars else {
                throw DbError.Db(message: "genetic candidate selected upgrades differ from its \(stars)-star group")
            }
            // Canonical DNA includes the selected meta upgrade IDs.
            let key = hash(try encoder.encode(strategy))
            if let candidate = cache[key] { cacheHits += 1; return candidate }
            guard completed + trainingSeeds.count <= trainingCap,
                  ProcessInfo.processInfo.systemUptime < searchDeadline else { return nil }
            var evaluations: [GeneticEvaluation] = []
            for seed in trainingSeeds {
                evaluations.append(try GeneticCommander.evaluate(strategy, content: study.battle,
                    money: options.money, seed: seed, maxSeconds: options.maxGameSeconds))
            }
            let candidate = GeneticCandidate(id: nextID, generation: generation, starsUsed: stars, strategy: strategy, evaluations: evaluations)
            nextID += 1; completed += evaluations.count
            try dao.insert([MoneyStudyResultRow(money: options.money, placementPlan: candidate.id,
                upgradePolicy: 0, results: evaluations.map(\.result), evidenceJSON: try encoded(candidate))], runID: runID, completed: completed,
                rate: Double(completed) / max(0.001, ProcessInfo.processInfo.systemUptime - start))
            cache[key] = candidate
            archive[stars] = Array(ranked((archive[stars] ?? []) + [candidate]).prefix(options.population))
            if best[stars] == nil || candidate.fitness > best[stars]!.fitness {
                best[stars] = candidate
                let replay = GeneticReplayDocument(format: "genetic-replay-v5", contentSHA256: digest,
                    executableSHA256: executable, money: options.money, maxGameSeconds: options.maxGameSeconds,
                    starsUsed: stars, bountyFraction: options.bountyFraction, strategy: strategy,
                    expected: evaluations.first(where: { $0.result.outcome == .victory }) ?? evaluations[0])
                try write(replay, to: output.appendingPathComponent("best-stars-\(stars).json"))
                print("New best at \(stars) stars: genome \(candidate.id), generation \(generation), wins \(evaluations.filter { $0.result.outcome == .victory }.count)/\(evaluations.count), mean victory lives \(candidate.fitness.meanVictoryLives)")
                fflush(stdout)
            }
            let now = ProcessInfo.processInfo.systemUptime
            if now - lastLog >= 15 {
                print("Genetic progress: \(completed) engine games, \(nextID) genomes, \(best.count)/\(starGroups.count) star groups evaluated")
                fflush(stdout); lastLog = now
            }
            return candidate
        }
        func brief(_ candidate: GeneticCandidate) throws -> [String: Any] {
            let evaluations = candidate.evaluations
            return ["id": candidate.id, "generation": candidate.generation, "starsUsed": candidate.starsUsed,
                "selectedMetaUpgrades": candidate.strategy.metaUpgrades.map { id -> [String: Any] in
                    let definition = study.battle.playerUpgrades.loadout.catalog[id]
                    return ["id": id.rawValue, "name": definition.title, "stars": definition.cost]
                }, "plannedActions": candidate.strategy.decisions.count,
                "games": evaluations.count, "wins": evaluations.filter { $0.result.outcome == .victory }.count,
                "timeouts": evaluations.filter { $0.result.outcome == .timeout }.count,
                "reinforcementStrategy": try JSONSerialization.jsonObject(with: encoder.encode(candidate.strategy.reinforcements)),
                "meanReinforcementDeployments": Double(evaluations.reduce(0) { $0 + $1.reinforcementDeployments.count }) / Double(evaluations.count),
                "earlyWaveStrategy": try JSONSerialization.jsonObject(with: encoder.encode(candidate.strategy.earlyWaves)),
                "meanEarlyWaveCalls": Double(evaluations.reduce(0) { $0 + $1.waveCalls.filter { $0.wave > 1 }.count }) / Double(evaluations.count),
                "meanEarlyCallBonus": Double(evaluations.reduce(0) { $0 + $1.waveCalls.reduce(0) { $0 + $1.earlyCallBonus } }) / Double(evaluations.count),
                "minimumLives": evaluations.map(\.result.livesRemaining).min() ?? 0,
                "meanLives": evaluations.reduce(0.0) { $0 + Double($1.result.livesRemaining) } / Double(evaluations.count)]
        }

        do {
            try dao.begin(runID: runID, configuration: String(decoding: configData, as: UTF8.self),
                contentSHA256: digest, plans: "{\"format\":\"genetic-v5\",\"storage\":\"starsUsed, meta upgrade genes, tower, reinforcement and early-wave DNA, deployment and wave-call receipts and explicit seeds in each result row\"}")
            try Data(runID.uuidString.utf8).write(to: output.appendingPathComponent("run-id.txt"), options: .atomic)
            print("Started genetic study \(runID): \(study.level.name), \(options.money) coins, no heroes, \(meta.earnedStars) stars earned")
            print("Exact star spend groups: \(requestedStars); population \(options.population) and \(options.finalists) finalists per reachable group")
            print("Bounty fraction: \(options.bountyFraction); fixed database meta selection: \(options.fixedMeta)")
            fflush(stdout)
            initial: for index in 0..<options.population {
                for stars in starGroups {
                    let strategy = try initialStrategy(stars: stars, index: index)
                    guard let candidate = try evaluate(strategy, generation: 0, stars: stars) else { break initial }
                    population[stars, default: []].append(candidate)
                }
            }
            population = population.mapValues(ranked)
            if !population.isEmpty { completedGenerations = 1 }
            if options.generations > 1 {
                for generation in 1..<options.generations {
                    guard !population.isEmpty, completed < trainingCap,
                          ProcessInfo.processInfo.systemUptime < searchDeadline else { break }
                    let eliteCount = max(1, options.population / 4)
                    var next = population.mapValues { Array($0.prefix(eliteCount)) }
                    let before = completed
                    breeding: for _ in 0..<options.population {
                        for stars in starGroups where (next[stars]?.count ?? 0) < options.population {
                            guard let parents = population[stars], !parents.isEmpty else { continue }
                            func parent() -> GeneticStrategy {
                                let samples = (0..<3).map { _ in parents[Int.random(in: parents.indices, using: &rng)] }
                                return ranked(samples)[0].strategy
                            }
                            var child: GeneticStrategy
                            if (next[stars]?.count ?? 0) < eliteCount + max(1, options.population / 8) {
                                child = try initialStrategy(stars: stars, index: 0, immigrant: true)
                            } else if Bool.random(using: &rng) {
                                child = GeneticStrategy.crossover(parent(), parent(), slots: study.level.towerSlots.count, rng: &rng)
                            } else { child = parent() }
                            for _ in 0..<Int.random(in: 1...4, using: &rng) {
                                child.mutate(study: study, metaChoices: choicesByStars[stars]!, rng: &rng,
                                             earlyWaveCallsEnabled: options.earlyWaveCalls)
                            }
                            guard let candidate = try evaluate(child, generation: generation, stars: stars) else { break breeding }
                            next[stars, default: []].append(candidate)
                        }
                    }
                    population = next.mapValues(ranked)
                    completedGenerations = generation + 1
                    let checkpoint = Dictionary(uniqueKeysWithValues: population.map { (String($0.key), $0.value.map(\.id)) })
                    try dao.recordAdaptiveCheckpoint(runID: runID, json: encoded(checkpoint))
                    try write(population.values.flatMap { $0 }.sorted { $0.id < $1.id }, to: output.appendingPathComponent("population.json"))
                    if completed == before { break }
                }
            }
            try write(population.values.flatMap { $0 }.sorted { $0.id < $1.id }, to: output.appendingPathComponent("population.json"))
            // Freeze every group's finalists before any held-out result is seen.
            let finalists = starGroups.flatMap { Array(ranked(archive[$0] ?? []).prefix(options.finalists)) }
            var samplesByID: [Int: [GeneticEvaluation]] = [:]
            // Round-robin validation gives every star group the same seed panel,
            // including partial panels when the global wall-time budget expires.
            validation: for seed in validationSeeds {
                for candidate in finalists {
                    guard completed < options.maxEvaluations, ProcessInfo.processInfo.systemUptime < deadline else { break validation }
                    samplesByID[candidate.id, default: []].append(try GeneticCommander.evaluate(candidate.strategy,
                        content: study.battle, money: options.money, seed: seed, maxSeconds: options.maxGameSeconds))
                    completed += 1
                }
                let checkpoint = finalists.compactMap { candidate -> GeneticCandidate? in
                    guard let samples = samplesByID[candidate.id] else { return nil }
                    return GeneticCandidate(id: candidate.id, generation: candidate.generation, starsUsed: candidate.starsUsed,
                        strategy: candidate.strategy, evaluations: samples)
                }
                try write(checkpoint, to: output.appendingPathComponent("validation.json"))
            }
            var validations: [GeneticCandidate] = []
            for candidate in finalists {
                guard let samples = samplesByID[candidate.id], !samples.isEmpty else { continue }
                let validated = GeneticCandidate(id: candidate.id, generation: candidate.generation, starsUsed: candidate.starsUsed,
                    strategy: candidate.strategy, evaluations: samples)
                validations.append(validated)
                try dao.insert([MoneyStudyResultRow(money: options.money, placementPlan: candidate.id,
                    upgradePolicy: 1, results: samples.map(\.result), evidenceJSON: try encoded(validated))], runID: runID, completed: completed,
                    rate: Double(completed) / max(0.001, ProcessInfo.processInfo.systemUptime - start))
                print("Held-out \(candidate.starsUsed) stars, genome \(candidate.id): \(samples.filter { $0.result.outcome == .victory }.count)/\(samples.count) wins")
            }
            try write(validations, to: output.appendingPathComponent("validation.json"))
            let persisted = try dao.geneticSummaryByStars(runID: runID)
            let starResults: [[String: Any]] = try requestedStars.map { stars in
                let tested = validations.filter { $0.starsUsed == stars }
                let reachable = meta.choicesByStars[stars] != nil
                let complete = reachable && tested.count == options.finalists && tested.allSatisfy { $0.evaluations.count == options.validationSeeds }
                return ["starsUsed": stars, "earnedStars": meta.earnedStars, "unspentStars": meta.earnedStars - stars,
                    "legalMetaLoadouts": meta.choicesByStars[stars]?.count ?? 0,
                    "searchedMetaLoadouts": choicesByStars[stars]?.count ?? 0,
                    "status": !reachable ? "no_legal_loadout" : (best[stars] == nil ? "not_evaluated" : (complete ? "validation_complete" : "validation_incomplete")),
                    "training": persisted.first { ($0["starsUsed"] as? Int) == stars && ($0["panel"] as? Int) == 0 } ?? [:],
                    "bestTraining": try best[stars].map(brief) as Any? ?? NSNull(),
                    "bestReplay": best[stars].map { _ in "best-stars-\(stars).json" } as Any? ?? NSNull(),
                    "validation": try tested.map(brief), "validationComplete": complete]
            }
            let summary: [String: Any] = ["format": "genetic-summary-v5", "runID": runID.uuidString,
                "bountyFraction": options.bountyFraction, "fixedMeta": options.fixedMeta,
                "heroes": false, "reinforcementCommands": true, "earlyWaveCalls": options.earlyWaveCalls,
                "engineGames": completed, "uniqueGenomes": nextID, "cacheHits": cacheHits, "generations": completedGenerations,
                "elapsedSeconds": ProcessInfo.processInfo.systemUptime - start, "contentSHA256": digest,
                "money": options.money, "earnedStars": meta.earnedStars, "starResults": starResults,
                "validationComplete": !starGroups.isEmpty && starResults.filter { ($0["legalMetaLoadouts"] as? Int ?? 0) > 0 }.allSatisfy { $0["validationComplete"] as? Bool == true },
                "note": "Grouped by exact stars spent, not earned. Upgrade selections are candidate genes. No winner found is not proof of impossibility. Search and held-out evidence are separate; old fixed-loadout runs are not results for other star budgets."]
            let summaryURL = output.appendingPathComponent("summary.json")
            try JSONSerialization.data(withJSONObject: summary, options: [.sortedKeys, .prettyPrinted]).write(to: summaryURL, options: .atomic)
            try dao.finishAdaptive(runID: runID, completed: completed, reportPath: summaryURL.path)
            print("Completed genetic study: \(completed) engine games across \(starGroups.count) star groups; report \(summaryURL.path)")
        } catch {
            db.simulatorRunDao.finish(id: runID, status: .failed, errorMessage: String(describing: error))
            throw error
        }
    }
}
