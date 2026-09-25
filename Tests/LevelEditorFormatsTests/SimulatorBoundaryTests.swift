import XCTest
import SQLite3
@testable import LevelEditorFormats

final class SimulatorBoundaryTests: XCTestCase {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    func testSimulatorDatabaseAccessStaysBehindDAOs() throws {
        let simulator = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Simulator").path)
            .filter { $0.hasSuffix(".swift") }.map { "Simulator/" + $0 }
        let paths = simulator + ["Engine/Design/AuthoredMoneyStudy.swift", "Engine/Design/AuthoredMoneyStudy+Replay.swift",
            "Engine/Design/GeneticStrategy.swift", "Engine/Design/BalanceAnalysis.swift",
            "Engine/Design/GeneticReplay.swift", "Engine/Design/GeneticSolution.swift",
            "Engine/Design/GeneticHeroLoadout.swift", "Engine/Design/GeneticSolutionPlayback.swift", "Engine/Models/GameSimulation.swift",
            "Engine/Models/BattleEngine+Recording.swift", "Engine/Models/LevelRecording.swift",
            "Engine/Models/LevelReplayTimeline.swift", "Engine/Models/ReplayTimelineEncoder.swift", "Engine/Models/LevelReplayer.swift"]
        for path in paths {
            let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            for forbidden in ["import SQLite3", "sqlite3_", "db.conn", "db.connection"] {
                XCTAssertFalse(source.contains(forbidden), "\(path) bypasses a DAO: \(forbidden)")
            }
            XCTAssertNil(source.range(of: #"\b(SELECT\s+.+\s+FROM|INSERT\s+INTO|UPDATE\s+\w+\s+SET|DELETE\s+FROM)\b"#,
                                      options: [.regularExpression, .caseInsensitive]), path)
        }
    }

