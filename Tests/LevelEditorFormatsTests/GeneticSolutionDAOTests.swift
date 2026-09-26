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
        try execute("UPDATE genetic_solution SET solution_json=json_remove(solution_json,'$.candidate.strategy.reinforcements')", f)
        XCTAssertThrowsError(try f.db.geneticSolutionDao.best(context: c, starsUsed: 0, study: s))
        try execute("UPDATE genetic_solution SET solution_json=json_set(solution_json,'$.candidate.evaluations',json('[]'))", f)
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
        try execute("UPDATE genetic_solution SET solution_json=json_set(solution_json,'$.candidate.evaluations[0].result.livesRemaining',19)", f)
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
        // Export must retain the stored evidence bytes, including formatting.
        // Codable dictionaries with non-String keys can reorder on re-encoding.
        try execute("UPDATE genetic_solution SET solution_json=solution_json || ' '", f)
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
            "SELECT count(*) FROM genetic_solution WHERE substr(solution_json,-1)=' '", -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
        XCTAssertEqual(sqlite3_column_int(statement, 0), 2, "Seed export must not re-encode evidence")
        sqlite3_reset(statement)
        try execute(String(contentsOf: seed, encoding: .utf8), rebuilt)
        XCTAssertEqual(try rebuilt.db.geneticSolutionDao.best(context: c, starsUsed: 0, study: s).count, 1,
                       "The product seed is safe to load repeatedly")
        XCTAssertThrowsError(try f.db.geneticSolutionDao.exportSeed(to: directory.appendingPathComponent("missing/seed.sql")))
        XCTAssertEqual(try f.db.geneticSolutionDao.best(context: c, starsUsed: 0, study: s).count, 1)
    }
}
