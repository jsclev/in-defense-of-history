import XCTest
@testable import LevelEditorFormats

final class BattleAPIParityTests: XCTestCase {
    @MainActor func testReinforcementsUsePlayerPlacementValidation() throws {
        let content = try BattleTestFixture.authored()
        let sim = try GameSimulation(recording: .preview, content: content, startingMoney: nil, heroesEnabled: true, seed: 1776)
        let player = try GameSimulation(recording: .preview, content: content, startingMoney: nil, heroesEnabled: true, seed: 1776).engine
        let offRoad = CGPoint(x: -10000, y: -10000)
        player.toggleReinforcementPlacement()
        player.placeReinforcements(at: offRoad)
        XCTAssertTrue(player.garrisonsBySlot.isEmpty)
        XCTAssertEqual(sim.perform(.reinforcements(point: Point(offRoad.x, offRoad.y))), .invalid)
        XCTAssertTrue(sim.engine.garrisonsBySlot.isEmpty, "A simulated player cannot deploy off the road")
        XCTAssertEqual(sim.engine.reinforcementCooldown, player.reinforcementCooldown)
        let road = try XCTUnwrap(content.level.paths.first).point(atDistance: 200)
        XCTAssertEqual(player.placeReinforcements(at: CGPoint(x: road.x, y: road.y)), .ok)
        XCTAssertEqual(sim.perform(.reinforcements(point: road)), .ok)
        XCTAssertEqual(sim.engine.reinforcementCooldown, player.reinforcementCooldown)
        XCTAssertEqual(sim.engine.garrisonsBySlot.keys.sorted(), player.garrisonsBySlot.keys.sorted())
    }

    @MainActor func testDisplayFramePartitionDoesNotChangeBattle() throws {
        let content = try BattleTestFixture.authored()
        let sim = try GameSimulation(recording: .preview, content: content, startingMoney: 1000, heroesEnabled: true, seed: 1776)
        let player = try GameSimulation(recording: .preview, content: content, startingMoney: 1000, heroesEnabled: true, seed: 1776).engine
        for (slot, kind) in [(17, TowerKind.ranged), (14, .areaOfEffect), (4, .melee), (0, .supply)] {
            XCTAssertEqual(sim.perform(.build(slot: slot, kind: kind)), .ok)
            player.selectSlot(slot); player.tapBuildButton(kind); player.tapBuildButton(kind)
        }
        sim.startNextWave(); player.startNextWave()
        for block in 0..<225 {
            // Real display callbacks can contain no tick, one tick or several
            // catch-up ticks. Fractional time may only affect presentation.
            if block % 2 == 0 {
                for _ in 0..<4 {
                    player.advance(ticks: 0, interpolation: 0.5)
                    player.advance(ticks: 1, interpolation: 0)
                }
            } else {
                player.advance(ticks: 4, interpolation: 0)
            }
            for _ in 0..<4 { sim.step() }
        }
        XCTAssertEqual(player.timer.tick, sim.engine.timer.tick)
        XCTAssertEqual(player.money, sim.gold)
        XCTAssertEqual(player.lives, sim.lives)
        XCTAssertEqual(player.walkers.map(\.id), sim.engine.walkers.map(\.id))
        XCTAssertEqual(player.walkers.map(\.hp), sim.engine.walkers.map(\.hp))
        XCTAssertEqual(player.walkers.map(\.pathDistance), sim.engine.walkers.map(\.pathDistance))
        XCTAssertEqual(player.walkers.map { $0.morale.value }, sim.engine.walkers.map { $0.morale.value })
        XCTAssertEqual(player.shotsByMode, sim.shotsByMode)
        XCTAssertEqual(player.goldEarned, sim.engine.goldEarned)
        XCTAssertEqual(player.killedCount, sim.engine.killedCount)
        XCTAssertEqual(player.heroPosts.map { $0.unit.position }, sim.engine.heroPosts.map { $0.unit.position })
        XCTAssertEqual(player.heroPosts.map { $0.unit.hp }, sim.engine.heroPosts.map { $0.unit.hp })
        XCTAssertEqual(player.nextFireTickBySlot, sim.engine.nextFireTickBySlot)
        XCTAssertEqual(player.projectiles.map(\.position), sim.engine.projectiles.map(\.position))
    }

