import Foundation
import CryptoKit
import OSLog

/// Search coordination and recording only. All battle evaluation goes through
/// GeneticCommander -> GameSimulation -> the game's player-facing engine APIs.
@MainActor final class GeneticStudy {
    private let db: Db
    private let reports: SimulatorReports
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; return encoder
    }()
    init(db: Db, reports: SimulatorReports) { self.db = db; self.reports = reports }
    private func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        guard reports.exports else { return }
        try reports.export(encoder.encode(value), to: url)
    }
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
        try db.geneticSolutionDao.requireRecordingStorage()
        var options = requested
        let study = try load(levelID, bountyFraction: options.bountyFraction,
            selectedHeroIDs: options.selectedHeroIDs, heroAIEnabled: options.heroAIEnabled)
        try options.towerLimits.validate(study: study)
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
            guard try options.towerLimits.permits(BalanceComposition(strategy: options.metaExchangeFrom!, study: study).plannedSlotsByKind) else {
                throw DbError.Db(message: "Meta-exchange source violates the requested tower search limits")
            }
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
            guard try options.towerLimits.permits(BalanceComposition(strategy: strategy, study: study).plannedSlotsByKind) else {
                throw DbError.Db(message: "Seed strategy violates the requested tower search limits")
            }
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
        try reports.export(content, to: output.appendingPathComponent("content.json"))
        let trainingSeeds = (0..<options.trainingSeeds).map { options.seed &+ UInt64($0) }
        guard let policy = options.stopping else {
            throw DbError.Db(message: "new genetic studies require an explicit quality stopping policy")
        }
        var validationSeeds = policy.validationSeeds(base: options.seed, trainingCount: options.trainingSeeds,
            count: options.validationSeeds, attempt: 0)
        if reports.exports {
            let configuration: [String: Any] = [
                "algorithm": "genetic-v13", "options": try JSONSerialization.jsonObject(with: encoder.encode(options)),
                "bountyFraction": options.bountyFraction, "fixedMeta": options.fixedMeta,
                "engine": "shared-game-engine", "level": study.level.name, "contentSHA256": digest,
                "executableSHA256": executable, "buildVersion": BuildVersion.version,
                "recordingPolicy": "retained-solutions-after-evaluation",
                "heroes": true, "heroLoadout": try JSONSerialization.jsonObject(with: encoder.encode(heroLoadout)),
                "reinforcementCommands": true, "earlyWaveCalls": options.earlyWaveCalls,
                "difficulty": study.difficulty.name, "earnedStars": meta.earnedStars,
                "requestedStarsUsed": requestedStars, "reachableStarsUsed": starGroups,
                "databaseSelectedUpgrades": study.battle.playerUpgrades.loadout.selected.map(\.rawValue).sorted(),
                "trainingSeeds": trainingSeeds, "validationSeeds": validationSeeds,
                "fitnessOrder": ["complete-level win rate", "victory lives", "waves reached", "survival on defeats"],
                "sampling": options.fixedMeta ? "Fixed-meta control: adapt and compare battle plans with the one database-selected upgrade selection. Full battles and separate held-out validation." : "Equal-sized subpopulations per meta selection within each stars-used population. Independent initial plans and shared training seeds; persistent best-per-behavior archives with allocated offspring; finalists drawn from every evaluated candidate. Controlled meta exchanges retain one finalist per qualified selection. Full battles, no early-wave pruning.",
                "controlledMetaExchange": options.metaExchangeFrom != nil,
                "searchTimeFraction": GeneticProgress.searchTimeFraction, "placementPlanMeaning": "globally unique population candidate ID",
                "upgradePolicyMeaning": ["0": "training panel", "1": "held-out panel"],
                "decisionScope": "meta upgrade selection; builds, upgrade branches, ability purchases, order, earliest wave/time, saving; reinforcement target priority and deliberate hold; per-wave early-call delay, visible countdown and enemy-count preference; evolved rally, obstacle and demolition route targets through shared player commands"]
            let configData = try JSONSerialization.data(withJSONObject: configuration, options: [.sortedKeys, .prettyPrinted])
            try reports.export(configData, to: output.appendingPathComponent("configuration.json"))
        }
        let dao = try GeneticStudyDAO(db: db)
        let start = ProcessInfo.processInfo.systemUptime
        var completed = 0, cacheHits = 0, nextID = 0, completedGenerations = 0
        var cache: [String: GeneticCandidate] = [:]
        var best: [Int: GeneticCandidate] = [:]
        var convergence = GeneticSearchConvergence(policy: policy, stars: starGroups)
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
        var targetFinalistCounts = Dictionary(uniqueKeysWithValues: starGroups.map { stars in
            // Creative finalists can share upgrades, including a zero-star run
            // with only one legal upgrade choice. Reserve their complete panels.
            (stars, options.metaExchangeFrom == nil ? options.finalists : populations[stars]!.selections.count)
        })
        let validationReservation = targetFinalistCounts.values.reduce(0, +) * options.validationSeeds
        let budget = GeneticSearchBudget(options: options, startedAt: start, validationReservation: validationReservation)
        let runID = try db.simulatorRunDao.begin(levelName: study.level.name,
            focus: "genetic meta selections; \(money) coins; \(requestedStars.count) stars-used groups", totalIterations: options.maxEvaluations, outputPath: db.path)
        var progress = GeneticProgress(runID: runID, startedAt: start, timeBudget: options.hours * 3600,
                                       trainingLimit: budget.trainingLimit, generationLimit: budget.generationLimit, qualitySearch: true)
        var validationCompleted = 0, validationTarget = validationReservation
        var lastProgressLog = start
        func reportProgress(phase: GeneticProgress.Phase = .search, force: Bool = false) throws {
            let now = ProcessInfo.processInfo.systemUptime
            let previous = progress.latest
            // Publish the new state only after its checkpoint write succeeds.
            var updated = progress
            let snapshot = updated.update(now: now, phase: phase, completedGenerations: completedGenerations,
                trainingEvaluations: completed - validationCompleted, validationEvaluations: validationCompleted,
                validationTarget: validationTarget)
            let milestones = snapshot.milestones.dropFirst(previous?.milestones.count ?? 0)
            guard force || previous?.phase != phase || !milestones.isEmpty || now - lastProgressLog >= 15 else {
                progress = updated
                return
            }
            try dao.saveProgress(snapshot)
            try dao.saveGoalProgress(runID: runID, convergence: convergence)
            try write(snapshot, to: output.appendingPathComponent("progress.json"))
            progress = updated
            print(snapshot.statusLine)
            if phase == .search { print(convergence.description(generation: completedGenerations)) }
            SimulatorLog.ga.notice("\(snapshot.statusLine, privacy: .public); runID=\(runID.uuidString, privacy: .public)")
            for milestone in milestones {
                let message = "GA milestone: passed \(milestone.percent)% after \(GeneticProgress.duration(milestone.elapsedSeconds))"
                print(message)
                SimulatorLog.ga.notice("\(message, privacy: .public); runID=\(runID.uuidString, privacy: .public)")
            }
            fflush(stdout)
            lastProgressLog = now
        }

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
        func initialStrategy(selection: MetaUpgradeProgression, index: Int, transferred: GeneticStrategy? = nil, fresh: Bool = false) throws -> GeneticStrategy {
            if !fresh, let source = options.metaExchangeFrom, index == 0 { return try source.selectingMetaUpgrades(selection, in: study) }
            if !fresh, let transferred, index == 0 { return try transferred.selectingMetaUpgrades(selection, in: study) }
            let seeds = options.seedStrategies.filter { $0.metaProgression == selection }
            if !fresh, index < seeds.count { return seeds[index] }
            let selected = try selectedStudy(selection)
            // Controlled meta experiments deliberately pair input plans. Normal
            // search consumes an independent stream across births/selections.
            if options.metaExchangeFrom != nil {
                var paired = SeededRNG(seed: options.seed &+ UInt64(index)).fork(stream: 92)
                return try GeneticStrategyFactory.make(study: selected, selection: selection,
                    towerLimits: options.towerLimits, earlyWaveCalls: options.earlyWaveCalls, rng: &paired)
            }
            return try GeneticStrategyFactory.make(study: selected, selection: selection,
                towerLimits: options.towerLimits, earlyWaveCalls: options.earlyWaveCalls, rng: &rng)
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
        // Keep a few battles queued per worker so the ordered transport can
        // refill a fast process while a slower battle is still running. Bound
        // candidates by seed count; serial execution still saves immediately.
        let candidateBatchLimit = options.workers == 1 ? 1
            : max(1, (options.workers * 4 + options.trainingSeeds - 1) / options.trainingSeeds)
        func evaluateJobs(_ jobs: [GeneticBattleJob]) throws -> [GeneticEvaluation] {
            if let pool { return try pool.evaluate(jobs) }
            return try jobs.map { job in
                try GeneticCommander.evaluate(job.strategy, recording: .evaluation,
                    content: selectedStudy(job.strategy.metaProgression).battle,
                    money: money, seed: job.seed, maxSeconds: options.maxGameSeconds)
            }
        }
        func save(_ item: PendingCandidate, evaluations: [GeneticEvaluation]) throws {
            guard evaluations.allSatisfy({ $0.placementPlan?.playstyle != nil }) else {
                throw DbError.Db(message: "genetic study: worker omitted original placement/playstyle evidence")
            }
            guard evaluations.allSatisfy({ $0.placementPlan!.playstyle!.towers.allSatisfy { $0.slowingSeconds != nil } }) else {
                throw DbError.Db(message: "genetic study: worker omitted control activity evidence")
            }
            let key = item.key, strategy = item.strategy, generation = item.generation
            let stars = strategy.metaProgression.spentStars
            let candidate = GeneticCandidate(id: nextID, generation: generation, strategy: strategy, evaluations: evaluations)
            nextID += 1; completed += evaluations.count
            try dao.insert([candidate], runID: runID, panel: .training, expectedSamples: options.trainingSeeds,
                completed: completed, rate: Double(completed) / max(0.001, ProcessInfo.processInfo.systemUptime - start))
            cache[key] = candidate
            try populations[stars]!.record(candidate)
            convergence.observe(candidate)
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
            try reportProgress()
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
            guard try options.towerLimits.permits(BalanceComposition(strategy: strategy, study: study).plannedSlotsByKind) else {
                return true // Reject this search proposal without executing or altering combat.
            }
            let key = hash(try encoder.encode(strategy))
            if cache[key] != nil || pendingKeys.contains(key) { cacheHits += 1; return true }
            guard budget.trainingStopReason(now: ProcessInfo.processInfo.systemUptime, completed: completed,
                                            pending: pending.count * trainingSeeds.count) == nil else { return false }
            pending.append(PendingCandidate(key: key, strategy: strategy, generation: generation))
            pendingKeys.insert(key)
            // Parent pools were frozen before breeding; ordered saves preserve
            // candidate IDs and RNG draws regardless of worker completion order.
            if pending.count >= candidateBatchLimit { try flushCandidates() }
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
                "winsMeetingTowerLimits": evaluations.filter {
                    $0.result.outcome == .victory && $0.builtTowersByKind.map(options.towerLimits.permits) == true
                }.count,
                "builtTowersBySeed": Dictionary(uniqueKeysWithValues: evaluations.compactMap { value in
                    value.builtTowersByKind.map { (String(value.seed), $0) }
                }),
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
            try dao.begin(runID: runID, context: solutionContext, executableSHA256: executable,
                snapshotSHA256: digest, buildVersion: BuildVersion.version, options: options,
                requestedStars: requestedStars, reachableStars: starGroups, earnedStars: meta.earnedStars,
                databaseUpgrades: active.selected.sorted { $0.rawValue < $1.rawValue },
                trainingSeeds: trainingSeeds, validationSeeds: validationSeeds)
            try write(["runID": runID.uuidString], to: output.appendingPathComponent("run.json"))
            SimulatorLog.ga.notice("GA started; runID=\(runID.uuidString, privacy: .public) levelID=\(levelID.uuidString, privacy: .public) level=\(study.level.name, privacy: .public) money=\(money) workers=\(options.workers) hours=\(options.hours) maxEvaluations=\(options.maxEvaluations)")
            print("Started genetic study \(runID): \(study.level.name), \(money) coins, heroes \(heroNames), \(meta.earnedStars) stars earned")
            print("Stars used: \(requestedStars); population cap \(options.population) per group; up to \(options.finalists) finalists; creative finalists with meta-selection coverage")
            print("Bounty fraction: \(options.bountyFraction); fixed database meta selection: \(options.fixedMeta)")
            print("Search limits: \(budget.generationLimit.map(String.init) ?? "unlimited") generations; \(budget.evaluationLimit.map(String.init) ?? "unlimited") total battles; \(options.hours > 0 ? GeneticProgress.duration(options.hours * 3600 * GeneticProgress.searchTimeFraction) : "unlimited") search time. Budget exhaustion does not establish solution quality.")
            fflush(stdout)
            try reportProgress(force: true)
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
            try reportProgress()
            SimulatorLog.ga.notice("Initial population evaluated; runID=\(runID.uuidString, privacy: .public) candidates=\(nextID) games=\(completed)")
            phase = "evolution"
            var recovery = GeneticSearchRecovery()
            recovery.completedGeneration(newEvaluations: completed)
            var generation = completedGenerations
            var attempt = 0
            var qualificationHistory = GeneticQualificationHistory()
            var searchStopReason = ""
            var finalists: [GeneticCandidate] = []
            var validations: [GeneticCandidate] = []
            var validationComplete = false
            func frozenFinalists() -> [GeneticCandidate] {
                starGroups.flatMap { populations[$0]!.finalists(limit: options.finalists,
                    distinctSelections: !options.fixedMeta, controlledMetaExchange: options.metaExchangeFrom != nil) }
            }
            func qualifies(_ candidates: [GeneticCandidate], samples: Int, history: [Int: GeneticCandidate] = [:]) throws -> Bool {
                try starGroups.allSatisfy { stars in
                    try policy.qualifyingSet(candidates.filter { $0.starsUsed == stars }, samples: samples, history: history).count == policy.solutions
                }
            }
            while true {
                phase = "evolution"
                var readyForQualification = false
                while budget.searchStopReason(now: ProcessInfo.processInfo.systemUptime,
                                              generations: generation, completed: completed) == nil {
                    if convergence.ready(generation: generation) {
                        if try qualifies(frozenFinalists(), samples: options.trainingSeeds) {
                            readyForQualification = true
                            break
                        }
                        convergence.restartExploration(generation: generation)
                        recovery.completedGeneration(newEvaluations: 0)
                        print("Stable training results lack the required winning variety; continuing fresh exploration.")
                    }
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
                            // Transfer a local strategy, not always the global champion.
                            let donors = group.selections.flatMap { $0.behaviorChampions.values }
                                .sorted { $0.id < $1.id }
                            transferred[GeneticMetaSearch.key(selection)] = donors.isEmpty ? champion.strategy
                                : donors[Int.random(in: donors.indices, using: &rng)].strategy
                        }
                    }
                    // Freeze parent pools before breeding. Children stay in the
                    // same meta selection; its battle plan gets time to adapt.
                    var parentsByStars: [Int: [String: [GeneticCandidate]]] = [:]
                    var matesByStars: [Int: [String: [GeneticCandidate]]] = [:]
                    for stars in starGroups {
                        let group = populations[stars]!
                        for selection in group.activeSelections {
                            let count = group.plansPerSelection - max(1, group.plansPerSelection / 4)
                            parentsByStars[stars, default: [:]][selection.key] = populations[stars]!.breedingParents(key: selection.key, count: count)
                            let champions = selection.behaviorChampions.values.sorted { $0.id < $1.id }
                            matesByStars[stars, default: [:]][selection.key] = champions.isEmpty ? selection.archive : champions
                        }
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
                                if recovery.needsFreshGeneration {
                                    child = try initialStrategy(selection: selection.upgrades, index: generation + index, fresh: true)
                                } else if introductions {
                                    child = try initialStrategy(selection: selection.upgrades, index: index, transferred: transferred[selection.key])
                                } else {
                                    let offspringCount = capacity - max(1, capacity / 4)
                                    if GeneticBreedingDiversity.introducesFreshPlan(index: index, offspringCount: offspringCount, generation: generation) {
                                        child = try initialStrategy(selection: selection.upgrades, index: generation + index)
                                    } else {
                                        let primary = parents[index % parents.count]
                                        let mates = GeneticBreedingDiversity.matingPool(for: primary, parents: matesByStars[stars]![selection.key]!)
                                        let mate = mates[Int.random(in: mates.indices, using: &rng)]
                                        let opening = Set((primary.placementPlan?.initial ?? []).map(\.slot)
                                            + (mate.placementPlan?.initial ?? []).map(\.slot))
                                        child = Bool.random(using: &rng)
                                            ? try GeneticStrategy.crossover(primary.strategy, mate.strategy,
                                                slots: study.level.towerSlots.count, metaFactory: metaFactory, rng: &rng,
                                                preservingOpening: opening)
                                            : primary.strategy
                                        for _ in 0..<Int.random(in: 1...4, using: &rng) {
                                            try child.mutate(study: study, metaFactory: metaFactory, rng: &rng,
                                                earlyWaveCallsEnabled: options.earlyWaveCalls, metaMutationEnabled: false,
                                                evidence: primary.evaluations)
                                        }
                                    }
                                }
                                guard try evaluate(child, generation: generation) else { break breeding }
                            }
                        }
                    }
                    try flushCandidates()
                    completedGenerations = generation + 1
                    try dao.checkpoint(runID: runID, populations: populations, generations: completedGenerations, nextID: nextID, cacheHits: cacheHits)
                    try write(populations.values.flatMap { $0.activeSelections.flatMap(\.archive) }.sorted { $0.id < $1.id }, to: output.appendingPathComponent("population.json"))
                    SimulatorLog.ga.info("Generation checkpoint saved; runID=\(runID.uuidString, privacy: .public) generation=\(generation) candidates=\(nextID) games=\(completed) cacheHits=\(cacheHits)")
                    try reportProgress()
                    recovery.completedGeneration(newEvaluations: completed - before)
                    if recovery.needsFreshGeneration {
                        SimulatorLog.ga.notice("No new candidates this generation; fresh exploration next; runID=\(runID.uuidString, privacy: .public) generation=\(generation)")
                    }
                    generation += 1
                }
                try dao.checkpoint(runID: runID, populations: populations, generations: completedGenerations, nextID: nextID, cacheHits: cacheHits)
                let resourceReason = budget.searchStopReason(now: ProcessInfo.processInfo.systemUptime,
                    generations: completedGenerations, completed: completed)
                guard readyForQualification || resourceReason != nil else {
                    throw DbError.Db(message: "search ended without quality readiness or an explicit resource limit")
                }
                // Freeze before seeing this attempt's entirely fresh held-out panel.
                finalists = frozenFinalists()
                targetFinalistCounts = Dictionary(uniqueKeysWithValues: starGroups.map { stars in
                    (stars, finalists.filter { $0.starsUsed == stars }.count)
                })
                validationSeeds = policy.validationSeeds(base: options.seed, trainingCount: options.trainingSeeds,
                    count: options.validationSeeds, attempt: attempt)
                let evidenceID = try dao.beginQualification(runID: runID, attempt: attempt,
                    context: solutionContext, executableSHA256: executable,
                    trainingBattles: completed - validationCompleted, generations: completedGenerations, seeds: validationSeeds)
                validationTarget = validationCompleted + finalists.count * options.validationSeeds
                phase = "validation"
                print("Frozen qualification attempt \(attempt + 1): \(finalists.count) candidates, \(options.validationSeeds) fresh held-out seeds each.")
                try reportProgress(phase: .validation)
                var samplesByID: [Int: [GeneticEvaluation]] = [:]
                func validationCheckpoint() throws -> [GeneticCandidate] {
                    let checkpoint = finalists.compactMap { candidate -> GeneticCandidate? in
                        guard let samples = samplesByID[candidate.id], !samples.isEmpty else { return nil }
                        return GeneticCandidate(id: candidate.id, generation: candidate.generation,
                            strategy: candidate.strategy, evaluations: samples)
                    }
                    for candidate in checkpoint {
                        try dao.saveEvidence(candidate, runID: evidenceID, panel: .validation, expectedSamples: options.validationSeeds)
                    }
                    try write(checkpoint, to: output.appendingPathComponent("validation.json"))
                    return checkpoint
                }
                // Round-robin validation gives every star group the same seed panel,
                // including partial panels when the global wall-time budget expires.
                validation: for seed in validationSeeds {
                    for start in stride(from: 0, to: finalists.count, by: options.workers) {
                        guard budget.evaluationLimit.map({ completed < $0 }) ?? true,
                              budget.deadline.map({ ProcessInfo.processInfo.systemUptime < $0 }) ?? true else { break validation }
                        let available = budget.evaluationLimit.map { $0 - completed } ?? options.workers
                        let end = min(finalists.count, start + options.workers, start + available)
                        let batch = Array(finalists[start..<end])
                        let samples = try evaluateJobs(batch.map { GeneticBattleJob(strategy: $0.strategy, seed: seed) })
                        for (candidate, sample) in zip(batch, samples) {
                            samplesByID[candidate.id, default: []].append(sample); completed += 1; validationCompleted += 1
                        }
                        try reportProgress(phase: .validation)
                    }
                    _ = try validationCheckpoint()
                    SimulatorLog.ga.info("Validation checkpoint saved; runID=\(runID.uuidString, privacy: .public) totalGames=\(completed) minimumSeedsPerFinalist=\(samplesByID.values.map(\.count).min() ?? 0) requestedSeeds=\(options.validationSeeds)")
                }
                validations = try validationCheckpoint()
                validationComplete = !starGroups.isEmpty && starGroups.allSatisfy { stars in
                    let tested = validations.filter { $0.starsUsed == stars }
                    let expected = targetFinalistCounts[stars] ?? 0
                    return expected > 0 && tested.count == expected && tested.allSatisfy { $0.evaluations.count == options.validationSeeds }
                }
                try qualificationHistory.append(validations)
                let qualified = try readyForQualification && validationComplete
                    && qualifies(validations, samples: options.validationSeeds, history: qualificationHistory.candidates)
                let exhausted = resourceReason ?? budget.searchStopReason(now: ProcessInfo.processInfo.systemUptime,
                    generations: completedGenerations, completed: completed)
                try dao.finishQualification(evidenceID: evidenceID,
                    status: qualified ? "qualified" : (exhausted == nil ? "rejected" : "resource-limit"))
                if qualified || exhausted != nil {
                    searchStopReason = qualified ? "quality-qualified" : exhausted!
                    try dao.finalValidationSeeds(runID: runID, seeds: validationSeeds)
                    try dao.insert(validations, runID: runID, panel: .validation, expectedSamples: options.validationSeeds,
                        completed: completed, rate: Double(completed) / max(0.001, ProcessInfo.processInfo.systemUptime - start))
                    break
                }
                // No held-out fitness enters the breeding populations. The next
                // frozen assessment uses a disjoint seed panel; this one stays saved.
                attempt += 1
                convergence.restartExploration(generation: generation)
                recovery.completedGeneration(newEvaluations: 0)
                print("Qualification rejected; evidence retained. Resuming training with fresh exploration.")
                try reportProgress(force: true)
            }
            try dao.saveGoalProgress(runID: runID, convergence: convergence)
            try write(populations.values.flatMap { $0.activeSelections.flatMap(\.archive) }.sorted { $0.id < $1.id },
                to: output.appendingPathComponent("population.json"))
            print(searchStopReason == "quality-qualified"
                ? "Quality goal qualified after training convergence and held-out assessment."
                : "Resource limit reached (\(searchStopReason)); quality goal NOT achieved.")
            let trainingSolutions = try db.geneticSolutionDao.saveBest(Array(cache.values), runID: runID,
                context: solutionContext, executableSHA256: executable, panel: .training,
                expectedSamples: options.trainingSeeds, limitPerStar: options.finalists, study: study)
            phase = "validation-publication"
            try reportProgress(phase: .saving)
            let validatedSolutions = try db.geneticSolutionDao.saveBest(validations, runID: runID,
                context: solutionContext, executableSHA256: executable, panel: .validation,
                expectedSamples: options.validationSeeds, limitPerStar: options.finalists, study: study)
            SimulatorLog.ga.notice("Validation candidates saved; runID=\(runID.uuidString, privacy: .public) candidates=\(validatedSolutions)")
            print("Published \(trainingSolutions) training and \(validatedSolutions) validation candidates to genetic_solution in \(db.path)")
            for candidate in validations {
                print("Held-out \(candidate.starsUsed) stars used, population candidate \(candidate.id): \(candidate.evaluations.filter { $0.result.outcome == .victory }.count)/\(candidate.evaluations.count) wins")
            }
            var summary: [String: Any] = [:]
            if reports.exports {
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
                summary = ["format": "genetic-summary-v7", "runID": runID.uuidString,
                    "bountyFraction": options.bountyFraction, "fixedMeta": options.fixedMeta,
                    "heroes": true, "heroLoadout": try JSONSerialization.jsonObject(with: encoder.encode(heroLoadout)),
                    "reinforcementCommands": true, "earlyWaveCalls": options.earlyWaveCalls,
                    "workers": options.workers, "engineGames": completed, "uniqueGenomes": nextID, "cacheHits": cacheHits, "generations": completedGenerations,
                    "elapsedSeconds": ProcessInfo.processInfo.systemUptime - start, "contentSHA256": digest,
                    "money": money, "earnedStars": meta.earnedStars, "starResults": starResults,
                    "controlledMetaExchange": options.metaExchangeFrom != nil, "metaExchangeComparisons": exchanges,
                    "validationComplete": validationComplete,
                    "note": "Grouped by exact stars used. Each meta selection has its own adapting battle plans. Creative finalists reserve coverage of qualified meta selections and may include multiple different battle plans with the same upgrades. Coverage and search effort are reported per selection. Absence of wins is not proof of impossibility. Final validation never feeds back into the search. Planned tower composition is intent, not a receipt of purchases completed in battle."]
            }
            phase = "summary"
            let evaluationSeconds = ProcessInfo.processInfo.systemUptime - start
            try dao.saveSummary(runID: runID, stopReason: searchStopReason, validationComplete: validationComplete,
                evaluationSeconds: evaluationSeconds, recordingSeconds: 0, totalSeconds: evaluationSeconds,
                cacheHits: cacheHits, generations: completedGenerations, candidates: nextID, recordings: 0)
            let summaryURL = output.appendingPathComponent("summary.json")
            if reports.exports { try reports.export(JSONSerialization.data(withJSONObject: summary, options: [.sortedKeys, .prettyPrinted]), to: summaryURL) }
            // The search and held-out panels are now frozen. Demonstrations
            // use their own recordings and cannot consume evaluation budget,
            // change rankings, or replace original candidate evidence.
            pool?.close(); pool = nil
            phase = "recording"
            let recordingStarted = ProcessInfo.processInfo.systemUptime
            let retained = try db.geneticSolutionDao.recordingCandidates(runID: runID)
            try reportProgress(phase: .recording)
            print("Recording \(retained.count) retained solutions after evaluation; original fitness results are unchanged.")
            for (index, solution) in retained.enumerated() {
                let original = try solution.recordingEvaluation()
                let actual = try GeneticCommander.evaluate(solution.candidate.strategy,
                    recording: .database(db.levelRunDao, .simulator),
                    content: selectedStudy(solution.candidate.strategy.metaProgression).battle,
                    money: money, seed: original.seed, maxSeconds: options.maxGameSeconds)
                let matches = try db.geneticSolutionDao.saveRecording(for: solution, evaluation: actual)
                print("Playback \(index + 1)/\(retained.count): candidate \(solution.candidate.id), \(solution.panel.rawValue), seed \(original.seed), \(actual.result.outcome.rawValue); original evaluation \(matches ? "matched" : "differs (fitness unchanged)").")
                try reportProgress(phase: .recording)
            }
            summary["recordingPolicy"] = "retained-solutions-after-evaluation"
            summary["playbackRecordings"] = retained.count
            summary["playbackRecordingSeconds"] = ProcessInfo.processInfo.systemUptime - recordingStarted
            summary["totalElapsedSeconds"] = ProcessInfo.processInfo.systemUptime - start
            if reports.exports { try reports.export(JSONSerialization.data(withJSONObject: summary, options: [.sortedKeys, .prettyPrinted]), to: summaryURL) }
            try dao.saveSummary(runID: runID, stopReason: searchStopReason, validationComplete: validationComplete,
                evaluationSeconds: evaluationSeconds, recordingSeconds: ProcessInfo.processInfo.systemUptime - recordingStarted,
                totalSeconds: ProcessInfo.processInfo.systemUptime - start, cacheHits: cacheHits,
                generations: completedGenerations, candidates: nextID, recordings: retained.count)
            try dao.finish(runID: runID, completed: completed)
            try reportProgress(phase: .completed)
            SimulatorLog.ga.notice("GA completed; runID=\(runID.uuidString, privacy: .public) games=\(completed) candidates=\(nextID) generations=\(completedGenerations) validationComplete=\(validationComplete) elapsedSeconds=\(ProcessInfo.processInfo.systemUptime - start)")
            let starBudgets = starGroups.map(String.init).joined(separator: ", ")
            let budgetDescription = starGroups.count == 1
                ? "a \(starBudgets)-star meta progression budget"
                : "meta progression budgets of \(starBudgets) stars"
            print("Genetic study ended (\(searchStopReason)): \(completed) evaluation games using \(budgetDescription), \(retained.count) playback recordings; relational results in \(db.path)")
        } catch {
            SimulatorLog.ga.error("GA failed; runID=\(runID.uuidString, privacy: .public) phase=\(phase, privacy: .public) games=\(completed) detail=\(String(describing: error), privacy: .private)")
            do { try reportProgress(phase: .failed) }
            catch let progressError {
                SimulatorLog.ga.error("Unable to save failure progress; runID=\(runID.uuidString, privacy: .public) detail=\(String(describing: progressError), privacy: .private)")
            }
            db.simulatorRunDao.finish(id: runID, status: .failed, errorMessage: String(describing: error))
            throw error
        }
    }
}
