import XCTest
import SQLite3
import CryptoKit
@testable import LevelEditorFormats

final class GeneticHeroTests: XCTestCase {
    private func fixture() throws -> AuthoredDatabaseFixture {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        try execute("DELETE FROM genetic_solution", fixture)
        return fixture
    }
    private func study(_ fixture: AuthoredDatabaseFixture, level: String = "Charleston") throws -> AuthoredMoneyStudy {
        try AuthoredMoneyStudy(db: fixture.db, levelID: XCTUnwrap(fixture.db.levelInfoDao.getIdBy(levelName: level)))
    }
    private func context(_ study: AuthoredMoneyStudy, _ fixture: AuthoredDatabaseFixture) throws -> GeneticSolutionContext {
        try GeneticSolutionContext(study: study, db: fixture.db, startingMoney: study.level.startingMoney,
                                   bountyFraction: 1, maxGameSeconds: 1800)
    }
    private func execute(_ sql: String, _ fixture: AuthoredDatabaseFixture) throws {
        guard sqlite3_exec(fixture.connection, sql, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(fixture.connection)))
        }
    }
    private func save(in fixture: AuthoredDatabaseFixture, study: AuthoredMoneyStudy) throws -> GeneticSolutionContext {
        let sample = GeneticEvaluation(seed: 1, result: SimulationResult(outcome: .victory, seconds: 600,
            livesRemaining: 5, goldRemaining: 10, goldEarned: 10, killed: 10, leaked: 0,
            fatesByTypeID: [:], waveMaxProgress: [], leaksByWave: []), wavesStarted: study.level.numWaves,
            waveEconomy: [], reinforcementDeployments: [], waveCalls: [])
        let candidate = GeneticCandidate(id: 1, generation: 0, starsUsed: 0,
            strategy: GeneticStrategy(decisions: [], metaUpgrades: []), evaluations: [sample])
        let value = try context(study, fixture)
        try fixture.db.geneticSolutionDao.saveBest([candidate], runID: UUID(), context: value,
            executableSHA256: String(repeating: "a", count: 64), panel: .validation,
            expectedSamples: 1, limitPerStar: 1, study: study)
        return value
    }

    @MainActor func testGAActuallyDeploysSelectedHeroesAndRecordsTheirDAOCombatStats() throws {
        let f = try fixture(), s = try study(f), ids = s.battle.chosenHeroes.ids
        XCTAssertEqual(ids.count, 2)
        let hero = try XCTUnwrap(s.battle.deployments.first?.hero.id)
        try execute("UPDATE hero_combat SET hp=hp+123 WHERE hero_id='\(hero.uuidString.lowercased())'", f)
        let updated = try study(f)
        let evaluation = try GeneticCommander.evaluate(GeneticStrategy(decisions: [], metaUpgrades: []),
            recording: .database(f.db.levelRunDao, .simulator), content: updated.battle,
            money: updated.level.startingMoney, seed: 1, maxSeconds: 1)
        let run = try f.db.levelRunDao.get(id: XCTUnwrap(evaluation.runID))
        let setup = try LevelRecordingCodec.decode(LevelReplaySetup.self, from: run.setup)
        XCTAssertTrue(setup.heroesEnabled)
        XCTAssertEqual(setup.heroes.map(\.id), ids)
        XCTAssertEqual(try XCTUnwrap(setup.heroCombat[hero]).hp, try XCTUnwrap(s.battle.heroCombat[hero]).hp + 123)
        let replay = try LevelReplayer(dao: f.db.levelRunDao, runID: run.id)
        XCTAssertTrue(try replay.advance())
        XCTAssertEqual(replay.frame?.heroes.count, 2, "Deployment must appear in the actual recorded engine frames")
        XCTAssertEqual(try f.db.heroDao.getSelectedHeroIds(), ids)
    }

    func testAdviserSeparatesChosenLineupsEvenWhenLevelDeploysOnlyPrimary() throws {
        let f = try fixture(), pair = try study(f, level: "Battle Road")
        XCTAssertEqual(pair.battle.chosenHeroes.ids.count, 2)
        XCTAssertEqual(pair.battle.deployments.count, 1)
        let pairContext = try save(in: f, study: pair)
        let ids = pair.battle.chosenHeroes.ids
        try f.db.heroDao.setSelectedHeroes(Array(ids.reversed()))
        XCTAssertEqual(try context(study(f, level: "Battle Road"), f), pairContext,
                       "Click order must not change database-ranked hero roles")
        try f.db.heroDao.setSelectedHeroes([ids[0]])
        let solo = try study(f, level: "Battle Road"), soloContext = try context(solo, f)
        XCTAssertEqual(solo.battle.deployments.map { $0.hero.id }, pair.battle.deployments.map { $0.hero.id })
        XCTAssertNotEqual(soloContext.contentSHA256, pairContext.contentSHA256)
        XCTAssertTrue(try f.db.geneticSolutionDao.best(context: soloContext, starsUsed: 0, study: solo).isEmpty)
        XCTAssertThrowsError(try f.db.geneticSolutionDao.best(context: pairContext, starsUsed: 0, study: solo))
        _ = try save(in: f, study: solo)
        XCTAssertEqual(try f.db.geneticSolutionDao.best(context: soloContext, starsUsed: 0, study: solo).count, 1)
        XCTAssertEqual(try f.db.geneticSolutionDao.best(context: pairContext, starsUsed: 0, study: pair).count, 1)
    }

    func testHeroStatsAISettingsAndMissingContentInvalidateAdvice() throws {
        let f = try fixture(), s = try study(f), c = try save(in: f, study: s)
        let deployment = try XCTUnwrap(c.heroLoadout?.deployments.first)
        try f.db.playerSettingsDao.setHeroAIEnabled(!deployment.aiEnabled, heroID: deployment.heroID)
        var changed = try study(f)
        var next = try context(changed, f)
        XCTAssertNotEqual(next, c)
        XCTAssertTrue(try f.db.geneticSolutionDao.best(context: next, starsUsed: 0, study: changed).isEmpty)
        try f.db.playerSettingsDao.setHeroAIEnabled(deployment.aiEnabled, heroID: deployment.heroID)
        XCTAssertEqual(try context(study(f), f), c)
        for sql in ["UPDATE hero_combat SET attack_rating=attack_rating+1",
                    "UPDATE hero_ai SET decision_interval=decision_interval+0.01"] {
            try execute(sql, f)
            changed = try study(f)
            next = try context(changed, f)
            XCTAssertNotEqual(next.contentSHA256, c.contentSHA256)
            XCTAssertTrue(try f.db.geneticSolutionDao.best(context: next, starsUsed: 0, study: changed).isEmpty)
        }
        try execute("DELETE FROM hero_combat WHERE hero_id='\(deployment.heroID.uuidString.lowercased())'", f)
        XCTAssertThrowsError(try study(f))
    }

    func testHeroExperimentSelectionUsesDAOsWithoutChangingPlayerSelection() throws {
        let f = try fixture(), s = try study(f), original = s.battle.chosenHeroes.ids
        let alternative = try XCTUnwrap(f.db.heroDao.getAll().first { $0.unlocked && !original.contains($0.id) })
        let copy = try BountyExperimentDAO.contentCopy(of: f.db, fraction: 1, selectedHeroIDs: [alternative.id])
        defer { copy.close() }
        let selected = try AuthoredMoneyStudy(db: copy, levelID: s.level.id)
        XCTAssertEqual(selected.battle.chosenHeroes.ids, [alternative.id])
        XCTAssertEqual(selected.battle.deployments.map { $0.hero.id }, [alternative.id])
        XCTAssertEqual(try f.db.heroDao.getSelectedHeroIds(), original)
        for invalid in [[UUID()], [], [original[0], original[0]]] {
            XCTAssertThrowsError(try BountyExperimentDAO.contentCopy(of: f.db, fraction: 1, selectedHeroIDs: invalid))
        }
        XCTAssertEqual(try f.db.heroDao.getSelectedHeroIds(), original)
    }

    func testExplicitHeroAIExperimentDoesNotChangePlayerControls() throws {
        let f = try fixture(), s = try study(f)
        let before = try f.db.playerSettingsDao.getHeroControls()
        let modes = Dictionary(uniqueKeysWithValues: s.battle.chosenHeroes.ids.map { ($0, true) })
        let copy = try BountyExperimentDAO.contentCopy(of: f.db, fraction: 1,
            selectedHeroIDs: s.battle.chosenHeroes.ids, heroAI: modes)
        defer { copy.close() }
        let enabled = try GeneticHeroLoadout(content: AuthoredMoneyStudy(db: copy, levelID: s.level.id).battle)
        XCTAssertTrue(enabled.deployments.allSatisfy(\.aiEnabled))
        XCTAssertEqual(try f.db.playerSettingsDao.getHeroControls(), before)
        XCTAssertThrowsError(try BountyExperimentDAO.contentCopy(of: f.db, fraction: 1, heroAI: [UUID(): true]))
    }

    @MainActor func testReplayRestoresRecordedLineupAndRejectsChangedHeroContent() throws {
        let f = try fixture(), s = try study(f)
        let strategy = GeneticStrategy(decisions: [], metaUpgrades: [])
        let expected = try GeneticCommander.evaluate(strategy, recording: .preview, content: s.battle,
            money: s.level.startingMoney, seed: 1, maxSeconds: 1)
        let snapshot = try s.replaySnapshot(db: f.db, heroesEnabled: true)
        XCTAssertEqual(snapshot, try study(f).replaySnapshot(db: f.db, heroesEnabled: true))
        let document = GeneticReplayDocument(format: "genetic-replay-v6",
            contentSHA256: SHA256.hash(data: snapshot).map { String(format: "%02x", $0) }.joined(),
            executableSHA256: String(repeating: "a", count: 64), money: s.level.startingMoney,
            maxGameSeconds: 1, starsUsed: 0, bountyFraction: 1,
            heroLoadout: try GeneticHeroLoadout(content: s.battle), strategy: strategy, expected: expected)
        let solo = [s.battle.chosenHeroes.primary.id]
        try f.db.heroDao.setSelectedHeroes(solo)
        XCTAssertEqual(try document.loadStudy(db: f.db, levelName: "Charleston").battle.chosenHeroes.ids, s.battle.chosenHeroes.ids)
        XCTAssertEqual(try f.db.heroDao.getSelectedHeroIds(), solo)
        try execute("UPDATE hero_combat SET hp=hp+1", f)
        XCTAssertThrowsError(try document.loadStudy(db: f.db, levelName: "Charleston"))
    }

    func testLegacyNoHeroRowsCannotServeAdviceAndNewRowsRequireHeroMetadata() throws {
        let f = try fixture(), s = try study(f), c = try save(in: f, study: s)
        XCTAssertNotEqual(sqlite3_exec(f.connection,
            "UPDATE genetic_solution SET solution_json=json_remove(solution_json,'$.context.heroLoadout')", nil, nil, nil), SQLITE_OK)
        try execute("UPDATE genetic_solution SET solution_json=json_remove(json_set(solution_json,'$.formatVersion',1,'$.heroesEnabled',json('false')),'$.context.heroLoadout')", f)
        XCTAssertTrue(try f.db.geneticSolutionDao.best(context: c, starsUsed: 0, study: s).isEmpty,
                      "Even a matching hash must never promote a no-hero result")
        let seed = FileManager.default.temporaryDirectory.appendingPathComponent("legacy-heroes-\(UUID()).sql")
        defer { try? FileManager.default.removeItem(at: seed) }
        XCTAssertNoThrow(try f.db.geneticSolutionDao.exportSeed(to: seed))
        try execute("PRAGMA ignore_check_constraints=ON; UPDATE genetic_solution SET solution_json=json_set(solution_json,'$.formatVersion',2,'$.heroesEnabled',json('true'))", f)
        XCTAssertThrowsError(try f.db.geneticSolutionDao.best(context: c, starsUsed: 0, study: s))
    }
}