    @MainActor func testUnaffordablePurchasesFollowTheSameConfirmationAndMenuState() throws {
        let content = try BattleTestFixture.authored()
        let sim = try GameSimulation(recording: .preview, content: content, startingMoney: 1, heroesEnabled: false, seed: 1)
        let player = try BattleEngine(recording: .preview, content: content, heroesEnabled: false,
            startingMoneyOverride: 1, seed: 1, onVictory: { _, _ in 0 })
        player.selectSlot(0)
        XCTAssertNil(player.tapBuildButton(.ranged))
        XCTAssertEqual(player.tapBuildButton(.ranged), .needGold)
        XCTAssertEqual(sim.perform(.build(slot: 0, kind: .ranged)), .needGold)
        XCTAssertEqual(player.selectedSlotIndex, sim.engine.selectedSlotIndex)
        XCTAssertEqual(player.armedBuildKind, sim.engine.armedBuildKind)
        XCTAssertEqual(player.money, sim.gold)
        XCTAssertNil(player.selectedSlotIndex, "The game closes an unaffordable confirmation")
    }

    @MainActor func testEndTimeAndOutcomeAreIndependentOfDisplayCatchUp() throws {
        let source = try BattleTestFixture.authored()
        var enemy = try XCTUnwrap(source.enemies.first)
        enemy.stats.speed = 3000
        var level = BattleTestFixture.level(enemy: enemy, slots: [])
        level.numStartingLives = 1
        let content = try BattleTestFixture.content(level: level, enemies: [enemy], base: source)
        let sim = try GameSimulation(recording: .preview, content: content, startingMoney: nil, heroesEnabled: false, seed: 1)
        let player = try BattleEngine(recording: .preview, content: content, heroesEnabled: false,
            startingMoneyOverride: nil, seed: 1, onVictory: { _, _ in 0 })
        sim.startNextWave(); player.startNextWave()
        while sim.outcome == nil { sim.step() }
        player.advance(ticks: 48, interpolation: 0.75)
        XCTAssertEqual(player.outcome, .defeat)
        XCTAssertEqual(player.elapsedTime, sim.time)
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        XCTAssertEqual(try encoder.encode(player.simulationResult()), try encoder.encode(sim.result()))
    }

    @MainActor func testPauseAndSpeedDoNotCreateASecondCombatClock() throws {
        let content = try BattleTestFixture.authored()
        let sim = try GameSimulation(recording: .preview, content: content, startingMoney: nil, heroesEnabled: true, seed: 1)
        sim.engine.pause()
        XCTAssertEqual(sim.perform(.build(slot: 0, kind: .ranged)), .invalid)
        sim.engine.selectSlot(0)
        XCTAssertEqual(sim.engine.tapBuildButton(.ranged), .invalid)
        sim.step()
        XCTAssertEqual(sim.time, 0)
        sim.engine.resume(); sim.engine.speedUp()
        sim.step()
        XCTAssertEqual(sim.time, SimClock.dt, "Speed changes wall-clock scheduling, never a combat tick")
    }

