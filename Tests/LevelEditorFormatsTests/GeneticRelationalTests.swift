import XCTest
import SQLite3
@testable import LevelEditorFormats

final class GeneticRelationalTests: XCTestCase {
    private func setup() throws -> (AuthoredDatabaseFixture, AuthoredMoneyStudy, UUID, GeneticSolutionContext) {
        let f = try AuthoredDatabaseFixture(levelGeoJSONDao: LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let id = try XCTUnwrap(f.db.levelInfoDao.getIdBy(levelName: "Charleston"))
        let study = try AuthoredMoneyStudy(db: f.db, levelID: id)
        let context = try GeneticSolutionContext(study: study, db: f.db, startingMoney: study.level.startingMoney, bountyFraction: 1, maxGameSeconds: 1800)
        return (f,study,UUID(),context)
    }
    private func candidate() throws -> GeneticCandidate {
        let type = UUID(), strategy = GeneticStrategy(decisions: [
            .init(step: .init(time: 1.2345678901234567, action: .build(slot: 0, towerID: type)), earliestWave: 1, saveForPurchase: true),
            .init(step: .init(time: 2, action: .upgrade(slot: 0))),
            .init(step: .init(time: 3, action: .purchaseUpgrade(slot: 0, pathID: "test-path")))
        ], metaProgression: try AuthoredDatabaseFixture.metaProgression([.rangeEstimation]),
            reinforcements: .init(priority: .nearPoint(.init(1.2345678901234567, 9.876543210987654)), holdSeconds: 2),
            earlyWaves: .init(decisions: [.init(wave: 2, policy: .automatic), .init(wave: 3, policy: .afterVisible(seconds: 1.3)),
                .init(wave: 4, policy: .whenCountdownAtMost(seconds: 3)), .init(wave: 5, policy: .whenEnemiesAtMost(count: 4, holdSeconds: 5.2))]))
        let result = SimulationResult(outcome: .victory, seconds: 123.45678901234567, livesRemaining: 19, goldRemaining: 101, goldEarned: 205,
            killed: 9, leaked: 1, fatesByTypeID: [type: .init(killed: 9, leaked: 1)], waveMaxProgress: [0, 0.12345678901234567, 1], leaksByWave: [1,0])
        let a = GeneticEvaluation(runID: UUID(), builtTowersByKind: ["ranged": 2], seed: UInt64.max, result: result, wavesStarted: 3,
            waveEconomy: [.init(wave: 2, seconds: 0.03333333333333333, money: 31, lives: 19)],
            reinforcementDeployments: [.init(seconds: 1.2345678901234567, wave: 2, point: .init(123.45678901234567, 456.7890123456789))],
            waveCalls: [.init(seconds: 4.2, wave: 2, countdownSeconds: nil, earlyCallBonus: 3, moneyBefore: 7, moneyAfter: 10),
                        .init(seconds: 5.3, wave: 3, countdownSeconds: 5, earlyCallBonus: 8, moneyBefore: 9, moneyAfter: 17)])
        var defeat = result; defeat.outcome = .defeat; defeat.livesRemaining = 0
        let b = GeneticEvaluation(builtTowersByKind: [:], seed: 0, result: defeat, wavesStarted: 2, waveEconomy: [], reinforcementDeployments: [], waveCalls: [])
        return .init(id: 7, generation: 3, strategy: strategy, evaluations: [a,b])
    }
    func testEveryTypedFieldRoundTripsAndSQLFitnessMatchesSearchExactly() throws {
        let (f,_,run,context) = try setup(), c = try candidate(), store = try GeneticStore(conn: f.connection)
        try store.sql.transaction {
            try store.ensureRun(runID: run, context: context, executableSHA256: String(repeating: "a", count: 64))
            try store.saveCandidate(c, runID: run, panel: .validation, expected: 2)
        }
        let copy = try store.candidate(runID: run, candidateID: c.id, panel: .validation)
        XCTAssertEqual(copy.strategy,c.strategy); XCTAssertEqual(copy.generation,c.generation)
        XCTAssertTrue(zip(c.evaluations,copy.evaluations).allSatisfy { GeneticStore.exact($0.0,$0.1) })
        XCTAssertEqual(copy.fitness,c.fitness)
        let fitness = try store.sql.one("SELECT * FROM ga_candidate_fitness WHERE run_id=?", [run])
        XCTAssertEqual(try fitness.double("win_rate"), c.fitness.winRate)
        XCTAssertEqual(try fitness.double("mean_victory_lives"), c.fitness.meanVictoryLives)
        XCTAssertEqual(try fitness.double("mean_waves_started"), c.fitness.meanWavesStarted)
        XCTAssertEqual(try fitness.double("mean_survival_seconds"), c.fitness.meanSurvivalSeconds)
        XCTAssertTrue(try fitness.bool("panel_complete"))
        try store.sql.execute("DELETE FROM ga_wave_call WHERE ordinal=0")
        XCTAssertThrowsError(try store.candidate(runID: run,candidateID: c.id,panel: .validation))
    }
    func testAppendOnlyValidationAndRollbackProtectDNAAndAllEvidence() throws {
        let (f,_,run,context) = try setup(), c = try candidate(), store = try GeneticStore(conn: f.connection)
        try store.ensureRun(runID: run,context: context,executableSHA256: String(repeating: "a",count: 64))
        let partial = GeneticCandidate(id:c.id,generation:c.generation,strategy:c.strategy,evaluations:[c.evaluations[0]])
        try store.sql.transaction { try store.saveCandidate(partial,runID:run,panel:.validation,expected:2) }
        try store.sql.transaction { try store.saveCandidate(c,runID:run,panel:.validation,expected:2) }
        let before = try store.sql.one("SELECT COUNT(*) AS n FROM ga_evaluation").int("n")
        XCTAssertThrowsError(try store.sql.transaction { try store.saveCandidate(partial,runID:run,panel:.validation,expected:2) })
        var changed = c.evaluations; changed[0].builtTowersByKind = ["ranged":99]
        let invalid = GeneticCandidate(id:c.id,generation:c.generation,strategy:c.strategy,evaluations:changed)
        XCTAssertThrowsError(try store.sql.transaction { try store.saveCandidate(invalid,runID:run,panel:.validation,expected:2) })
        XCTAssertEqual(try store.sql.one("SELECT COUNT(*) AS n FROM ga_evaluation").int("n"), before)
        XCTAssertEqual(try store.candidate(runID:run,candidateID:c.id,panel:.validation).evaluations[0].builtTowersByKind,c.evaluations[0].builtTowersByKind)
    }
    func testSQLRankingUsesTheSameOrderedDoubleFoldAsGeneticFitness() throws {
        let (f,_,run,context) = try setup(), template = try candidate(), store = try GeneticStore(conn: f.connection)
        try store.ensureRun(runID: run,context: context,executableSHA256: String(repeating: "a",count: 64))
        let timings = [(1940,[337.1666666666667,336.4,334.1333333333333]),
                       (2014,[336.56666666666666,335.3333333333333,335.8])]
        let candidates = timings.map { id, seconds in
            GeneticCandidate(id: id,generation: 1,strategy: template.strategy,evaluations: seconds.enumerated().map { i, seconds in
                var result = template.evaluations[0].result
                result.outcome = .defeat; result.livesRemaining = 0; result.seconds = seconds
                return GeneticEvaluation(seed: UInt64(i),result:result,wavesStarted:15,waveEconomy:[],reinforcementDeployments:[],waveCalls:[])
            })
        }
        for c in candidates { try store.saveCandidate(c,runID:run,panel:.training,expected:3) }
        let rows = try store.sql.rows("SELECT * FROM ga_candidate_fitness WHERE run_id=? ORDER BY win_rate DESC,mean_victory_lives DESC,mean_waves_started DESC,mean_survival_seconds DESC,candidate_id",[run])
        XCTAssertEqual(try rows.map { try $0.int("candidate_id") },GeneticCandidate.ranked(candidates).map(\.id))
        for row in rows {
            let c = try XCTUnwrap(candidates.first { $0.id == (try? row.int("candidate_id")) })
            XCTAssertEqual(try row.double("mean_survival_seconds").bitPattern,c.fitness.meanSurvivalSeconds.bitPattern)
        }
    }

    func testCandidateBatchRollsBackWhenRunProgressCannotBeSaved() throws {
        let (f,_,run,context) = try setup(), c = try candidate()
        let store = try GeneticStore(conn: f.connection), dao = try GeneticStudyDAO(db: f.db)
        try store.ensureRun(runID: run,context: context,executableSHA256: String(repeating: "a",count: 64))
        XCTAssertThrowsError(try dao.insert([c],runID:run,panel:.training,expectedSamples:2,completed:2,rate:1))
        XCTAssertTrue(try store.sql.rows("SELECT * FROM ga_candidate WHERE run_id=?",[run]).isEmpty)
    }

    func testStudyOptionsWorkersSeedsAndProgressUseRelationalRows() throws {
        let (f,study,run,context) = try setup(), dao = try GeneticStudyDAO(db:f.db)
        var options = GeneticStudyOptions(); options.money = study.level.startingMoney
        options.workers=2; options.seed=UInt64.max; options.starMinimum=0; options.starMaximum=2
        options.heroAIEnabled=false; options.selectedHeroIDs=context.heroLoadout!.selectedHeroIDs
        options.trainingSeeds=2; options.validationSeeds=2
        try dao.begin(runID:run,context:context,executableSHA256:String(repeating:"b",count:64),snapshotSHA256:String(repeating:"c",count:64),
            buildVersion:"test",options:options,requestedStars:[0,1,2],reachableStars:[0,1,2],earnedStars:2,databaseUpgrades:[],
            trainingSeeds:[UInt64.max,0],validationSeeds:[1,2])
        XCTAssertEqual(try dao.runID(),run)
        XCTAssertEqual(try dao.seeds(runID:run,panel:.training),[UInt64.max,0])
        XCTAssertEqual(try dao.workerConfiguration().heroLoadout,context.heroLoadout)
        let copy=try dao.options(runID:run)
        let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys]
        XCTAssertEqual(try encoder.encode(copy),try encoder.encode(options))
        let p=GeneticProgress.Snapshot(runID:run,phase:.validation,percentComplete:86.7,elapsedSeconds:123.4,estimatedSecondsRemaining:nil,
            completedGenerations:2,trainingEvaluations:3,validationEvaluations:1,milestones:[.init(percent:80,elapsedSeconds:100)])
        try dao.saveProgress(p);XCTAssertEqual(try dao.progress(),p)
        let sql=try GeneticSQL(f.connection)
        try sql.execute("DELETE FROM ga_study_seed WHERE panel='training' AND ordinal=0")
        XCTAssertThrowsError(try dao.seeds(runID:run,panel:.training))
    }
    func testQualificationHistoryAndFinalCopyCountEveryActualBattleOnce() throws {
        let (f,study,_,context) = try setup(), dao = try GeneticStudyDAO(db:f.db), c = try candidate()
        let sql = try GeneticSQL(f.connection)
        let run = try f.db.simulatorRunDao.begin(levelName: study.level.name, focus: "test", totalIterations: 0, outputPath: f.db.path)
        var options = GeneticStudyOptions(); options.trainingSeeds = 2; options.validationSeeds = 2
        try dao.begin(runID:run,context:context,executableSHA256:String(repeating:"a",count:64),snapshotSHA256:String(repeating:"b",count:64),buildVersion:"test",
            options:options,requestedStars:[c.starsUsed],reachableStars:[c.starsUsed],earnedStars:42,databaseUpgrades:[],
            trainingSeeds:c.evaluations.map(\.seed),validationSeeds:[10,11])
        try dao.insert([c],runID:run,panel:.training,expectedSamples:2,completed:2,rate:1)
        var evidenceIDs: [UUID] = []
        for attempt in 0..<2 {
            let seeds: [UInt64] = attempt == 0 ? [10,11] : [12,13]
            let id = try dao.beginQualification(runID:run,attempt:attempt,context:context,executableSHA256:String(repeating:"a",count:64),
                trainingBattles:2,generations:1,seeds:seeds)
            evidenceIDs.append(id)
            let samples = zip(c.evaluations,seeds).map { e,seed in
                GeneticEvaluation(seed:seed,result:e.result,wavesStarted:e.wavesStarted,
                    waveEconomy:e.waveEconomy,reinforcementDeployments:e.reinforcementDeployments,waveCalls:e.waveCalls)
            }
            let v = GeneticCandidate(id:c.id,generation:c.generation,strategy:c.strategy,evaluations:samples)
            try dao.saveEvidence(v,runID:id,panel:.validation,expectedSamples:2)
            try dao.finishQualification(evidenceID:id,status:attempt == 0 ? "rejected" : "qualified")
            if attempt == 1 {
                try dao.insert([v],runID:run,panel:.validation,expectedSamples:2,completed:6,rate:1)
                try dao.finalValidationSeeds(runID:run,seeds:seeds)
            }
        }
        XCTAssertEqual(try dao.candidate(runID:evidenceIDs[0],candidateID:c.id,panel:.validation).evaluations.map(\.seed),[10,11])
        XCTAssertEqual(try dao.candidate(runID:evidenceIDs[1],candidateID:c.id,panel:.validation).evaluations.map(\.seed),[12,13])
        XCTAssertEqual(try dao.candidate(runID:run,candidateID:c.id,panel:.training).fitness,c.fitness)
        XCTAssertEqual(try dao.seeds(runID:run,panel:.validation),[12,13])
        XCTAssertEqual(try sql.one("SELECT COUNT(*) AS n FROM ga_evaluation WHERE run_id=? OR run_id IN (SELECT evidence_run_id FROM ga_qualification WHERE study_run_id=?)",[run,run]).int("n"),8)
        try dao.finish(runID:run,completed:6)
        XCTAssertEqual(try sql.one("SELECT completed_iterations FROM simulator_run WHERE id=?",[run]).int("completed_iterations"),6)
        try sql.execute("DROP TABLE ga_stopping_policy")
        XCTAssertNil(try dao.options(runID:run).stopping, "Old studies must not acquire an invented quality policy")
    }

