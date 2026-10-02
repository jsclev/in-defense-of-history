import Foundation
import CryptoKit

/// Explicit offline publication, separate from time-bounded search. Owns only
/// selection, provenance and recording; every battle uses GeneticCommander.
@MainActor enum GeneticSolutionImport {
    /// Read-only comparison across the complete saved candidate archive.
    /// Training and held-out rankings are never mixed. Qualifying training plans
    /// still need their full held-out panels before publication.
    static func auditDiversity(sourceURL: URL) throws {
        let source = try SimulatorDatabase.open(sourceURL, readOnly: true)
        defer { source.close() }
        let dao = try GeneticStudyDAO(db: source)
        let runID = try dao.runID()
        let selector = GeneticSolutionDiversitySelector()
        for panel in [GeneticSolutionPanel.validation, .training] {
            let ranked = try dao.rankedPlacementCandidates(runID: runID, panel: panel)
            for stars in Set(ranked.map(\.starsUsed)).sorted() {
                let group = ranked.filter { $0.starsUsed == stars }
                let unknown = group.filter { $0.placementPlan == nil }
                guard unknown.isEmpty else {
                    print("\(panel.rawValue): \(group.count) winners; \(unknown.count) lack saved opening/placement data. Diversity is unknown; no ordered selection can be claimed.")
                    continue
                }
                print("Comparing \(group.count) saved \(panel.rawValue) winners at \(stars) stars; candidate data only")
                let selected = try selector.select(ranked: group, plan: { try $0.requirePlacementPlan() })
                for selection in selected {
                    let candidate = selection.item
                    print("Selected candidate \(candidate.id), original fitness rank \(selection.fitnessRank): wins \(candidate.victories)/\(candidate.samples), lives \(candidate.meanVictoryLives)")
                    print("Comparisons against all earlier selections: \(selection.comparisons)")
                }
                print("\(panel.rawValue) greedy diagnostic: \(selected.map { $0.item.id }); pool \(group.count) winners. A shortfall is not proof that no other compatible set exists; publication searches the full validated pool. No battles executed; no data written.")
            }
        }
    }

    private struct Configuration: Decodable {
        let algorithm: String
        let level: String
        let contentSHA256: String
        let executableSHA256: String
        let heroLoadout: GeneticHeroLoadout
        let trainingSeeds: [UInt64]
        let validationSeeds: [UInt64]
        let options: GeneticStudyOptions
    }