    @MainActor func testCommandDispatchUsesTheExactInteractivePurchaseCallOrder() throws {
        let content = try BattleTestFixture.authored()
        let scripted = try InputTraceEngine(recording: .preview, content: content, heroesEnabled: false,
            startingMoneyOverride: 100_000, seed: 1, onVictory: { _, _ in 0 })
        let player = try InputTraceEngine(recording: .preview, content: content, heroesEnabled: false,
            startingMoneyOverride: 100_000, seed: 1, onVictory: { _, _ in 0 })
        XCTAssertEqual(scripted.perform(.build(slot: 0, kind: .ranged)), .ok)
        player.dismissMenu(); player.selectSlot(0)
        player.tapBuildButton(.ranged); player.tapBuildButton(.ranged)
        XCTAssertEqual(scripted.calls, player.calls)
        XCTAssertEqual(scripted.calls, ["dismiss", "selectSlot", "tapBuild", "tapBuild", "commitBuild"])
        for _ in 2...4 {
            scripted.calls = []; player.calls = []
            XCTAssertEqual(scripted.perform(.upgrade(slot: 0, branch: 1)), .ok)
            player.dismissMenu(); player.selectPlacedTower(atSlot: 0)
            player.tapUpgradeButton(branch: 1); player.tapUpgradeButton(branch: 1)
            XCTAssertEqual(scripted.calls, player.calls)
            XCTAssertEqual(scripted.calls, ["dismiss", "selectTower", "tapUpgrade", "tapUpgrade", "commitUpgrade"])
        }
        let path = try XCTUnwrap(player.towerLevel(for: XCTUnwrap(player.placedTower(atSlot: 0)))?.upgradePaths.first)
        scripted.calls = []; player.calls = []
        XCTAssertEqual(scripted.perform(.purchaseUpgrade(slot: 0, pathID: path.id)), .ok)
        player.dismissMenu(); player.selectPlacedTower(atSlot: 0)
        player.tapUpgradePath(path.id); player.tapUpgradePath(path.id)
        XCTAssertEqual(scripted.calls, player.calls)
        XCTAssertEqual(scripted.calls, ["dismiss", "selectTower", "tapAbility", "tapAbility", "commitAbility"])
    }

