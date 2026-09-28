import Foundation
import CryptoKit

/// Explicit offline publication, separate from time-bounded search. Owns only
/// selection, provenance and recording; every battle uses GeneticCommander.
@MainActor enum GeneticSolutionImport {
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
    private struct Run: Decodable { let runID: UUID }

    static func run(sourceURL: URL, contentURL: URL, destination: URL, seedURL: URL) throws {
        let paths = [sourceURL, contentURL, destination, seedURL].map { $0.standardizedFileURL.resolvingSymlinksInPath().path }
        guard Set(paths).count == paths.count, seedURL.pathExtension == "sql" else {
            throw DbError.Db(message: "genetic import: source, content, new evidence and SQL output must be separate files")
        }
        let source = try SimulatorDatabase.open(sourceURL, readOnly: true)
        defer { source.close() }
        let configurationData = try source.simulatorInvocationDao.document(named: "configuration.json")
        let configuration = try JSONDecoder().decode(Configuration.self, from: configurationData)
        let sourceRun = try JSONDecoder().decode(Run.self,
            from: source.simulatorInvocationDao.document(named: "run.json")).runID
        guard configuration.algorithm == "genetic-v8", configuration.options.bountyFraction == 1,
              configuration.trainingSeeds.count == configuration.options.trainingSeeds,
              configuration.validationSeeds.count == configuration.options.validationSeeds,
              !configuration.validationSeeds.isEmpty,
              Set(configuration.validationSeeds).count == configuration.validationSeeds.count,
              Set(configuration.trainingSeeds).isDisjoint(with: configuration.validationSeeds) else {
            throw DbError.Db(message: "genetic import: unsupported configuration or invalid held-out seeds")
        }
        let candidates = try MoneyStudyDAO(db: source).bestTrainingCandidates(runID: sourceRun,
            seeds: configuration.trainingSeeds, limit: 3)
        guard candidates.count == 3 else { throw DbError.Db(message: "genetic import: fewer than three distinct candidates") }
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
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try db.simulatorInvocationDao.saveDocument(configurationData, name: "source-configuration.json")
        try db.simulatorInvocationDao.saveDocument(encoder.encode(candidates), name: "frozen-training-candidates.json")
        try db.simulatorInvocationDao.saveDocument(JSONSerialization.data(withJSONObject: [
            "sourceDatabase": sourceURL.path, "sourceRunID": sourceRun.uuidString,
            "validationRunID": validationRun.uuidString, "executableSHA256": executable,
            "candidateIDs": candidates.map(\.id),
            "selection": "Top three distinct complete training panels, frozen before held-out evaluation"
        ], options: [.sortedKeys]), name: "import-provenance.json")
        try db.geneticSolutionDao.saveBest(candidates, runID: sourceRun, context: context,
            executableSHA256: configuration.executableSHA256, panel: .training,
            expectedSamples: configuration.trainingSeeds.count, limitPerStar: 3, study: study)
        var validated: [GeneticCandidate] = []
        for candidate in candidates {
            try candidate.strategy.validate(study: study)
            print("Verifying saved training candidate \(candidate.id)")
            for expected in candidate.evaluations {
                let actual = try GeneticCommander.evaluate(candidate.strategy,
                    recording: .database(db.levelRunDao, .simulator), content: study.battle,
                    money: study.level.startingMoney, seed: expected.seed, maxSeconds: context.maxGameSeconds)
                guard actual == expected else {
                    throw DbError.Db(message: "genetic import: candidate \(candidate.id), seed \(expected.seed) differs from saved evidence")
                }
            }
            var evaluations: [GeneticEvaluation] = []
            for seed in configuration.validationSeeds {
                evaluations.append(try GeneticCommander.evaluate(candidate.strategy,
                    recording: .database(db.levelRunDao, .simulator), content: study.battle,
                    money: study.level.startingMoney, seed: seed, maxSeconds: context.maxGameSeconds))
                let partial = GeneticCandidate(id: candidate.id, generation: candidate.generation,
                    strategy: candidate.strategy, evaluations: evaluations)
                try db.simulatorInvocationDao.saveDocument(encoder.encode(partial), name: "validation-\(candidate.id).json")
                if evaluations.count % 8 == 0 { print("Candidate \(candidate.id): \(evaluations.count)/\(configuration.validationSeeds.count) held-out battles") }
            }
            validated.append(GeneticCandidate(id: candidate.id, generation: candidate.generation,
                strategy: candidate.strategy, evaluations: evaluations))
            try db.geneticSolutionDao.saveBest(validated, runID: validationRun, context: context,
                executableSHA256: executable, panel: .validation, expectedSamples: configuration.validationSeeds.count,
                limitPerStar: 3, study: study)
        }
        guard validated.allSatisfy({ $0.evaluations.contains { $0.result.outcome == .victory } }) else {
            throw DbError.Db(message: "genetic import: a selected candidate has no held-out victory; seed was not published")
        }
        try db.geneticSolutionDao.exportSeed(to: seedURL)
        for candidate in GeneticCandidate.ranked(validated) {
            print("Published candidate \(candidate.id): \(candidate.evaluations.filter { $0.result.outcome == .victory }.count)/\(candidate.evaluations.count) victories; fitness \(candidate.fitness)")
        }
        print("Seed: \(seedURL.path)\nValidation evidence: \(destination.path)")
    }
}