    /// Scan the held-out ranking for three diverse winners, then record only
    /// their demonstrations. Original held-out fitness remains authoritative.
    static func ship(sourceURL: URL, contentURL: URL, destination: URL, seedURL: URL, recordingsURL: URL) throws {
        let paths = [sourceURL, contentURL, destination, seedURL, recordingsURL]
            .map { $0.standardizedFileURL.resolvingSymlinksInPath().path }
        guard Set(paths).count == paths.count, seedURL.pathExtension == "sql",
              !FileManager.default.fileExists(atPath: recordingsURL.path) else {
            throw DbError.Db(message: "genetic publication: source, content and outputs must be separate paths")
        }
        let source = try SimulatorDatabase.open(sourceURL, readOnly: true)
        defer { source.close() }
        let sourceRun = try GeneticStudyDAO(db: source).runID()
        let ranked = try source.geneticSolutionDao.validatedCandidates(runID: sourceRun, limit: Int.max)
            .filter { $0.candidate.fitness.winRate >= 0.9
                && $0.candidate.placementPlan?.playstyle?.towers.allSatisfy({ $0.slowingSeconds != nil }) == true }
        guard let first = ranked.first,
              ranked.allSatisfy({ $0.context == first.context && $0.heroesEnabled && $0.context.bountyFraction == 1
                && $0.expectedSamples == first.expectedSamples && $0.executableSHA256 == first.executableSHA256 }) else {
            throw DbError.Db(message: "genetic publication: requires complete validated winners for the same authored battle")
        }
        let selector = GeneticSolutionDiversitySelector()
        let selections = try selector.selectCompleteSet(ranked: ranked, plan: { try $0.candidate.requirePlacementPlan() },
            pairEligible: { try selector.consistentlyDifferent($0.candidate, $1.candidate) })
        for selection in selections {
            print("Selected candidate \(selection.item.candidate.id), original fitness rank \(selection.fitnessRank); comparisons against all earlier selections: \(selection.comparisons)")
        }
        guard selections.count == 3 else {
            throw DbError.Db(message: "genetic publication: only \(selections.count) of \(ranked.count) reliable validated winners satisfy meaningful playstyle diversity against every selected plan; no seed or recordings were published")
        }
        let selected = selections.map(\.item)
        let authored = Db(dbPath: contentURL.path, fullRefresh: false,
            levelGeoJSONDao: LevelGeoJSONDAO(directory: contentURL.deletingLastPathComponent()), readOnly: true)
        defer { authored.close() }
        guard let heroes = first.context.heroLoadout else { throw DbError.Db(message: "genetic publication: missing heroes") }
        let copy = try BountyExperimentDAO.contentCopy(of: authored, fraction: 1,
            selectedHeroIDs: heroes.selectedHeroIDs,
            heroAI: Dictionary(uniqueKeysWithValues: heroes.deployments.map { ($0.heroID, $0.aiEnabled) }))
        defer { copy.close() }
        try copy.difficultyDao.setSelected(difficultyID: first.context.difficultyID)
        let study = try AuthoredMoneyStudy(db: copy, levelID: first.context.levelID)
        let context = try GeneticSolutionContext(study: study, db: copy,
            startingMoney: study.level.startingMoney, bountyFraction: 1, maxGameSeconds: first.context.maxGameSeconds)
        guard context == first.context else { throw DbError.Db(message: "genetic publication: current content differs from saved validation") }
        let db = try SimulatorDatabase.create(source: authored, destination: destination, arguments: CommandLine.arguments,
            schema: contentURL.deletingLastPathComponent().appendingPathComponent("DDL/create_simulator_invocation.sql"))
        defer { db.close() }
        try db.geneticSolutionDao.requireRecordingStorage()
        try db.geneticSolutionDao.copyCatalog(from: authored.geneticSolutionDao, excludingLevelID: context.levelID)
        try db.geneticSolutionDao.saveBest(selected.map(\.candidate), runID: sourceRun, context: context,
            executableSHA256: first.executableSHA256, panel: .validation,
            expectedSamples: first.expectedSamples, limitPerStar: 3, study: study)
        var demonstrated: [Int: GeneticPlacementPlan] = [:]
        for solution in selected {
            let expected = try solution.recordingEvaluation()
            let actual = try GeneticCommander.evaluate(solution.candidate.strategy,
                recording: .database(db.levelRunDao, .simulator), content: study.battle,
                money: context.startingMoney, seed: expected.seed, maxSeconds: context.maxGameSeconds)
            let matches = try db.geneticSolutionDao.saveRecording(for: solution, evaluation: actual)
            guard actual.result.outcome == .victory else {
                throw DbError.Db(message: "genetic publication: candidate \(solution.candidate.id) demonstration did not win; evidence retained, no seed published")
            }
            guard let placements = actual.placementPlan else {
                throw DbError.Db(message: "genetic publication: demonstration omitted placement evidence")
            }
            demonstrated[solution.candidate.id] = placements
            let replay = try LevelReplayer(dao: db.levelRunDao, runID: db.geneticSolutionDao.recordingID(for: solution))
            while try replay.advance() { }
            print("Recorded candidate \(solution.candidate.id): \(solution.victories)/\(solution.expectedSamples) held-out wins; seed \(expected.seed); playback \(actual.result.outcome.rawValue); original result \(matches ? "matched" : "differs (fitness unchanged)")")
        }
        let shown = try selector.select(ranked: selected, plan: { solution in
            guard let plan = demonstrated[solution.candidate.id] else {
                throw DbError.Db(message: "genetic publication: missing demonstrated placements")
            }
            return plan
        })
        guard shown.count == 3 else {
            throw DbError.Db(message: "genetic publication: generated demonstrations fail the same diversity rule; evidence retained, no seed published")
        }
        try db.geneticSolutionDao.exportSeed(to: seedURL)
        try db.geneticSolutionDao.exportRecordingSeeds(for: selected, directory: recordingsURL)
        print("Published three original validated solutions and three newly generated playback recordings.")
    }

