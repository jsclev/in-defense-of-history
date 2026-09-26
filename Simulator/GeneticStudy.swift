import Foundation
import CryptoKit
import OSLog

struct GeneticStudyOptions: Codable {
    var money: Int?
    var workers = 1
    var population = 64 // Per exact star-spend group.
    var generations = 300
    var trainingSeeds = 3
    var validationSeeds = 64
    var finalists = 8 // Per exact star-spend group.
    var maxEvaluations = 50_000
    var hours = 8.0
    var maxGameSeconds = 1800.0
    var seed: UInt64 = 1776
    var starMinimum: Int?
    var starMaximum: Int?
    var starStep = 1
    var bountyFraction = 1.0
    var fixedMeta = false
    var earlyWaveCalls = true
    var seedStrategies: [GeneticStrategy] = []
    var metaSelections = 8
    var minimumMetaCandidates = 4
    var metaAdaptationGenerations = 2
    var metaExchangeFrom: GeneticStrategy?
    var selectedHeroIDs: [UUID]?
    var heroAIEnabled: Bool?

    func starValues(earned: Int) throws -> [Int] {
        let maximum = starMaximum ?? earned
        let minimum = starMinimum ?? maximum
        guard minimum >= 0, maximum >= minimum, maximum <= earned, starStep > 0,
              (maximum - minimum) % starStep == 0 else {
            throw DbError.Db(message: "genetic study: star range must be exact nonnegative steps within the database's \(earned) earned stars")
        }
        return Array(stride(from: minimum, through: maximum, by: starStep))
    }

    func validate(groups: Int) throws {
        guard (money == nil || money! > 0), (1...32).contains(workers), (4...1024).contains(population), (1...100_000).contains(generations),
              (1...1000).contains(trainingSeeds), (1...10_000).contains(validationSeeds),
              (1...population).contains(finalists),
              (1...1024).contains(metaSelections), (2...population).contains(minimumMetaCandidates),
              metaAdaptationGenerations >= 2,
              maxEvaluations >= groups * (population * trainingSeeds + finalists * validationSeeds),
              bountyFraction.isFinite, (0...1).contains(bountyFraction), seedStrategies.count <= population,
              hours.isFinite, hours > 0, hours <= 24, maxGameSeconds.isFinite, maxGameSeconds > 0 else {
            throw DbError.Db(message: "genetic study: invalid budget; evaluation ceiling must cover initial populations and validation for all \(groups) reachable star groups")
        }
    }
}


