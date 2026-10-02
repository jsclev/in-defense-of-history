import XCTest
import SQLite3
@testable import LevelEditorFormats

final class GeneticSolutionDAOTests: XCTestCase {
    private let executable = String(repeating: "a", count: 64)

    private func fixture() throws -> AuthoredDatabaseFixture {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao: LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        try execute("PRAGMA foreign_keys=ON; DELETE FROM genetic_solution;", fixture)
        return fixture
    }
    private func study(_ fixture: AuthoredDatabaseFixture, level: String = "Charleston") throws -> AuthoredMoneyStudy {
        try AuthoredMoneyStudy(db: fixture.db, levelID: XCTUnwrap(fixture.db.levelInfoDao.getIdBy(levelName: level)))
    }
    private func context(_ study: AuthoredMoneyStudy, _ fixture: AuthoredDatabaseFixture, money: Int? = nil,
                         bounty: Double = 1) throws -> GeneticSolutionContext {
        try GeneticSolutionContext(study: study, db: fixture.db, startingMoney: money ?? study.level.startingMoney,
                                   bountyFraction: bounty, maxGameSeconds: 1800)
    }
    private func sample(_ seed: UInt64, victory: Bool, lives: Int = 10) -> GeneticEvaluation {
        GeneticEvaluation(seed: seed, result: SimulationResult(outcome: victory ? .victory : .defeat, seconds: 600,
            livesRemaining: victory ? lives : 0, goldRemaining: 10, goldEarned: 50, killed: 10, leaked: 0,
            fatesByTypeID: [:], waveMaxProgress: [], leaksByWave: []), wavesStarted: 15,
            waveEconomy: [], reinforcementDeployments: [], waveCalls: [])
    }
    private func candidate(_ id: Int, wins: Int = 2, lives: Int = 10, hold: Double = 0,
                           selection: [MetaUpgrade] = []) throws -> GeneticCandidate {
        GeneticCandidate(id: id, generation: 1, strategy: GeneticStrategy(decisions: [], metaProgression: try AuthoredDatabaseFixture.metaProgression(selection),
                reinforcements: ReinforcementStrategy(priority: .nearestExit, holdSeconds: hold)),
            evaluations: (0..<2).map { sample(UInt64($0), victory: $0 < wins, lives: lives) })
    }
    private func save(_ values: [GeneticCandidate], in fixture: AuthoredDatabaseFixture, study: AuthoredMoneyStudy,
                      run: UUID = UUID(), panel: GeneticSolutionPanel = .validation, expected: Int = 2,
                      limit: Int = 8, context override: GeneticSolutionContext? = nil) throws {
        try fixture.db.geneticSolutionDao.saveBest(values, runID: run, context: override ?? context(study, fixture),
            executableSHA256: executable, panel: panel, expectedSamples: expected, limitPerStar: limit, study: study)
    }
    private func execute(_ sql: String, _ fixture: AuthoredDatabaseFixture) throws {
        guard sqlite3_exec(fixture.connection, sql, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(fixture.connection)))
        }
    }

    func testRanksByGAFitnessKeepsDistinctPlansAndSeparatesStarGroups() throws {
        let f = try fixture(), s = try study(f), c = try context(s, f)
        let weak = try candidate(1, wins: 1), strong = try candidate(2, lives: 15, hold: 1)
        let duplicate = try candidate(3, lives: 15, hold: 1)
        let third = try candidate(4, lives: 12, hold: 2)
        let upgrade = try candidate(5, selection: [.rangeEstimation])
        try save([weak, third, duplicate, upgrade, strong], in: f, study: s, limit: 2)
        let records = try f.db.geneticSolutionDao.best(context: c, starsUsed: 0, study: s)
        XCTAssertEqual(records.map { $0.candidate.id }, [2, 4])
        XCTAssertEqual(records[0].candidate.strategy, strong.strategy)
        XCTAssertEqual(records[0].candidate.evaluations, strong.evaluations)
        XCTAssertEqual(records[0].candidate.generation, 1)
        XCTAssertEqual(records[0].executableSHA256, executable)
        XCTAssertTrue(records[0].validationComplete)
        XCTAssertTrue(records[0].heroesEnabled)
        XCTAssertEqual(records[0].formatVersion, 2)
        XCTAssertEqual(records[0].context.heroLoadout?.selectedHeroIDs, s.battle.chosenHeroes.ids)
        XCTAssertEqual(try f.db.geneticSolutionDao.best(context: c, starsUsed: 1, study: s).map { $0.candidate.id }, [5])
    }

    func testRecordingSelectionUsesOnlyRetainedPlansAndPrefersValidationPerStarGroup() throws {
        let f = try fixture(), s = try study(f), run = UUID()
        try save([try candidate(1), try candidate(4, selection: [.rangeEstimation])], in: f, study: s, run: run, panel: .training)
        try save([try candidate(2, hold: 1), try candidate(3, lives: 1, hold: 2)],
                 in: f, study: s, run: run, limit: 1)
        try save([try candidate(9, hold: 3)], in: f, study: s)
        let selected = try f.db.geneticSolutionDao.recordingCandidates(runID: run)
        XCTAssertEqual(selected.map { $0.candidate.id }, [2, 4])
        XCTAssertEqual(selected.map(\.panel), [.validation, .training])
        XCTAssertEqual(try selected[0].recordingEvaluation().seed, 0)
        XCTAssertTrue(try f.db.geneticSolutionDao.recordingCandidates(runID: UUID()).isEmpty)
    }

    func testMissingRecordingSchemaFailsBeforeEvaluation() throws {
        let f = try fixture()
        XCTAssertNoThrow(try f.db.geneticSolutionDao.requireRecordingStorage())
        try execute("DROP TABLE genetic_solution_recording", f)
        XCTAssertThrowsError(try f.db.geneticSolutionDao.requireRecordingStorage()) {
            XCTAssertTrue(String(describing: $0).contains("fresh starter"))
        }
    }

    func testPublicationUsesCompleteValidationRankingOnly() throws {
        let f = try fixture(), s = try study(f), run = UUID()
        try save([try candidate(1, lives: 5), try candidate(2, lives: 15, hold: 1),
                  try candidate(3, lives: 10, hold: 2), try candidate(4, lives: 2, hold: 3)], in: f, study: s, run: run)
        try save([try candidate(8, lives: 20, hold: 4)], in: f, study: s, run: run, panel: .training)
        XCTAssertEqual(try f.db.geneticSolutionDao.validatedCandidates(runID: run, limit: 3).map { $0.candidate.id }, [2, 3, 1])
        XCTAssertTrue(try f.db.geneticSolutionDao.validatedCandidates(runID: UUID(), limit: 3).isEmpty)
    }

    func testPublicationCanScanValidatedCandidatesOutsideRetainedShortlist() throws {
        let f = try fixture(), s = try study(f), run = UUID()
        try save([try candidate(1, lives: 15)], in: f, study: s, run: run)
        let dao = try GeneticStudyDAO(db: f.db)
        try dao.saveEvidence(candidate(2, lives: 10, hold: 1), runID: run, panel: .validation, expectedSamples: 2)
        try dao.saveEvidence(candidate(3, lives: 20, hold: 2), runID: run, panel: .validation, expectedSamples: 3)
        XCTAssertEqual(try f.db.geneticSolutionDao.validatedCandidates(runID: run, limit: 3).map { $0.candidate.id }, [1,2])
    }

    func testPlacementRankingReadsCompleteSavedPlansWithoutEvaluationOrBattleContent() throws {
        let f = try fixture(), s = try study(f), run = UUID()
        try save([try candidate(1, lives: 15)], in: f, study: s, run: run)
        let towerID = try XCTUnwrap(s.towerPaths.first).type.id
        let strategy = GeneticStrategy(decisions: [
            .init(step: .init(time: 0, action: .build(slot: 0, towerID: towerID))),
            .init(step: .init(time: 2, action: .build(slot: 1, towerID: towerID))),
            .init(step: .init(time: 0, action: .build(slot: 2, towerID: towerID)), earliestWave: 1),
            .init(step: .init(time: 0, action: .upgrade(slot: 0)))
        ], metaProgression: try AuthoredDatabaseFixture.metaProgression([]))
        var recorded = sample(0, victory: true)
        recorded.placementPlan = GeneticPlacementPlan(initial: [.init(slot: 0, towerID: towerID)],
            subsequent: [.init(slot: 1, towerID: towerID), .init(slot: 2, towerID: towerID)])
        let value = GeneticCandidate(id: 2, generation: 1, strategy: strategy,
            evaluations: [recorded, sample(1, victory: true)])
        let dao = try GeneticStudyDAO(db: f.db)
        try dao.saveEvidence(value, runID: run, panel: .validation, expectedSamples: 2)
        try dao.saveEvidence(candidate(3, lives: 20, hold: 2), runID: run, panel: .validation, expectedSamples: 3)
        let rows = try dao.rankedPlacementCandidates(runID: run, panel: .validation)
        XCTAssertEqual(rows.map(\.id), [1,2])
        XCTAssertEqual(rows[1].placementPlan, value.placementPlan)
        XCTAssertEqual(rows[1].placementPlan?.initial.map(\.slot), [0])
        XCTAssertEqual(rows[1].placementPlan?.subsequent.map(\.slot), [1,2])
        XCTAssertNil(rows[0].placementPlan)
        XCTAssertThrowsError(try rows[0].requirePlacementPlan())
        XCTAssertEqual(try dao.candidate(runID: run, candidateID: 2, panel: .validation).placementPlan, recorded.placementPlan)
        try execute("DELETE FROM ga_placement WHERE ordinal=0 AND evaluation_id=(SELECT evaluation_id FROM ga_evaluation WHERE run_id='\(run.uuidString)' AND candidate_id=2 AND seed='0')", f)
        XCTAssertThrowsError(try dao.rankedPlacementCandidates(runID: run, panel: .validation))
    }

    @MainActor func testRecordingDifferencesDoNotReplaceFitnessAndUInt64SeedsArePreserved() throws {
        let f = try fixture(), s = try study(f), run = UUID()
        let strategy = try candidate(1).strategy
        let actual = try GeneticCommander.evaluate(strategy, recording: .database(f.db.levelRunDao, .simulator),
            content: s.battle, money: s.level.startingMoney, seed: UInt64.max, maxSeconds: 1)
        let original = GeneticEvaluation(seed: actual.seed, result: actual.result,
            wavesStarted: actual.wavesStarted + 1, waveEconomy: actual.waveEconomy,
            reinforcementDeployments: actual.reinforcementDeployments, waveCalls: actual.waveCalls)
        let value = GeneticCandidate(id: 1, generation: 1, strategy: strategy, evaluations: [original])
        try save([value], in: f, study: s, run: run, expected: 1)
        let solution = try XCTUnwrap(f.db.geneticSolutionDao.recordingCandidates(runID: run).first)
        XCTAssertFalse(try f.db.geneticSolutionDao.saveRecording(for: solution, evaluation: actual))
        let unchanged = try XCTUnwrap(f.db.geneticSolutionDao.recordingCandidates(runID: run).first)
        XCTAssertEqual(unchanged.candidate.evaluations, [original])
        XCTAssertEqual(unchanged.candidate.fitness, value.fitness)
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(f.connection,
            "SELECT seed,level_run_id,matches_evaluation,waves_started FROM genetic_solution_recording", -1, &stmt, nil), SQLITE_OK)
        defer { sqlite3_finalize(stmt) }
        XCTAssertEqual(sqlite3_step(stmt), SQLITE_ROW)
        XCTAssertEqual(String(cString: sqlite3_column_text(stmt, 0)), String(UInt64.max))
        XCTAssertEqual(String(cString: sqlite3_column_text(stmt, 1)), actual.runID?.uuidString)
        XCTAssertEqual(sqlite3_column_int(stmt, 2), 0)
        XCTAssertEqual(sqlite3_column_int64(stmt, 3), Int64(actual.wavesStarted))
        XCTAssertThrowsError(try f.db.geneticSolutionDao.saveRecording(for: solution, evaluation: original))
        XCTAssertThrowsError(try f.db.geneticSolutionDao.saveRecording(for: solution, evaluation: actual), "Cannot silently replace a saved demonstration")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ga-recording-seed-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        try f.db.geneticSolutionDao.exportRecordingSeeds(for: [solution], directory: directory)
        let restored = try fixture(), restoredStudy = try study(restored)
        try save([value], in: restored, study: restoredStudy, run: run, expected: 1)
        try execute(String(contentsOf: directory.appendingPathComponent("candidate-1.sql"), encoding: .utf8), restored)
        let restoredID = try restored.db.geneticSolutionDao.recordingID(for: solution)
        XCTAssertEqual(restoredID, actual.runID)
        XCTAssertEqual(try restored.db.levelRunDao.get(id: restoredID).setup,
                       try f.db.levelRunDao.get(id: restoredID).setup)
        let expectedRows = try f.db.levelRunDao.actions(runID: restoredID)
        let restoredRows = try restored.db.levelRunDao.actions(runID: restoredID)
        XCTAssertEqual(restoredRows.map(\.eventData), expectedRows.map(\.eventData))
        XCTAssertEqual(restoredRows.map(\.payloadJSON), expectedRows.map(\.payloadJSON))
    }

    func testOfflineRecoveryUsesGAFitnessDistinctDNAAndExactTrainingSeeds() throws {
        let f = try fixture(), run = UUID()
        try execute("INSERT INTO simulator_run(id,level_name,status,started_at,updated_at) VALUES('\(run)','Charleston','running','test','test')", f)
        let dao = try MoneyStudyDAO(db: f.db)
        try dao.begin(runID: run, configuration: "{}", contentSHA256: executable, plans: "{}")
        let values = try [candidate(1, wins: 1), candidate(2, lives: 20, hold: 1),
                          candidate(3, lives: 20, hold: 1), candidate(4, lives: 18, hold: 2)]
        try dao.insert(values.map {
            MoneyStudyResultRow(money: 670, placementPlan: $0.id, upgradePolicy: 0,
                results: $0.evaluations.map(\.result),
                evidenceJSON: String(decoding: try JSONEncoder().encode($0), as: UTF8.self))
        }, runID: run, completed: 8, rate: 1)
        let selected = try dao.bestTrainingCandidates(runID: run, seeds: [0, 1], limit: 3)
        XCTAssertEqual(selected.map(\.id), [2, 4, 1])
        XCTAssertEqual(selected.first?.evaluations, values[1].evaluations)
        XCTAssertEqual(selected.first?.strategy, values[1].strategy)
        XCTAssertThrowsError(try dao.bestTrainingCandidates(runID: run, seeds: [1, 2], limit: 3))
        XCTAssertThrowsError(try dao.bestTrainingCandidates(runID: run, seeds: [0, 1], limit: 0))
        try execute("UPDATE money_study_result SET seed_results_json='{}' WHERE placement_plan=2", f)
        XCTAssertThrowsError(try dao.bestTrainingCandidates(runID: run, seeds: [0, 1], limit: 3))
    }

    @MainActor func testPreviewReturnsThreeDistinctCompatiblePlansInRankOrder() throws {
        let f = try fixture(), s = try study(f)
        try save([try candidate(2, lives: 20, hold: 1), try candidate(4, lives: 18, hold: 2),
                  try candidate(5, lives: 17, hold: 3)], in: f, study: s)
        // A second run of the same DNA cannot consume a preview choice.
        try save([try candidate(3, lives: 20, hold: 1)], in: f, study: s)
        try save([try candidate(6, lives: 20, hold: 4)], in: f, study: s, panel: .training)
        try save([try candidate(7, lives: 20, hold: 5)], in: f, study: s, expected: 3)
        let selected = try GeneticSolutionPlayback.best(db: f.db, levelID: s.level.id,
            difficultyID: s.difficulty.id, limit: 3)
        XCTAssertEqual(selected.count, 3)
        XCTAssertEqual(selected.map { $0.candidate.strategy.reinforcements.holdSeconds }, [1, 2, 3])
        XCTAssertTrue(try GeneticSolutionPlayback.best(db: f.db, levelID: s.level.id,
            difficultyID: UUID(), limit: 3).isEmpty)
        try execute("UPDATE tower SET cost=cost+1", f)
        XCTAssertTrue(try GeneticSolutionPlayback.best(db: f.db, levelID: s.level.id,
            difficultyID: s.difficulty.id, limit: 3).isEmpty)
    }

    func testAdviserDefaultsExcludeTrainingPartialPanelsAndDefeatsWithoutErasingEarlierWinners() throws {
        let f = try fixture(), s = try study(f), c = try context(s, f)
        try save([try candidate(1)], in: f, study: s, panel: .training)
        try save([try candidate(2, hold: 1)], in: f, study: s, expected: 3)
        try save([try candidate(3, wins: 0, hold: 2)], in: f, study: s)
        XCTAssertTrue(try f.db.geneticSolutionDao.best(context: c, starsUsed: 0, study: s).isEmpty)
        XCTAssertEqual(try f.db.geneticSolutionDao.best(context: c, starsUsed: 0, study: s,
            requireCompletePanel: false).count, 1)
        try save([try candidate(4, hold: 3)], in: f, study: s)
        try save([try candidate(5, wins: 0, hold: 4)], in: f, study: s)
        XCTAssertEqual(try f.db.geneticSolutionDao.best(context: c, starsUsed: 0, study: s).map { $0.candidate.id }, [4])
        XCTAssertEqual(try f.db.geneticSolutionDao.best(context: c, starsUsed: 0, study: s, panel: .training).count, 1)
        XCTAssertEqual(try f.db.geneticSolutionDao.best(context: c, starsUsed: 0, study: s,
            winningOnly: false).count, 3)
    }

    func testContextSeparatesExperimentsAndContentChangesButNotPlayerProgression() throws {
        let f = try fixture(), s = try study(f), c = try context(s, f)
        try save([try candidate(1)], in: f, study: s)
        for other in [try context(s, f, money: s.level.startingMoney + 1), try context(s, f, bounty: 0.5)] {
            XCTAssertTrue(try f.db.geneticSolutionDao.best(context: other, starsUsed: 0, study: s).isEmpty)
        }
        let otherLevel = try study(f, level: "Bunker Hill")
        XCTAssertTrue(try f.db.geneticSolutionDao.best(context: context(otherLevel, f), starsUsed: 0, study: otherLevel).isEmpty)
        try f.db.playerMetaUpgradeDao.reset()
        XCTAssertEqual(try context(study(f), f), c, "Player selections must not invalidate shipping content")
        try execute("UPDATE player_meta_upgrade_level_stars SET best_stars=0 WHERE profile_key='active'", f)
        XCTAssertEqual(try context(study(f), f), c, "Earning stars must not invalidate shipping content")
        try execute("UPDATE tower SET cost=cost+1", f)
        let changed = try study(f), updated = try context(changed, f)
        XCTAssertNotEqual(updated.contentSHA256, c.contentSHA256)
        XCTAssertTrue(try f.db.geneticSolutionDao.best(context: updated, starsUsed: 0, study: changed).isEmpty)
        try execute("DELETE FROM combat_rules", f)
        XCTAssertThrowsError(try study(f))
    }

    func testRejectsInvalidDataAndChangedEvidencePreservingPreviousPublication() throws {
        let f = try fixture(), s = try study(f), c = try context(s, f), run = UUID()
        let good = try candidate(1)
        try save([good], in: f, study: s, run: run)
        let empty = GeneticCandidate(id: 2, generation: 0, strategy: good.strategy, evaluations: [])
        let duplicateSeed = GeneticCandidate(id: 2, generation: 0, strategy: good.strategy,
            evaluations: [good.evaluations[0], good.evaluations[0]])
        for invalid in [empty, duplicateSeed, try candidate(2, hold: -1)] {
            XCTAssertThrowsError(try save([invalid], in: f, study: s, run: run))
        }
        XCTAssertThrowsError(try save([good, good], in: f, study: s, run: run))
        XCTAssertThrowsError(try save([try candidate(1, hold: 3)], in: f, study: s, run: run))
        XCTAssertThrowsError(try save([try candidate(1, wins: 0)], in: f, study: s, run: run))
        XCTAssertThrowsError(try save([good], in: f, study: s, run: run, context: context(s, f, money: 1)))
        try execute("CREATE TRIGGER fail_solution BEFORE INSERT ON genetic_solution BEGIN SELECT RAISE(ABORT, 'test write failure'); END", f)
        XCTAssertThrowsError(try save([try candidate(2, hold: 2)], in: f, study: s, run: run))
        XCTAssertEqual(try f.db.geneticSolutionDao.best(context: c, starsUsed: 0, study: s).map { $0.candidate.id }, [1],
                       "Replacement must roll back its deletion on an insert failure")
    }

    func testReadRejectsMissingAndMalformedRequiredPayload() throws {
        let f = try fixture(), s = try study(f), c = try context(s, f)
        try save([try candidate(1)], in: f, study: s)
        try execute("PRAGMA ignore_check_constraints=ON; UPDATE ga_strategy SET reinforcement_hold_seconds=-1; PRAGMA ignore_check_constraints=OFF", f)
        XCTAssertThrowsError(try f.db.geneticSolutionDao.best(context: c, starsUsed: 0, study: s))
        try execute("DELETE FROM ga_evaluation", f)
        XCTAssertThrowsError(try f.db.geneticSolutionDao.best(context: c, starsUsed: 0, study: s))
        try execute("DROP TABLE genetic_solution", f)
        XCTAssertThrowsError(try f.db.geneticSolutionDao.best(context: c, starsUsed: 0, study: s))
    }

    func testGrowingValidationAndDatabaseEditsReachTheAdviser() throws {
        let f = try fixture(), s = try study(f), c = try context(s, f), run = UUID()
        let plan = try candidate(1)
        let partial = GeneticCandidate(id: 1, generation: 1, strategy: plan.strategy,
                                       evaluations: [plan.evaluations[0]])
        try save([partial], in: f, study: s, run: run)
        XCTAssertTrue(try f.db.geneticSolutionDao.best(context: c, starsUsed: 0, study: s).isEmpty)
        try save([plan], in: f, study: s, run: run)
        XCTAssertEqual(try f.db.geneticSolutionDao.best(context: c, starsUsed: 0, study: s)[0].victories, 2)
        XCTAssertThrowsError(try save([partial], in: f, study: s, run: run))
        try execute("UPDATE ga_evaluation SET lives_remaining=19 WHERE ordinal=0", f)
        XCTAssertEqual(try f.db.geneticSolutionDao.best(context: c, starsUsed: 0, study: s)[0]
            .candidate.evaluations[0].result.livesRemaining, 19)
        let difficulty = try XCTUnwrap(f.db.difficultyDao.getAll().first { $0.id != s.difficulty.id })
        try f.db.difficultyDao.setSelected(difficultyID: difficulty.id)
        let changed = try study(f)
        XCTAssertTrue(try f.db.geneticSolutionDao.best(context: context(changed, f), starsUsed: 0, study: changed).isEmpty)
    }

    func testSeedRebuildRoundTripsWithoutSimulatorHistoryAndExportFailureIsReported() throws {
        let f = try fixture(), s = try study(f), c = try context(s, f), run = UUID()
        try save([try candidate(1)], in: f, study: s, run: run, panel: .training)
        try save([try candidate(1)], in: f, study: s, run: run)
        // Values must survive SQL export without decimal rounding.
        let exact = 1.2345678901234567
        try execute("UPDATE ga_evaluation SET seconds=\(exact) WHERE ordinal=0", f)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("genetic-seed-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let seed = directory.appendingPathComponent("solutions.sql")
        try f.db.geneticSolutionDao.exportSeed(to: seed)
        let rebuilt = try fixture()
        try execute("PRAGMA foreign_keys=ON; DELETE FROM genetic_solution; DELETE FROM simulator_run;", rebuilt)
        try execute(String(contentsOf: seed, encoding: .utf8), rebuilt)
        let result = try rebuilt.db.geneticSolutionDao.best(context: c, starsUsed: 0, study: s)
        XCTAssertEqual(result.map(\.runID), [run])
        XCTAssertEqual(result[0].candidate.strategy, try candidate(1).strategy)
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(rebuilt.connection,
            "SELECT count(*) FROM ga_evaluation WHERE seconds=1.2345678901234567", -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
        XCTAssertEqual(sqlite3_column_int(statement, 0), 2, "Seed export must preserve exact Double evidence")
        sqlite3_reset(statement)
        try execute(String(contentsOf: seed, encoding: .utf8), rebuilt)
        XCTAssertEqual(try rebuilt.db.geneticSolutionDao.best(context: c, starsUsed: 0, study: s).count, 1,
                       "The product seed is safe to load repeatedly")
        XCTAssertThrowsError(try f.db.geneticSolutionDao.exportSeed(to: directory.appendingPathComponent("missing/seed.sql")))
        XCTAssertEqual(try f.db.geneticSolutionDao.best(context: c, starsUsed: 0, study: s).count, 1)
    }
}