    func testNoAlternateCombatImplementationOrUnreviewedSimulatorEntryPoint() throws {
        for path in ["Engine/Models/Simulation.swift", "Simulator/GPUSweep.swift", "Simulator/SimKernel.metal",
                     "Simulator/SimGPUTypes.h", "Simulator/Sweep.swift", "Simulator/SupplySupportValidation.swift"] {
            XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path), path)
        }
        let sources = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Simulator").path)
            .filter { ["swift", "metal", "h", "m", "mm", "c", "cpp"].contains(($0 as NSString).pathExtension) }
        XCTAssertEqual(Set(sources), Set(["main.swift", "AuthoredMoneySweep.swift", "GeneticStudy.swift", "GeneticWorkers.swift", "BalanceStudy.swift", "SimulatorStore.swift", "BuildVersion.swift"]),
                       "Every new simulator source requires a boundary audit; no alternate combat backend is permitted")
        let driverPaths = sources.map { "Simulator/" + $0 } + ["LevelEditor/SimSession.swift"]
        for path in driverPaths {
            let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            XCTAssertNil(source.range(of: #"\bSimulation\s*\("#, options: .regularExpression), path)
            for forbidden in ["sim.engine", "BattleEngine(", "MTLCreateSystemDefaultDevice", "import Metal"] {
                XCTAssertFalse(source.contains(forbidden), "\(path) bypasses the input/result boundary: \(forbidden)")
            }
        }
    }

    func testGeneticSearchOwnsOnlyPlayerIntentAndWholeBattleScoring() throws {
        // Ownership audit: the coordinator breeds/records plans; the commander
        // chooses commands. Neither has access to mutable battle internals.
        for path in ["Engine/Design/GeneticStrategy.swift", "Engine/Design/GeneticMetaSearch.swift", "Engine/Design/GeneticMetaPopulation.swift",
                     "Engine/Design/ReinforcementStrategy.swift", "Engine/Design/EarlyWaveStrategy.swift",
                     "Engine/Design/GeneticReplay.swift", "Engine/Design/BalanceAnalysis.swift",
                     "Simulator/GeneticStudy.swift", "Simulator/GeneticWorkers.swift", "Simulator/BalanceStudy.swift"] {
            let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            for forbidden in ["sim.engine", "BattleEngine(", "buildTower(", "upgradeSelectedTower(",
                "applyImpact", "applyMorale", "shotMinDamage", "shotMaxDamage", "enemyHPMultiplier:",
                "gold +=", "money -=", "hp -=", "wave.startTime", "SimClock.dt"] {
                XCTAssertFalse(source.contains(forbidden), "\(path) duplicates or bypasses gameplay: \(forbidden)")
            }
        }
        let commander = try String(contentsOf: root.appendingPathComponent("Engine/Design/GeneticStrategy.swift"), encoding: .utf8)
        XCTAssertTrue(commander.contains("sim.execute(decision.step.action)"))
        XCTAssertTrue(commander.contains("sim.stepPaced()"))
        XCTAssertTrue(commander.contains("let outcome = sim.result()"))
        XCTAssertTrue(commander.contains("while sim.outcome == nil, sim.time < maxSeconds"))
        // Worker ownership audit: independent processes transport player DNA,
        // validate the DAO snapshot, and invoke the existing evaluation entry.
        let workers = try String(contentsOf: root.appendingPathComponent("Simulator/GeneticWorkers.swift"), encoding: .utf8)
        XCTAssertTrue(workers.contains("GeneticCommander.evaluate("))
        XCTAssertTrue(workers.contains("digest == configuration.contentSHA256"))
        XCTAssertTrue(workers.contains("configuration.executableSHA256"))
        XCTAssertTrue(workers.contains(".database(db.levelRunDao, .simulator)"))
        XCTAssertFalse(workers.contains(".preview"))
        XCTAssertFalse(workers.contains(".terminate()"))
        let reinforcement = try String(contentsOf: root.appendingPathComponent("Engine/Design/ReinforcementStrategy.swift"), encoding: .utf8)
        XCTAssertTrue(reinforcement.contains("sim.canCallReinforcements"))
        XCTAssertTrue(reinforcement.contains("sim.perform(.reinforcements(point:"))
        for forbidden in ["ReinforcementSchedule(", "reinforcementStats", "cooldownSeconds", "timeToLiveSeconds", "reinforcementSoldierCount"] {
            XCTAssertFalse(reinforcement.contains(forbidden), "Reinforcement driver owns gameplay: \(forbidden)")
        }
        let calls = try String(contentsOf: root.appendingPathComponent("Engine/Design/EarlyWaveStrategy.swift"), encoding: .utf8)
        XCTAssertTrue(calls.contains("sim.canStartWave"))
        XCTAssertTrue(calls.contains("sim.perform(.startWave)"))
        for forbidden in ["WaveStartSchedule(", "callButtonDelay", "autoStartCountdown", "earlyCallBonus", "wave.startTime"] {
            XCTAssertFalse(calls.contains(forbidden), "Early-wave driver owns gameplay: \(forbidden)")
        }
    }

    func testHeadlessAdapterDoesNotComputeOrMutateGameplay() throws {
        let source = try String(contentsOf: root.appendingPathComponent("Engine/Models/GameSimulation.swift"), encoding: .utf8)
        for forbidden in ["gold >=", "money >=", "money -=", "gold +=", ".stats.", "shotMinDamage",
                          "shotMaxDamage", "splashCoverPierce", "applyMorale", "applyImpact", "pathDistance",
                          "advanceWalkers", "wave.startTime", "hp -=", "case .victory", "case .defeat"] {
            XCTAssertFalse(source.contains(forbidden), "Gameplay leaked into the input driver: \(forbidden)")
        }
        XCTAssertTrue(source.contains("engine.perform(command)"))
        XCTAssertTrue(source.contains("engine.simulationResult()"))
        let game = try String(contentsOf: root.appendingPathComponent("Liberty Line/LevelRunner.swift"), encoding: .utf8)
        XCTAssertTrue(game.contains("class LevelRunner: BattleEngine"))
    }

    func testCommandDriverCannotBypassPlayerHandlersOrSupplySeparateTuning() throws {
        let commands = try String(contentsOf: root.appendingPathComponent("Engine/Models/BattleCommands.swift"), encoding: .utf8)
        for forbidden in ["return buildTower(", "return upgradeSelectedTower(", "return purchaseTowerUpgrade(",
                          "return callReinforcements(", "money >=", "waveSchedule.state(at:"] {
            XCTAssertFalse(commands.contains(forbidden), "Command bypasses the player handler: \(forbidden)")
        }
        for handler in ["tapBuildButton", "tapUpgradeButton", "tapUpgradePath", "placeDemolition", "placeEngineerObstacles",
                        "placeRallyPoint", "commandSelectedHero", "placeReinforcements", "startNextWave"] {
            XCTAssertTrue(commands.contains(handler + "("), "Missing shared player handler: \(handler)")
        }
        XCTAssertTrue(commands.contains("CallWaveButtonSelection()"))
        XCTAssertTrue(commands.contains("selection.tap(point, for: nextWaveNumber)"))
        for path in ["Engine/Models/GameSimulation.swift", "Liberty Line/LevelRunner.swift"] {
            let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            XCTAssertFalse(source.contains("enemyHPMultiplier:"), path)
            XCTAssertFalse(source.contains("metaUpgrades:"), path)
            XCTAssertTrue(source.contains("advance(ticks:"), path)
        }
    }

    @MainActor func testEngineRejectsInvalidAndUnaffordableCommandsWithoutMutatingBattle() throws {
        let content = try BattleTestFixture.authored()
        let sim = try GameSimulation(recording: .preview, content: content, startingMoney: 1, heroesEnabled: false, seed: 1)
        for command in [BattleCommand.build(slot: -1, kind: .ranged), .upgrade(slot: 0, branch: 1),
                        .purchaseUpgrade(slot: 0, pathID: "missing"), .placeDemolition(slot: 0, point: .zero),
                        .placeObstacles(slot: 0, point: .zero), .rally(slot: 0, point: .zero),
                        .moveHero(id: UUID(), point: .zero)] {
            XCTAssertEqual(sim.perform(command), .invalid)
        }
        XCTAssertEqual(sim.perform(.build(slot: 0, kind: .ranged)), .needGold)
        XCTAssertEqual(sim.gold, 1)
        XCTAssertTrue(sim.towers.isEmpty)
        XCTAssertEqual(sim.lives, content.level.numStartingLives)
    }

    @MainActor func testHeadlessVictoryRewardDoesNotDependOnPersistenceCallback() throws {
        let source = try BattleTestFixture.authored()
        let enemy = try XCTUnwrap(source.enemies.first)
        var level = BattleTestFixture.level(enemy: enemy, slots: [], waveTimes: [0])
        level.waves[0].spawns = []
        let content = try BattleTestFixture.content(level: level, enemies: [enemy], base: source)
        let sim = try GameSimulation(recording: .preview, content: content, startingMoney: nil, heroesEnabled: false, seed: 1)
        let player = try BattleEngine(recording: .preview, content: content, heroesEnabled: false,
            startingMoneyOverride: nil, seed: 1, onVictory: { _, _ in 999 })
        sim.startNextWave(); player.startNextWave()
        sim.step(); player.advance(ticks: 1, interpolation: 0)
        XCTAssertEqual(sim.outcome, .victory)
        XCTAssertEqual(sim.earnedMetaStars, 3)
        XCTAssertEqual(sim.earnedMetaStars, player.earnedMetaStars)
    }

    @MainActor func testDatabaseChangesAndMissingContentReachTheSharedEntryPoint() throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let original = try BattleTestFixture.authored(db: fixture.db)
        XCTAssertEqual(sqlite3_exec(fixture.connection, "UPDATE tower SET shot_min_damage=shot_min_damage+11, shot_max_damage=shot_max_damage+11 WHERE attack_mode='direct'", nil, nil, nil), SQLITE_OK)
        let changed = try BattleTestFixture.authored(db: fixture.db)
        let before = try GameSimulation(recording: .preview, content: original, startingMoney: nil, heroesEnabled: false, seed: 1)
        let after = try GameSimulation(recording: .preview, content: changed, startingMoney: nil, heroesEnabled: false, seed: 1)
        XCTAssertEqual(before.perform(.build(slot: 0, kind: .ranged)), .ok)
        XCTAssertEqual(after.perform(.build(slot: 0, kind: .ranged)), .ok)
        XCTAssertEqual(try XCTUnwrap(after.towers.first).tuning.shotMinDamage,
                       try XCTUnwrap(before.towers.first).tuning.shotMinDamage + 11)
        XCTAssertEqual(sqlite3_exec(fixture.connection, "DELETE FROM tower WHERE tower_level=1 AND attack_mode='direct'", nil, nil, nil), SQLITE_OK)
        XCTAssertThrowsError(try BattleTestFixture.authored(db: fixture.db))
    }
}