/// Search coordination and recording only. All battle evaluation goes through
/// GeneticCommander -> GameSimulation -> the game's player-facing engine APIs.
@MainActor final class GeneticStudy {
    private let db: Db
    private let reports: SimulatorReports
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; return encoder
    }()
    init(db: Db, reports: SimulatorReports) { self.db = db; self.reports = reports }
    private func encoded<T: Encodable>(_ value: T) throws -> String { String(decoding: try encoder.encode(value), as: UTF8.self) }
    private func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private func write<T: Encodable>(_ value: T, to url: URL) throws { try reports.write(encoder.encode(value), to: url) }
    private func executableHash() throws -> String { hash(try Data(contentsOf: SimulatorStore.executableURL)) }
    private func load(_ id: UUID, bountyFraction: Double, selectedHeroIDs: [UUID]?, heroAIEnabled: Bool?) throws -> AuthoredMoneyStudy {
        let ids = try selectedHeroIDs ?? HeroSelectionStore(dao: db.heroDao).load().ids
        let modes = heroAIEnabled.map { enabled in Dictionary(uniqueKeysWithValues: ids.map { ($0, enabled) }) } ?? [:]
        let experiment = try BountyExperimentDAO.contentCopy(of: db, fraction: bountyFraction,
            selectedHeroIDs: selectedHeroIDs, heroAI: modes)
        defer { experiment.close() }
        return try AuthoredMoneyStudy(db: experiment, levelID: id)
    }

    func replay(levelName: String, document: String) throws {
        SimulatorLog.ga.notice("Replay verification started; level=\(levelName, privacy: .public) document=\(document, privacy: .private(mask: .hash))")
        let replay = try MetaUpgradesFactory.decoder(catalog: db.metaUpgradeDao.get()).decode(GeneticReplayDocument.self, from: Data(contentsOf: URL(fileURLWithPath: document)))
        let study = try replay.loadStudy(db: db, levelName: levelName)
        let content = try study.replaySnapshot(db: db, heroesEnabled: true)
        guard replay.format == "genetic-replay-v6", replay.contentSHA256 == hash(content),
              replay.executableSHA256 == (try executableHash()) else {
            throw DbError.Db(message: "Replay content or engine executable differs from the recorded experiment; retain the original binary for older replay formats")
        }
        try replay.strategy.validate(study: study)
        guard try replay.strategy.playerState(in: study.battle).loadout.spentStars == replay.starsUsed else {
            throw DbError.Db(message: "Replay starsUsed differs from its selected meta upgrades")
        }
        let actual = try GeneticCommander.evaluate(replay.strategy, recording: .database(db.levelRunDao, .simulator), content: study.battle, money: replay.money,
            seed: replay.expected.seed, maxSeconds: replay.maxGameSeconds)
        guard actual == replay.expected else {
            throw DbError.Db(message: "Genetic replay differs from its recorded engine outcome/economy trace")
        }
        let output = reports.root
        try write(actual, to: output.appendingPathComponent("verified-replay.json"))
        SimulatorLog.ga.notice("Replay verified; levelID=\(study.level.id.uuidString, privacy: .public) stars=\(replay.starsUsed) lives=\(actual.result.livesRemaining)")
        print("Verified exact genetic replay: \(replay.starsUsed) stars, \(actual.result.outcome), \(actual.result.livesRemaining) lives, \(actual.wavesStarted) waves, \(actual.reinforcementDeployments.count) reinforcement deployments")
    }

    func run(levelName: String, options requested: GeneticStudyOptions) throws {
        guard let id = try db.levelInfoDao.getIdBy(levelName: levelName) else {
            throw DbError.Db(message: "Unknown authored level '\(levelName)'")
        }
        try run(levelID: id, options: requested)
    }

    func run(levelID: UUID, options requested: GeneticStudyOptions) throws {
        SimulatorLog.ga.notice("Preparing GA; levelID=\(levelID.uuidString, privacy: .public) build=\(BuildVersion.version, privacy: .public)")
        var options = requested
        let study = try load(levelID, bountyFraction: options.bountyFraction,
            selectedHeroIDs: options.selectedHeroIDs, heroAIEnabled: options.heroAIEnabled)
        let money = options.money ?? study.level.startingMoney
        options.money = money
        let heroLoadout = try GeneticHeroLoadout(content: study.battle)
        let heroNames = study.battle.chosenHeroes.heroes.map(\.shortName).joined(separator: ", ")
        let meta = try GeneticMetaSearch(player: study.battle.playerUpgrades)
        let metaFactory = meta.factory
        let exchangeStars = try options.metaExchangeFrom?.playerState(in: study.battle).loadout.spentStars
        let requestedStars = try exchangeStars.map { stars in
            let requested = options.starMinimum == nil && options.starMaximum == nil ? [stars] : try options.starValues(earned: meta.earnedStars)
            guard requested == [stars], !options.fixedMeta, options.seedStrategies.isEmpty else {
                throw DbError.Db(message: "meta exchange study requires its source candidate's exact stars used, without fixed-meta or additional seeds")
            }
            try options.metaExchangeFrom!.validate(study: study)
            guard options.earlyWaveCalls || options.metaExchangeFrom!.earlyWaves.decisions.allSatisfy({ $0.policy == .automatic }) else {
                throw DbError.Db(message: "early-wave calls are disabled but the meta-exchange source calls early")
            }
            return requested
        } ?? options.starValues(earned: meta.earnedStars)
        let active = study.battle.playerUpgrades.loadout
        if options.fixedMeta && requestedStars != [active.spentStars] {
            throw DbError.Db(message: "fixed meta requires exactly the database's \(active.spentStars)-star spending group")
        }
        let choicesByStars = options.fixedMeta
            ? [active.spentStars: [try metaFactory.make(selected: active.selected)]] : meta.choicesByStars
        let starGroups = requestedStars.filter { choicesByStars[$0] != nil }
        try options.validate(groups: starGroups.count)
        SimulatorLog.ga.info("GA settings validated; levelID=\(levelID.uuidString, privacy: .public) money=\(money) earnedStars=\(meta.earnedStars) starGroups=\(starGroups.count) population=\(options.population) metaSelections=\(options.metaSelections) trainingSeeds=\(options.trainingSeeds) validationSeeds=\(options.validationSeeds) fixedMeta=\(options.fixedMeta)")
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
        let content = try study.replaySnapshot(db: db, heroesEnabled: true)
        let digest = hash(content), executable = try executableHash()
        let solutionContext = try GeneticSolutionContext(study: study, db: db, startingMoney: money,
            bountyFraction: options.bountyFraction, maxGameSeconds: options.maxGameSeconds)
        let output = reports.root
        try reports.write(content, to: output.appendingPathComponent("content.json"))
        let trainingSeeds = (0..<options.trainingSeeds).map { options.seed &+ UInt64($0) }
        let validationSeeds = (0..<options.validationSeeds).map { options.seed &+ 1_000_000 &+ UInt64($0) }
        let configuration: [String: Any] = [
            "algorithm": "genetic-v8", "options": try JSONSerialization.jsonObject(with: encoder.encode(options)),
            "bountyFraction": options.bountyFraction, "fixedMeta": options.fixedMeta,
            "engine": "shared-game-engine", "level": study.level.name, "contentSHA256": digest,
            "executableSHA256": executable, "buildVersion": BuildVersion.version,
            "heroes": true, "heroLoadout": try JSONSerialization.jsonObject(with: encoder.encode(heroLoadout)),
            "reinforcementCommands": true, "earlyWaveCalls": options.earlyWaveCalls,
            "difficulty": study.difficulty.name, "earnedStars": meta.earnedStars,
            "requestedStarsUsed": requestedStars, "reachableStarsUsed": starGroups,
            "databaseSelectedUpgrades": study.battle.playerUpgrades.loadout.selected.map(\.rawValue).sorted(),
            "trainingSeeds": trainingSeeds, "validationSeeds": validationSeeds,
            "fitnessOrder": ["complete-level win rate", "victory lives", "waves reached", "survival on defeats"],
            "sampling": options.fixedMeta ? "Fixed-meta control: adapt and compare battle plans with the one database-selected upgrade selection. Full battles and separate held-out validation." : "Equal-sized subpopulations per meta selection within each stars-used population. Paired initial plan families and training seeds; protected adaptation; one finalist per qualified selection. Full battles, no early-wave pruning.",
            "controlledMetaExchange": options.metaExchangeFrom != nil,
            "searchTimeFraction": 0.85, "placementPlanMeaning": "globally unique population candidate ID",
            "upgradePolicyMeaning": ["0": "training panel", "1": "held-out panel"],
            "decisionScope": "meta upgrade selection; builds, upgrade branches, ability purchases, order, earliest wave/time, saving; reinforcement target priority and deliberate hold; per-wave early-call delay, visible countdown and enemy-count preference; default rally/obstacle sites and nearest ready demolition site"]
        let configData = try JSONSerialization.data(withJSONObject: configuration, options: [.sortedKeys, .prettyPrinted])
        try reports.write(configData, to: output.appendingPathComponent("configuration.json"))
        let dao = try MoneyStudyDAO(db: db)
        let start = ProcessInfo.processInfo.systemUptime
        let deadline = start + options.hours * 3600, searchDeadline = start + options.hours * 3600 * 0.85
        var completed = 0, cacheHits = 0, nextID = 0, completedGenerations = 0
        var cache: [String: GeneticCandidate] = [:]
        var best: [Int: GeneticCandidate] = [:]
        var populations: [Int: GeneticMetaPopulation] = [:]
        var rng = SeededRNG(seed: options.seed).fork(stream: 91)
        for stars in starGroups {
            let choices = choicesByStars[stars]!
            let count = min(options.metaSelections, options.population / options.minimumMetaCandidates, choices.count)
            var selected: [MetaUpgradeProgression] = []
            if let source = options.metaExchangeFrom {
                guard count >= 2 else {
                    throw DbError.Db(message: "meta exchange study needs room for at least two legal selections at the source candidate's stars used")
                }
                selected = [source.metaProgression]
                var remaining = choices.filter { $0 != source.metaProgression }
                while selected.count < count, !remaining.isEmpty {
                    let neighbors = GeneticMetaSearch.nearestSelections(to: source.metaProgression, among: remaining)
                    let next = neighbors[Int.random(in: neighbors.indices, using: &rng)]
                    selected.append(next); remaining.removeAll { $0 == next }
                }
                guard options.finalists >= selected.count else {
                    throw DbError.Db(message: "meta exchange study needs at least \(selected.count) finalists to validate every selection")
                }
            } else {
                for strategy in options.seedStrategies where try strategy.playerState(in: study.battle).loadout.spentStars == stars {
                    if !selected.contains(strategy.metaProgression) { selected.append(strategy.metaProgression) }
                }
                guard selected.count <= count else { throw DbError.Db(message: "Seed selections exceed available meta subpopulations") }
                if selected.count < count, active.spentStars == stars {
                    let current = try metaFactory.make(selected: active.selected)
                    if !selected.contains(current) { selected.append(current) }
                }
                while selected.count < count {
                    selected.append(try metaFactory.make(stars: stars, excluding: Set(selected), using: &rng))
                }
            }
            populations[stars] = try GeneticMetaPopulation(selections: selected, population: options.population,
                                                          minimumCandidates: options.minimumMetaCandidates)
        }
        let targetFinalistCounts = Dictionary(uniqueKeysWithValues: starGroups.map { stars in
            (stars, options.fixedMeta ? options.finalists : (options.metaExchangeFrom == nil
                ? min(options.finalists, choicesByStars[stars]!.count) : populations[stars]!.selections.count))
        })
        let validationReservation = targetFinalistCounts.values.reduce(0, +) * options.validationSeeds
        let trainingCap = options.maxEvaluations - validationReservation
        var lastLog = start
        let runID = try db.simulatorRunDao.begin(levelName: study.level.name,
            focus: "genetic meta selections; \(money) coins; \(requestedStars.count) stars-used groups", totalIterations: options.maxEvaluations, outputPath: db.path)

        func ranked(_ candidates: [GeneticCandidate]) -> [GeneticCandidate] {
            GeneticCandidate.ranked(candidates)
        }
        // Scope caches to this immutable DAO snapshot. Set identity avoids
        // sorting/joining strings or rebuilding the same legal loadout per seed.
        var selectedStudies: [MetaUpgradeProgression: AuthoredMoneyStudy] = [try metaFactory.make(selected: active.selected): study]
        func selectedStudy(_ selection: MetaUpgradeProgression) throws -> AuthoredMoneyStudy {
            let key = selection
            if let cached = selectedStudies[key] { return cached }
            let selected = try study.selectingMetaUpgrades(key.selected)
            selectedStudies[key] = selected
            return selected
        }
        func initialStrategy(selection: MetaUpgradeProgression, index: Int, transferred: GeneticStrategy? = nil) throws -> GeneticStrategy {
            if let source = options.metaExchangeFrom, index == 0 { return try source.selectingMetaUpgrades(selection, in: study) }
            if let transferred, index == 0 { return try transferred.selectingMetaUpgrades(selection, in: study) }
            let seeds = options.seedStrategies.filter { $0.metaProgression == selection }
            if index < seeds.count { return seeds[index] }
            // Every selection starts with the same plan-family indices and input
            // policy random stream. Placement heuristics read its actual effects.
            let selected = try selectedStudy(selection)
            let plan = try MoneyStudyPlan(study: selected,
                placementIndex: index == 0 ? 7 : index - 1,
                upgradePolicyIndex: index == 0 ? 2 : (index - 1) % 10, seed: options.seed)
            var policyRNG = SeededRNG(seed: options.seed &+ UInt64(index)).fork(stream: 92)
            var strategy = GeneticStrategy(plan: plan, metaProgression: selection,
                reinforcements: index == 0 ? .immediate : .random(paths: study.level.paths, rng: &policyRNG),
                earlyWaves: options.earlyWaveCalls && index > 0
                    ? .random(waveCount: study.level.numWaves, rng: &policyRNG) : .automatic)
            if index > 0 && index % 3 == 0 {
                for i in strategy.decisions.indices { strategy.decisions[i].saveForPurchase = true }
            }
            return strategy
        }
        var pool: GeneticWorkerPool?
        defer { pool?.close() }
        struct PendingCandidate {
            let key: String
            let strategy: GeneticStrategy
            let generation: Int
        }
        var pending: [PendingCandidate] = []
        var pendingKeys: Set<String> = []
        func evaluateJobs(_ jobs: [GeneticBattleJob]) throws -> [GeneticEvaluation] {
            if let pool { return try pool.evaluate(jobs) }
            return try jobs.map { job in
                try GeneticCommander.evaluate(job.strategy, recording: .database(db.levelRunDao, .simulator),
                    content: selectedStudy(job.strategy.metaProgression).battle,
                    money: money, seed: job.seed, maxSeconds: options.maxGameSeconds)
            }
        }
        func save(_ item: PendingCandidate, evaluations: [GeneticEvaluation]) throws {
            let key = item.key, strategy = item.strategy, generation = item.generation
            let stars = strategy.metaProgression.spentStars
            let candidate = GeneticCandidate(id: nextID, generation: generation, strategy: strategy, evaluations: evaluations)
            nextID += 1; completed += evaluations.count
            try dao.insert([MoneyStudyResultRow(money: money, placementPlan: candidate.id,
                upgradePolicy: 0, results: evaluations.map(\.result), evidenceJSON: try encoded(candidate))], runID: runID, completed: completed,
                rate: Double(completed) / max(0.001, ProcessInfo.processInfo.systemUptime - start))
            cache[key] = candidate
            try populations[stars]!.record(candidate)
            SimulatorLog.ga.debug("Candidate recorded; runID=\(runID.uuidString, privacy: .public) candidate=\(candidate.id) generation=\(generation) stars=\(stars) games=\(evaluations.count) winRate=\(candidate.fitness.winRate)")
            if best[stars] == nil || candidate.fitness > best[stars]!.fitness {
                best[stars] = candidate
                let replay = GeneticReplayDocument(format: "genetic-replay-v6", contentSHA256: digest,
                    executableSHA256: executable, money: money, maxGameSeconds: options.maxGameSeconds,
                    starsUsed: stars, bountyFraction: options.bountyFraction, heroLoadout: heroLoadout, strategy: strategy,
                    expected: evaluations.first(where: { $0.result.outcome == .victory }) ?? evaluations[0])
                try write(replay, to: output.appendingPathComponent("best-stars-\(stars).json"))
                SimulatorLog.ga.notice("New best candidate; runID=\(runID.uuidString, privacy: .public) candidate=\(candidate.id) generation=\(generation) stars=\(stars) winRate=\(candidate.fitness.winRate) meanVictoryLives=\(candidate.fitness.meanVictoryLives)")
                print("New best at \(stars) stars used: population candidate \(candidate.id), generation \(generation), wins \(evaluations.filter { $0.result.outcome == .victory }.count)/\(evaluations.count), mean victory lives \(candidate.fitness.meanVictoryLives)")
                fflush(stdout)
            }
            let now = ProcessInfo.processInfo.systemUptime
            if now - lastLog >= 15 {
                SimulatorLog.ga.notice("Training progress; runID=\(runID.uuidString, privacy: .public) games=\(completed) candidates=\(nextID) evaluatedStarGroups=\(best.count) totalStarGroups=\(starGroups.count) elapsedSeconds=\(now - start)")
                print("Genetic progress: \(completed) engine games, \(nextID) population candidates, \(best.count)/\(starGroups.count) stars-used groups evaluated")
                fflush(stdout); lastLog = now
            }
        }
        func flushCandidates() throws {
            guard !pending.isEmpty else { return }
            let jobs = pending.flatMap { item in trainingSeeds.map { GeneticBattleJob(strategy: item.strategy, seed: $0) } }
            let evaluations = try evaluateJobs(jobs)
            for (index, item) in pending.enumerated() {
                let start = index * trainingSeeds.count
                try save(item, evaluations: Array(evaluations[start..<(start + trainingSeeds.count)]))
            }
            pending.removeAll(keepingCapacity: true); pendingKeys.removeAll(keepingCapacity: true)
        }
        func evaluate(_ strategy: GeneticStrategy, generation: Int) throws -> Bool {
            let selected = try selectedStudy(strategy.metaProgression)
            try strategy.validate(study: selected)
            let key = hash(try encoder.encode(strategy))
            if cache[key] != nil || pendingKeys.contains(key) { cacheHits += 1; return true }
            guard completed + (pending.count + 1) * trainingSeeds.count <= trainingCap,
                  ProcessInfo.processInfo.systemUptime < searchDeadline else { return false }
            pending.append(PendingCandidate(key: key, strategy: strategy, generation: generation))
            pendingKeys.insert(key)
            // At most one candidate per worker is buffered. Parent pools were
            // frozen before breeding; completion order never changes RNG draws.
            if pending.count >= options.workers { try flushCandidates() }
            return true
        }
        func brief(_ candidate: GeneticCandidate) throws -> [String: Any] {
            let evaluations = candidate.evaluations
            var towers: [String: Int] = [:]
            for decision in candidate.strategy.decisions {
                if case let .build(_, id) = decision.step.action,
                   let path = study.towerPaths.first(where: { $0.type.id == id }) {
                    towers[path.type.name, default: 0] += 1
                }
            }
            return ["id": candidate.id, "generation": candidate.generation, "starsUsed": candidate.starsUsed,
                "selectedMetaUpgrades": candidate.metaUpgrades.upgrades.map { id -> [String: Any] in
                    let definition = study.battle.playerUpgrades.loadout.catalog[id]
                    return ["id": id.rawValue, "name": definition.title, "stars": definition.cost]
                }, "plannedActions": candidate.strategy.decisions.count, "plannedTowerMix": towers,
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

        var phase = "initial-population"
        do {
            try dao.begin(runID: runID, configuration: String(decoding: configData, as: UTF8.self),
                contentSHA256: digest, plans: "{\"format\":\"genetic-v8\",\"storage\":\"Fixed hero loadout in configuration; separate meta-selection subpopulations; starsUsed, complete player DNA, engine receipts and seeds in each result row\"}")
            try write(["runID": runID.uuidString], to: output.appendingPathComponent("run.json"))
            SimulatorLog.ga.notice("GA started; runID=\(runID.uuidString, privacy: .public) levelID=\(levelID.uuidString, privacy: .public) level=\(study.level.name, privacy: .public) money=\(money) workers=\(options.workers) hours=\(options.hours) maxEvaluations=\(options.maxEvaluations)")
            print("Started genetic study \(runID): \(study.level.name), \(money) coins, heroes \(heroNames), \(meta.earnedStars) stars earned")
            print("Stars used: \(requestedStars); population cap \(options.population) per group; up to \(options.finalists) finalists; distinct meta selections: \(!options.fixedMeta)")
            print("Bounty fraction: \(options.bountyFraction); fixed database meta selection: \(options.fixedMeta)")
            fflush(stdout)
            if options.workers > 1 {
                pool = try GeneticWorkerPool(count: options.workers,
                    configuration: GeneticWorkerConfiguration(runID: runID, levelID: levelID, contentSHA256: digest,
                        executableSHA256: executable, bountyFraction: options.bountyFraction,
                        money: money, maxSeconds: options.maxGameSeconds, heroLoadout: heroLoadout), db: db)
            }
            initial: for index in 0..<options.population {
                for stars in starGroups {
                    let group = populations[stars]!
                    guard index < group.plansPerSelection else { continue }
                    for selection in group.activeSelections {
                        let strategy = try initialStrategy(selection: selection.upgrades, index: index)
                        guard try evaluate(strategy, generation: 0) else { break initial }
                    }
                }
            }
            try flushCandidates()
            if nextID > 0 { completedGenerations = 1 }
            SimulatorLog.ga.notice("Initial population evaluated; runID=\(runID.uuidString, privacy: .public) candidates=\(nextID) games=\(completed)")
            phase = "evolution"
            if options.generations > 1 {
                for generation in 1..<options.generations {
                    guard nextID > 0, completed + trainingSeeds.count <= trainingCap,
                          ProcessInfo.processInfo.systemUptime < searchDeadline else { break }
                    var transferred: [String: GeneticStrategy] = [:]
                    if !options.fixedMeta && options.metaExchangeFrom == nil {
                        for stars in starGroups {
                            let group = populations[stars]!
                            guard let weakest = group.weakestReplaceable(generation: generation, adaptationGenerations: options.metaAdaptationGenerations),
                                  let champion = group.best else { continue }
                            let unseen = choicesByStars[stars]!.filter { !group.visitedKeys.contains(GeneticMetaSearch.key($0)) }
                            guard !unseen.isEmpty else { continue }
                            let visited = Set(group.selections.map(\.upgrades))
                            let alternatives = group.activeSelections.compactMap { $0.archive.first }
                            let mate = alternatives[Int.random(in: alternatives.indices, using: &rng)]
                            let crossed = try metaFactory.crossover(champion.metaUpgrades, mate.metaUpgrades, using: &rng)
                            let selection: MetaUpgradeProgression
                            if !visited.contains(crossed) { selection = crossed }
                            else if generation % 4 == 0 {
                                selection = try metaFactory.make(stars: stars, excluding: visited, using: &rng)
                            } else {
                                selection = try metaFactory.mutate(champion.metaUpgrades, excluding: visited, using: &rng)
                            }
                            try populations[stars]!.replace(weakest.key, with: selection, generation: generation,
                                                             adaptationGenerations: options.metaAdaptationGenerations)
                            SimulatorLog.ga.debug("Introduced meta selection; runID=\(runID.uuidString, privacy: .public) generation=\(generation) stars=\(stars) upgrades=\(selection.selected.count)")
                            transferred[GeneticMetaSearch.key(selection)] = champion.strategy
                        }
                    }
                    // Freeze parent pools before breeding. Children stay in the
                    // same meta selection; its battle plan gets time to adapt.
                    let parentsByStars = populations.mapValues { group in
                        Dictionary(uniqueKeysWithValues: group.activeSelections.map { ($0.key, $0.archive) })
                    }
                    let before = completed
                    breeding: for index in 0..<options.population {
                        for stars in starGroups {
                            let group = populations[stars]!, capacity = group.plansPerSelection
                            for selection in group.activeSelections {
                                let parents = parentsByStars[stars]![selection.key]!
                                let introductions = parents.isEmpty
                                guard index < (introductions ? capacity : capacity - max(1, capacity / 4)) else { continue }
                                var child: GeneticStrategy
                                if introductions {
                                    child = try initialStrategy(selection: selection.upgrades, index: index, transferred: transferred[selection.key])
                                } else {
                                    func parent() -> GeneticStrategy {
                                        let samples = (0..<3).map { _ in parents[Int.random(in: parents.indices, using: &rng)] }
                                        return ranked(samples)[0].strategy
                                    }
                                    child = Bool.random(using: &rng)
                                        ? try GeneticStrategy.crossover(parent(), parent(), slots: study.level.towerSlots.count, metaFactory: metaFactory, rng: &rng) : parent()
                                    for _ in 0..<Int.random(in: 1...4, using: &rng) {
                                        try child.mutate(study: study, metaFactory: metaFactory, rng: &rng,
                                                     earlyWaveCallsEnabled: options.earlyWaveCalls, metaMutationEnabled: false)
                                    }
                                }
                                guard try evaluate(child, generation: generation) else { break breeding }
                            }
                        }
                    }
                    try flushCandidates()
                    completedGenerations = generation + 1
                    let checkpoint = Dictionary(uniqueKeysWithValues: populations.map { stars, group in
                        (String(stars), Dictionary(uniqueKeysWithValues: group.activeSelections.map { ($0.key, $0.archive.map(\.id)) }))
                    })
                    try dao.recordAdaptiveCheckpoint(runID: runID, json: encoded(checkpoint))
                    try write(populations.values.flatMap { $0.activeSelections.flatMap(\.archive) }.sorted { $0.id < $1.id }, to: output.appendingPathComponent("population.json"))
                    SimulatorLog.ga.info("Generation checkpoint saved; runID=\(runID.uuidString, privacy: .public) generation=\(generation) candidates=\(nextID) games=\(completed) cacheHits=\(cacheHits)")
                    if completed == before { break }
                }
            }
            try write(populations.values.flatMap { $0.activeSelections.flatMap(\.archive) }.sorted { $0.id < $1.id }, to: output.appendingPathComponent("population.json"))
            let searchStopReason: String
            if ProcessInfo.processInfo.systemUptime >= searchDeadline { searchStopReason = "time-budget" }
            else if completed + trainingSeeds.count > trainingCap { searchStopReason = "evaluation-budget" }
            else if completedGenerations >= options.generations { searchStopReason = "generation-limit" }
            else { searchStopReason = "no-new-candidates" }
            SimulatorLog.ga.notice("Training ended; runID=\(runID.uuidString, privacy: .public) reason=\(searchStopReason, privacy: .public) generations=\(completedGenerations) games=\(completed) candidates=\(nextID)")
            phase = "training-publication"
            // Freeze every group's finalists before any held-out result is seen.
            let finalists = starGroups.flatMap { populations[$0]!.finalists(limit: options.finalists, distinctSelections: !options.fixedMeta) }
            let trainingSolutions = try db.geneticSolutionDao.saveBest(
                populations.values.flatMap { $0.selections.flatMap(\.archive) }, runID: runID,
                context: solutionContext, executableSHA256: executable, panel: .training,
                expectedSamples: options.trainingSeeds, limitPerStar: options.finalists, study: study)
            SimulatorLog.ga.notice("Training candidates saved; runID=\(runID.uuidString, privacy: .public) candidates=\(trainingSolutions)")
            phase = "validation"
            SimulatorLog.ga.notice("Validation started; runID=\(runID.uuidString, privacy: .public) finalists=\(finalists.count) seedsPerFinalist=\(options.validationSeeds)")
            var samplesByID: [Int: [GeneticEvaluation]] = [:]
            func validationCheckpoint() throws -> [GeneticCandidate] {
                let checkpoint = finalists.compactMap { candidate -> GeneticCandidate? in
                    guard let samples = samplesByID[candidate.id], !samples.isEmpty else { return nil }
                    return GeneticCandidate(id: candidate.id, generation: candidate.generation,
                        strategy: candidate.strategy, evaluations: samples)
                }
                let rows = try checkpoint.map { candidate in
                    MoneyStudyResultRow(money: money, placementPlan: candidate.id, upgradePolicy: 1,
                        results: candidate.evaluations.map(\.result), evidenceJSON: try encoded(candidate))
                }
                try dao.insert(rows, runID: runID, completed: completed,
                    rate: Double(completed) / max(0.001, ProcessInfo.processInfo.systemUptime - start), replacingValidation: true)
                try write(checkpoint, to: output.appendingPathComponent("validation.json"))
                return checkpoint
            }
            // Round-robin validation gives every star group the same seed panel,
            // including partial panels when the global wall-time budget expires.
            validation: for seed in validationSeeds {
                for start in stride(from: 0, to: finalists.count, by: options.workers) {
                    guard completed < options.maxEvaluations, ProcessInfo.processInfo.systemUptime < deadline else { break validation }
                    let end = min(finalists.count, start + options.workers, start + options.maxEvaluations - completed)
                    let batch = Array(finalists[start..<end])
                    let samples = try evaluateJobs(batch.map { GeneticBattleJob(strategy: $0.strategy, seed: seed) })
                    for (candidate, sample) in zip(batch, samples) {
                        samplesByID[candidate.id, default: []].append(sample); completed += 1
                    }
                }
                _ = try validationCheckpoint()
                SimulatorLog.ga.info("Validation checkpoint saved; runID=\(runID.uuidString, privacy: .public) totalGames=\(completed) minimumSeedsPerFinalist=\(samplesByID.values.map(\.count).min() ?? 0) requestedSeeds=\(options.validationSeeds)")
                print("Validation progress: \(completed) total battles; \(samplesByID.values.map(\.count).min() ?? 0)/\(options.validationSeeds) held-out seeds per finalist")
                fflush(stdout)
            }
            let validations = try validationCheckpoint()
            phase = "validation-publication"
            let validatedSolutions = try db.geneticSolutionDao.saveBest(validations, runID: runID,
                context: solutionContext, executableSHA256: executable, panel: .validation,
                expectedSamples: options.validationSeeds, limitPerStar: options.finalists, study: study)
            SimulatorLog.ga.notice("Validation candidates saved; runID=\(runID.uuidString, privacy: .public) candidates=\(validatedSolutions)")
            print("Published \(trainingSolutions) training and \(validatedSolutions) validation candidates to genetic_solution in \(db.path)")
            for candidate in validations {
                print("Held-out \(candidate.starsUsed) stars used, population candidate \(candidate.id): \(candidate.evaluations.filter { $0.result.outcome == .victory }.count)/\(candidate.evaluations.count) wins")
            }
            let persisted = try dao.geneticSummaryByStars(runID: runID)
            let starResults: [[String: Any]] = try requestedStars.map { stars in
                let tested = validations.filter { $0.starsUsed == stars }
                let reachable = meta.choicesByStars[stars] != nil
                let expected = targetFinalistCounts[stars] ?? 0
                let complete = reachable && expected > 0 && tested.count == expected && tested.allSatisfy { $0.evaluations.count == options.validationSeeds }
                let selections: [[String: Any]] = try (populations[stars]?.selections ?? []).map { selection in
                    let heldOut = tested.first { $0.strategy.metaProgression == selection.upgrades }
                    return ["metaUpgrades": selection.upgrades.upgrades.map(\.rawValue),
                        "selectedMetaUpgrades": selection.upgrades.upgrades.map { study.battle.playerUpgrades.loadout.catalog[$0].title },
                        "activeAtEnd": selection.active, "introducedGeneration": selection.introducedGeneration,
                        "trainingCandidates": selection.candidateIDs.count,
                        "trainingBattles": selection.candidateIDs.count * options.trainingSeeds,
                        "minimumSearchComplete": selection.candidateIDs.count >= options.minimumMetaCandidates,
                        "bestTraining": try selection.archive.first.map(brief) as Any? ?? NSNull(),
                        "validation": try heldOut.map(brief) as Any? ?? NSNull(),
                        "validationCandidates": try tested.filter { $0.strategy.metaProgression == selection.upgrades }.map(brief)]
                }
                return ["starsUsed": stars, "earnedStars": meta.earnedStars, "unspentStars": meta.earnedStars - stars,
                    "legalMetaLoadouts": meta.choicesByStars[stars]?.count ?? 0,
                    "searchedMetaLoadouts": populations[stars]?.selections.filter { !$0.candidateIDs.isEmpty }.count ?? 0,
                    "plansPerMetaSelection": populations[stars]?.plansPerSelection ?? 0,
                    "metaSelectionResults": selections, "expectedFinalists": expected,
                    "expectedDistinctFinalists": options.fixedMeta ? min(1, expected) : expected,
                    "status": !reachable ? "no_legal_loadout" : (best[stars] == nil ? "not_evaluated" : (complete ? "validation_complete" : "validation_incomplete")),
                    "training": persisted.first { ($0["starsUsed"] as? Int) == stars && ($0["panel"] as? Int) == 0 } ?? [:],
                    "bestTraining": try best[stars].map(brief) as Any? ?? NSNull(),
                    "bestReplay": best[stars].map { _ in "best-stars-\(stars).json" } as Any? ?? NSNull(),
                    "validation": try tested.map(brief), "validationComplete": complete]
            }
            var exchanges: [[String: Any]] = []
            if let source = options.metaExchangeFrom,
               let baseline = validations.first(where: { $0.strategy.metaProgression == source.metaProgression }) {
                let group = populations[baseline.starsUsed]!
                for alternative in validations where alternative.id != baseline.id {
                    let common = Set(baseline.evaluations.map(\.seed)).intersection(alternative.evaluations.map(\.seed))
                    guard !common.isEmpty else { continue }
                    let paired = try GeneticPairedComparison(baseline: baseline.evaluations.filter { common.contains($0.seed) },
                        alternative: alternative.evaluations.filter { common.contains($0.seed) })
                    let original = source.metaProgression.selected, changed = alternative.metaUpgrades.selected
                    func names(_ values: Set<MetaUpgrade>) -> [String] {
                        values.sorted { $0.rawValue < $1.rawValue }.map { study.battle.playerUpgrades.loadout.catalog[$0].title }
                    }
                    let baselineCount = group.selections.first { $0.upgrades == baseline.strategy.metaProgression }!.candidateIDs.count
                    let alternativeCount = group.selections.first { $0.upgrades == alternative.strategy.metaProgression }!.candidateIDs.count
                    exchanges.append(["starsUsed": baseline.starsUsed, "baselinePopulationCandidateID": baseline.id,
                        "alternativePopulationCandidateID": alternative.id, "removedUpgrades": names(original.subtracting(changed)),
                        "addedUpgrades": names(changed.subtracting(original)), "baselineTrainingCandidates": baselineCount,
                        "alternativeTrainingCandidates": alternativeCount, "equalTrainingCandidateCounts": baselineCount == alternativeCount,
                        "pairedValidation": try JSONSerialization.jsonObject(with: encoder.encode(paired))])
                }
            }
            phase = "summary"
            let validationComplete = !starGroups.isEmpty && starResults.filter { ($0["legalMetaLoadouts"] as? Int ?? 0) > 0 }.allSatisfy { $0["validationComplete"] as? Bool == true }
            let summary: [String: Any] = ["format": "genetic-summary-v7", "runID": runID.uuidString,
                "bountyFraction": options.bountyFraction, "fixedMeta": options.fixedMeta,
                "heroes": true, "heroLoadout": try JSONSerialization.jsonObject(with: encoder.encode(heroLoadout)),
                "reinforcementCommands": true, "earlyWaveCalls": options.earlyWaveCalls,
                "workers": options.workers, "engineGames": completed, "uniqueGenomes": nextID, "cacheHits": cacheHits, "generations": completedGenerations,
                "elapsedSeconds": ProcessInfo.processInfo.systemUptime - start, "contentSHA256": digest,
                "money": money, "earnedStars": meta.earnedStars, "starResults": starResults,
                "controlledMetaExchange": options.metaExchangeFrom != nil, "metaExchangeComparisons": exchanges,
                "validationComplete": validationComplete,
                "note": "Grouped by exact stars used. Each meta selection has its own adapting battle plans. Meta-search finalists represent distinct qualified selections; explicit fixed-meta controls compare battle plans with one selection. Coverage and search effort are reported per selection. Absence of wins is not proof of impossibility. Final validation never feeds back into the search. Planned tower composition is intent, not a receipt of purchases completed in battle."]
            let summaryURL = output.appendingPathComponent("summary.json")
            try reports.write(JSONSerialization.data(withJSONObject: summary, options: [.sortedKeys, .prettyPrinted]), to: summaryURL)
            try dao.finishAdaptive(runID: runID, completed: completed, reportPath: db.path)
            SimulatorLog.ga.notice("GA completed; runID=\(runID.uuidString, privacy: .public) games=\(completed) candidates=\(nextID) generations=\(completedGenerations) validationComplete=\(validationComplete) elapsedSeconds=\(ProcessInfo.processInfo.systemUptime - start)")
            print("Completed genetic study: \(completed) engine games across \(starGroups.count) star groups; summary.json in \(db.path)")
        } catch {
            SimulatorLog.ga.error("GA failed; runID=\(runID.uuidString, privacy: .public) phase=\(phase, privacy: .public) games=\(completed) detail=\(String(describing: error), privacy: .private)")
            db.simulatorRunDao.finish(id: runID, status: .failed, errorMessage: String(describing: error))
            throw error
        }
    }
}
