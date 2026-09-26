import XCTest
import SQLite3
@testable import LevelEditorFormats

@MainActor final class GeneticSolutionPlaybackTests: XCTestCase {
    private func execute(_ sql: String, _ f: AuthoredDatabaseFixture) throws {
        guard sqlite3_exec(f.connection, sql, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(f.connection)))
        }
    }

    private func winner() throws -> (AuthoredDatabaseFixture, GeneticSolution) {
        let f = try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        // A small, explicitly authored mutation fixture guarantees a victory
        // without changing production combat or depending on the GA catalog.
        try execute("""
            DELETE FROM genetic_solution;
            UPDATE level_info SET num_starting_lives=10000;
            UPDATE level_wave SET call_button_delay=0,auto_start_countdown=0;
            UPDATE level_wave_enemy_spawn SET num_enemies=1,spawn_time_since_previous_spawn=0;
            """, f)
        let id = try XCTUnwrap(f.db.levelInfoDao.getIdBy(levelName: "Charleston"))
        let study = try AuthoredMoneyStudy(db: f.db, levelID: id)
        let strategy = GeneticStrategy(decisions: [], metaProgression: try AuthoredDatabaseFixture.metaProgression([]), reinforcements: .immediate)
        let evaluation = try GeneticCommander.evaluate(strategy, recording: .preview, content: study.battle,
            money: study.level.startingMoney, seed: 919, maxSeconds: 1800)
        XCTAssertEqual(evaluation.result.outcome, .victory)
        let context = try GeneticSolutionContext(study: study, db: f.db,
            startingMoney: study.level.startingMoney, bountyFraction: 1, maxGameSeconds: 1800)
        let candidate = GeneticCandidate(id: 1, generation: 1, strategy: strategy, evaluations: [evaluation])
        try f.db.geneticSolutionDao.saveBest([candidate], runID: UUID(), context: context,
            executableSHA256: String(repeating: "a", count: 64), panel: .validation,
            expectedSamples: 1, limitPerStar: 5, study: study)
        return (f, try XCTUnwrap(GeneticSolutionPlayback.best(db: f.db, levelID: id, difficultyID: study.difficulty.id)))
    }

    func testLiveSpeedChangesPauseAndFractionalFramesPreserveWinningBattle() throws {
        let (f, solution) = try winner()
        let settings = try f.db.playerSettingsDao.get()
        let difficulty = try f.db.difficultyDao.requireSelected()
        let selection = try HeroSelectionStore(dao: f.db.heroDao).load()
        for hero in try XCTUnwrap(solution.context.heroLoadout).deployments {
            try f.db.playerSettingsDao.setHeroAIEnabled(!hero.aiEnabled, heroID: hero.heroID)
        }
        let controls = try f.db.playerSettingsDao.getHeroControls()
        let player = try GeneticSolutionPlayback(solution: solution, db: f.db)
        XCTAssertEqual(try GeneticHeroLoadout(content: player.engine.content), solution.context.heroLoadout)
        XCTAssertEqual(player.engine.money, solution.context.startingMoney)
        try player.advance(wallSeconds: SimClock.dt / 2)
        XCTAssertEqual(player.engine.timer.tick, 0)
        player.togglePause()
        try player.advance(wallSeconds: 90)
        XCTAssertEqual(player.engine.timer.tick, 0)
        player.setSpeed(try PlaySpeed(8))
        player.togglePause()
        try player.advance(wallSeconds: SimClock.dt / 16)
        XCTAssertEqual(player.engine.timer.tick, 1)
        var frame = 0
        let speeds = try [0.5, 1, 2, 4, 8].map(PlaySpeed.init)
        while !player.isFinished {
            if frame % 17 == 0 { player.setSpeed(speeds[(frame / 17) % speeds.count]) }
            try player.advance(wallSeconds: frame % 3 == 0 ? 0.037 : 0.19)
            frame += 1
        }
        XCTAssertEqual(player.engine.outcome, .victory)
        XCTAssertEqual(player.engine.simulationResult(), player.expected.result)
        let finalTick = player.engine.timer.tick
        try player.advance(wallSeconds: 100)
        XCTAssertEqual(player.engine.timer.tick, finalTick)
        XCTAssertEqual(try f.db.playerSettingsDao.get(), settings)
        XCTAssertEqual(try f.db.playerSettingsDao.getHeroControls(), controls)
        XCTAssertEqual(try f.db.difficultyDao.requireSelected().id, difficulty.id)
        XCTAssertEqual(try HeroSelectionStore(dao: f.db.heroDao).load().ids, selection.ids)
    }

    func testPreviewExcludesWrongDifficultyStaleMoneyAndChangedContent() throws {
        let (f, solution) = try winner()
        let context = solution.context
        XCTAssertNil(try GeneticSolutionPlayback.best(db: f.db, levelID: context.levelID, difficultyID: UUID()))
        try execute("UPDATE level_info SET starting_money=starting_money+1", f)
        XCTAssertNil(try GeneticSolutionPlayback.best(db: f.db, levelID: context.levelID, difficultyID: context.difficultyID))
        XCTAssertThrowsError(try GeneticSolutionPlayback(solution: solution, db: f.db))
        try execute("UPDATE level_info SET starting_money=starting_money-1; UPDATE tower SET cost=cost+1", f)
        XCTAssertNil(try GeneticSolutionPlayback.best(db: f.db, levelID: context.levelID, difficultyID: context.difficultyID))
        try execute("DELETE FROM combat_rules", f)
        XCTAssertThrowsError(try GeneticSolutionPlayback.best(db: f.db, levelID: context.levelID, difficultyID: context.difficultyID))
    }
}