    func testIncrementalCheckpointPreservesMembersAndRollbackDoesNotLoseAppendCursor() throws {
        let (f,_,run,context) = try setup(), dao = try GeneticStudyDAO(db:f.db), c = try candidate(), sql = try GeneticSQL(f.connection)
        try sql.execute("PRAGMA foreign_keys=ON")
        var options = GeneticStudyOptions(); options.trainingSeeds=2; options.validationSeeds=2
        try dao.begin(runID:run,context:context,executableSHA256:String(repeating:"a",count:64),snapshotSHA256:String(repeating:"b",count:64),buildVersion:"test",
            options:options,requestedStars:[c.starsUsed],reachableStars:[c.starsUsed],earnedStars:42,databaseUpgrades:[],
            trainingSeeds:c.evaluations.map(\.seed),validationSeeds:[1,2])
        var population = try GeneticMetaPopulation(selections:[c.metaUpgrades],population:4,minimumCandidates:2)
        try dao.saveEvidence(c,runID:run,panel:.training,expectedSamples:2)
        try population.record(c)
        try dao.checkpoint(runID:run,populations:[c.starsUsed:population],generations:1,nextID:8,cacheHits:0)
        let later = GeneticCandidate(id:8,generation:4,strategy:c.strategy,evaluations:c.evaluations)
        try population.record(later)
        XCTAssertThrowsError(try dao.checkpoint(runID:run,populations:[c.starsUsed:population],generations:2,nextID:9,cacheHits:0))
        XCTAssertEqual(try sql.one("SELECT COUNT(*) AS n FROM ga_population_member").int("n"),1)
        try dao.saveEvidence(later,runID:run,panel:.training,expectedSamples:2)
        try dao.checkpoint(runID:run,populations:[c.starsUsed:population],generations:2,nextID:9,cacheHits:1)
        // A newly opened DAO must also append from the persisted membership count.
        try GeneticStudyDAO(db:f.db).checkpoint(runID:run,populations:[c.starsUsed:population],generations:3,nextID:9,cacheHits:2)
        XCTAssertEqual(try sql.rows("SELECT candidate_id FROM ga_population_member ORDER BY candidate_id").map { try $0.int("candidate_id") },[7,8])
        XCTAssertEqual(try sql.rows("SELECT candidate_id FROM ga_population_member WHERE archive_ordinal IS NOT NULL ORDER BY archive_ordinal").map { try $0.int("candidate_id") },population.selections[0].archive.map(\.id))
        XCTAssertEqual(try sql.one("SELECT completed_generations FROM ga_checkpoint").int("completed_generations"),3)
    }

}