    static func run(sourceURL: URL, contentURL: URL, destination: URL, seedURL: URL) throws {
        let paths = [sourceURL, contentURL, destination, seedURL].map { $0.standardizedFileURL.resolvingSymlinksInPath().path }
        guard Set(paths).count == paths.count, seedURL.pathExtension == "sql" else {
            throw DbError.Db(message: "genetic import: source, content, new evidence and SQL output must be separate files")
        }
        let source = try SimulatorDatabase.open(sourceURL, readOnly: true)
        defer { source.close() }
        let sourceStudy = try GeneticStudyDAO(db: source)
        let worker = try sourceStudy.workerConfiguration()
        let sourceRun = worker.runID
        let configuration = try Configuration(algorithm: sourceStudy.algorithm(runID: sourceRun), level: source.levelInfoDao.getBy(id: worker.levelID).name,
            contentSHA256: worker.contentSHA256, executableSHA256: worker.executableSHA256, heroLoadout: worker.heroLoadout,
            trainingSeeds: sourceStudy.seeds(runID: sourceRun, panel: .training),
            validationSeeds: sourceStudy.seeds(runID: sourceRun, panel: .validation), options: sourceStudy.options(runID: sourceRun))
        guard ["genetic-v8", "genetic-v9", "genetic-v10", "genetic-v11", "genetic-v12", "genetic-v13"].contains(configuration.algorithm), configuration.options.bountyFraction == 1,
              configuration.trainingSeeds.count == configuration.options.trainingSeeds,
              configuration.validationSeeds.count == configuration.options.validationSeeds,
              !configuration.validationSeeds.isEmpty,
              Set(configuration.validationSeeds).count == configuration.validationSeeds.count,
              Set(configuration.trainingSeeds).isDisjoint(with: configuration.validationSeeds) else {
            throw DbError.Db(message: "genetic import: unsupported configuration or invalid held-out seeds")
        }
        let rankedCandidates = try sourceStudy.rankedPlacementCandidates(runID: sourceRun, panel: .training)
        guard Set(rankedCandidates.map(\.starsUsed)).count <= 1 else {
            throw DbError.Db(message: "genetic import: choose one star budget before comparing candidates")
        }
        let selector = GeneticSolutionDiversitySelector()
        let selections = try selector.select(ranked: rankedCandidates, plan: { try $0.requirePlacementPlan() })
        guard selections.count == 3 else {
            throw DbError.Db(message: "genetic import: only \(selections.count) saved training winners meet the creative playstyle policy; no seed was published")
        }
        let candidates = try selections.map {
            try sourceStudy.candidate(runID: sourceRun, candidateID: $0.item.id, panel: .training)
        }
        guard candidates.allSatisfy({ $0.evaluations.map(\.seed) == configuration.trainingSeeds }) else {
            throw DbError.Db(message: "genetic import: saved training seed panel differs from study configuration")
        }
        let levelID = try source.levelInfoDao.getIdBy(levelName: configuration.level)
        guard let levelID else { throw DbError.Db(message: "genetic import: missing source level") }

        let store = try SimulatorStore(destination: destination, content: contentURL)
        let db = store.db
        defer { db.close() }
        let heroes = configuration.heroLoadout
        let copy = try BountyExperimentDAO.contentCopy(of: db, fraction: 1,
            selectedHeroIDs: heroes.selectedHeroIDs,
            heroAI: Dictionary(uniqueKeysWithValues: heroes.deployments.map { ($0.heroID, $0.aiEnabled) }))
        defer { copy.close() }
        try copy.difficultyDao.setSelected(difficultyID: source.difficultyDao.requireSelected().id)
        let study = try AuthoredMoneyStudy(db: copy, levelID: levelID)
        func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
        guard try hash(study.replaySnapshot(db: copy, heroesEnabled: true)) == configuration.contentSHA256,
              study.level.startingMoney == configuration.options.money else {
            throw DbError.Db(message: "genetic import: current game content differs from the saved study")
        }
        let context = try GeneticSolutionContext(study: study, db: copy, startingMoney: study.level.startingMoney,
            bountyFraction: 1, maxGameSeconds: configuration.options.maxGameSeconds)
        let validationRun = UUID()
        let executable = try hash(Data(contentsOf: SimulatorStore.executableURL))
        let destinationStudy = try GeneticStudyDAO(db: db)
        try destinationStudy.recordImport(runID: validationRun, context: context, executableSHA256: executable,
            sourceDatabase: sourceURL.path, sourceRunID: sourceRun)
        try db.geneticSolutionDao.saveBest(candidates, runID: sourceRun, context: context,
            executableSHA256: configuration.executableSHA256, panel: .training,
            expectedSamples: configuration.trainingSeeds.count, limitPerStar: 3, study: study)
        var validated: [GeneticCandidate] = []
        for candidate in candidates {
            try candidate.strategy.validate(study: study)
            print("Verifying saved training candidate \(candidate.id)")
            for expected in candidate.evaluations {
                let actual = try GeneticCommander.evaluate(candidate.strategy,
                    recording: .evaluation, content: study.battle,
                    money: study.level.startingMoney, seed: expected.seed, maxSeconds: context.maxGameSeconds)
                guard actual == expected else {
                    throw DbError.Db(message: "genetic import: candidate \(candidate.id), seed \(expected.seed) differs from saved evidence")
                }
            }
            var evaluations: [GeneticEvaluation] = []
            for seed in configuration.validationSeeds {
                evaluations.append(try GeneticCommander.evaluate(candidate.strategy,
                    recording: .evaluation, content: study.battle,
                    money: study.level.startingMoney, seed: seed, maxSeconds: context.maxGameSeconds))
                let partial = GeneticCandidate(id: candidate.id, generation: candidate.generation,
                    strategy: candidate.strategy, evaluations: evaluations)
                try destinationStudy.saveEvidence(partial, runID: validationRun, panel: .validation, expectedSamples: configuration.validationSeeds.count)
                if evaluations.count % 8 == 0 { print("Candidate \(candidate.id): \(evaluations.count)/\(configuration.validationSeeds.count) held-out battles") }
            }
            validated.append(GeneticCandidate(id: candidate.id, generation: candidate.generation,
                strategy: candidate.strategy, evaluations: evaluations))
            try db.geneticSolutionDao.saveBest(validated, runID: validationRun, context: context,
                executableSHA256: executable, panel: .validation, expectedSamples: configuration.validationSeeds.count,
                limitPerStar: 3, study: study)
        }
        guard validated.allSatisfy({ $0.fitness.winRate >= 0.9 }) else {
            throw DbError.Db(message: "genetic import: a selected candidate is below 90% held-out wins; seed was not published")
        }
        let finalSelection = try selector.select(ranked: GeneticCandidate.ranked(validated), plan: { try $0.requirePlacementPlan() })
        guard finalSelection.count == 3 else {
            throw DbError.Db(message: "genetic import: held-out candidates no longer provide three creative winners; evidence was retained, no seed was published")
        }
        try db.geneticSolutionDao.exportSeed(to: seedURL)
        for candidate in GeneticCandidate.ranked(validated) {
            print("Published candidate \(candidate.id): \(candidate.evaluations.filter { $0.result.outcome == .victory }.count)/\(candidate.evaluations.count) victories; fitness \(candidate.fitness)")
        }
        print("Seed: \(seedURL.path)\nValidation evidence: \(destination.path)")
    }
}