    @MainActor func testMapCommandsUseTheSameSelectionAndPlacementHandlers() throws {
        let content = try BattleTestFixture.authored()
        let sim = try GameSimulation(recording: .preview, content: content, startingMoney: 100_000, heroesEnabled: true, seed: 1)
        let player = try BattleEngine(recording: .preview, content: content, heroesEnabled: true,
            startingMoneyOverride: 100_000, seed: 1, onVictory: { _, _ in 0 })
        let offMap = Point(-10000, -10000)
        let special = try XCTUnwrap(content.arsenal.towers.first { $0.kind == .special })
        let base = try XCTUnwrap(special.tiers.first { $0.level == 1 })
        let slot = try XCTUnwrap(content.level.towerSlots.indices.first { index in
            let p = content.level.towerSlots[index].position
            let origin = CGPoint(x: p.x, y: p.y)
            return base.tuning.attackRange.nearestPathPoint(to: origin, from: origin, paths: content.level.paths) != nil
        })
        XCTAssertEqual(sim.perform(.build(slot: slot, kind: .special)), .ok)
        player.selectSlot(slot); player.tapBuildButton(.special); player.tapBuildButton(.special)
        let site = try XCTUnwrap(player.placedTower(atSlot: slot)?.engineerObstaclePosition)
        for point in [offMap, Point(site.x, site.y)] {
            player.dismissMenu(); player.selectPlacedTower(atSlot: slot); player.beginEngineerObstaclePlacement()
            XCTAssertEqual(sim.perform(.placeObstacles(slot: slot, point: point)),
                           player.placeEngineerObstacles(at: CGPoint(x: point.x, y: point.y)))
            XCTAssertEqual(sim.engine.placedTower(atSlot: slot)?.engineerObstaclePosition,
                           player.placedTower(atSlot: slot)?.engineerObstaclePosition)
        }
        for tier in 2...4 {
            let branch = tier == 4 ? 3 : 1
            XCTAssertEqual(sim.perform(.upgrade(slot: slot, branch: branch)), .ok)
            player.dismissMenu(); player.selectPlacedTower(atSlot: slot)
            player.tapUpgradeButton(branch: branch); player.tapUpgradeButton(branch: branch)
        }
        for point in [offMap, Point(site.x, site.y)] {
            player.dismissMenu(); player.selectPlacedTower(atSlot: slot); player.beginDemolitionPlacement()
            XCTAssertEqual(sim.perform(.placeDemolition(slot: slot, point: point)),
                           player.placeDemolition(at: CGPoint(x: point.x, y: point.y)))
            XCTAssertEqual(sim.engine.placedTower(atSlot: slot)?.demolitionCharge,
                           player.placedTower(atSlot: slot)?.demolitionCharge)
        }
        let meleeSlot = try XCTUnwrap(content.level.towerSlots.indices.first { $0 != slot })
        XCTAssertEqual(sim.perform(.build(slot: meleeSlot, kind: .melee)), .ok)
        player.selectSlot(meleeSlot); player.tapBuildButton(.melee); player.tapBuildButton(.melee)
        for point in [offMap, content.level.towerSlots[meleeSlot].position] {
            player.dismissMenu(); player.selectPlacedTower(atSlot: meleeSlot); player.toggleRallyPlacement()
            XCTAssertEqual(sim.perform(.rally(slot: meleeSlot, point: point)),
                           player.placeRallyPoint(at: CGPoint(x: point.x, y: point.y)))
            XCTAssertEqual(sim.engine.rallyPointsBySlot, player.rallyPointsBySlot)
        }
        let hero = try XCTUnwrap(content.deployments.first)
        player.selectHero(heroID: hero.hero.id)
        XCTAssertFalse(player.commandSelectedHero(to: CGPoint(x: offMap.x, y: offMap.y)))
        XCTAssertEqual(sim.perform(.moveHero(id: hero.hero.id, point: offMap)), .invalid)
        // An invalid destination leaves the hero selected. A player can choose
        // another map point without toggling that selection off first.
        let destination = hero.spawn.position
        XCTAssertTrue(player.commandSelectedHero(to: CGPoint(x: destination.x, y: destination.y)))
        XCTAssertEqual(sim.perform(.moveHero(id: hero.hero.id, point: destination)), .ok)
        XCTAssertEqual(sim.engine.selectedHeroIndex, player.selectedHeroIndex)
        XCTAssertEqual(sim.engine.heroPosts.map { $0.unit.position }, player.heroPosts.map { $0.unit.position })
        XCTAssertEqual(sim.gold, player.money)
    }
}

@MainActor private final class InputTraceEngine: BattleEngine {
    var calls: [String] = []
    override func dismissMenu() { calls.append("dismiss"); super.dismissMenu() }
    override func selectSlot(_ index: Int) { calls.append("selectSlot"); super.selectSlot(index) }
    override func selectPlacedTower(atSlot index: Int) { calls.append("selectTower"); super.selectPlacedTower(atSlot: index) }
    override func tapBuildButton(_ kind: TowerKind) -> BuildResult? {
        calls.append("tapBuild"); return super.tapBuildButton(kind)
    }
    override func buildTower(_ kind: TowerKind) -> BuildResult {
        calls.append("commitBuild"); return super.buildTower(kind)
    }
    override func tapUpgradeButton(branch: Int) -> BuildResult? {
        calls.append("tapUpgrade"); return super.tapUpgradeButton(branch: branch)
    }
    override func upgradeSelectedTower(branch: Int) -> BuildResult {
        calls.append("commitUpgrade"); return super.upgradeSelectedTower(branch: branch)
    }
    override func tapUpgradePath(_ pathID: String) -> BuildResult? {
        calls.append("tapAbility"); return super.tapUpgradePath(pathID)
    }
    override func purchaseTowerUpgrade(slot: Int, pathID: String) -> BuildResult {
        calls.append("commitAbility"); return super.purchaseTowerUpgrade(slot: slot, pathID: pathID)
    }
}
