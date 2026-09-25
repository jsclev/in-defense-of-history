import XCTest
@testable import LevelEditorFormats

@MainActor
final class SimulationTowerModesTests: XCTestCase {
    private func make(kind: TowerKind, branch: Int, speed: Double = 0,
                      starts: [Point]) throws -> (GameSimulation, TowerLevel) {
        let content = try BattleTestFixture.authored()
        var enemy = try XCTUnwrap(content.enemies.first)
        enemy.stats.maxHP = 1_000_000; enemy.stats.speed = speed
        enemy.stats.cover = 0; enemy.stats.discipline = 1
        var tuning = try XCTUnwrap(content.arsenal.towers.first { $0.kind == kind }?.tiers.first {
            $0.level == 4 && $0.branch == branch
        }?.tuning)
        tuning.fireInterval = 1000 // Explicit one-shot fixture, in memory only.
        let level = BattleTestFixture.level(enemy: enemy,
            slots: [Point(0, tuning.combatRules.enemyBodyOffsetY)], starts: starts)
        let fixture = try BattleTestFixture.content(level: level, enemies: [enemy],
            tiers: [.init(kind, 4, branch): tuning], base: content)
        let sim = try GameSimulation(recording: .preview, content: fixture, startingMoney: nil, heroesEnabled: false, seed: 1776)
        try BattleTestFixture.build(kind, level: 4, branch: branch, in: sim)
        sim.startNextWave()
        return (sim, tuning)
    }

    func testSolidShotPenetratesSeveralEnemiesOnceEach() throws {
        let (sim, tuning) = try make(kind: .areaOfEffect, branch: 4,
                                    starts: [Point(100, 0), Point(180, 0), Point(260, 0)])
        for _ in 0..<300 { sim.step() }
        XCTAssertEqual(sim.shotsByMode[.solidShot], 1)
        XCTAssertEqual(sim.enemies.count, 3)
        for enemy in sim.enemies {
            let damage = 1_000_000 - enemy.hp
            XCTAssertGreaterThanOrEqual(damage, tuning.shotMinDamage - 0.001)
            XCTAssertLessThanOrEqual(damage, tuning.shotMaxDamage + 0.001)
        }
    }

    func testGrapeshotPelletsDoNotStackDamageOnOneEnemy() throws {
        let (sim, tuning) = try make(kind: .areaOfEffect, branch: 2, starts: [Point(100, 0), Point(110, 0)])
        for _ in 0..<300 { sim.step() }
        XCTAssertEqual(sim.shotsByMode[.grapeshot], 1)
        XCTAssertTrue(sim.enemies.contains { $0.hp < 1_000_000 })
        for enemy in sim.enemies {
            XCTAssertLessThanOrEqual(1_000_000 - enemy.hp, tuning.shotMaxDamage + 0.001)
        }
    }

    func testShellKeepsAreaDamage() throws {
        let (sim, _) = try make(kind: .areaOfEffect, branch: 1,
                                starts: [Point(100, 0), Point(110, 0), Point(120, 0)])
        for _ in 0..<300 { sim.step() }
        XCTAssertEqual(sim.shotsByMode[.shell], 1)
        XCTAssertEqual(sim.enemies.filter { $0.hp < 1_000_000 }.count, 3)
    }

    func testDemolitionRequiresPlacementThenAutomaticallyTriggersAndRearms() throws {
        let (sim, tuning) = try make(kind: .special, branch: 3, speed: 30, starts: [Point(0, 0)])
        for _ in 0..<60 { sim.step() }
        XCTAssertTrue(try XCTUnwrap(sim.engine.placedTower(atSlot: 0)?.demolitionCharge).isReadyForPlacement)
        XCTAssertEqual(sim.demolitionDetonations, 0)
        XCTAssertEqual(sim.perform(.placeDemolition(slot: 0, point: Point(150, 0))), .ok)
        for _ in 0..<900 {
            sim.step()
            if sim.demolitionDetonations > 0 { break }
        }
        XCTAssertEqual(sim.demolitionDetonations, 1)
        XCTAssertFalse(try XCTUnwrap(sim.engine.placedTower(atSlot: 0)?.demolitionCharge).isReady)
        XCTAssertLessThan(try XCTUnwrap(sim.enemies.first).hp, 1_000_000)
        XCTAssertNil(sim.shotsByMode[.demolition])
        let ticks = Int(ceil(try XCTUnwrap(tuning.demolitionPreparationSeconds) * Double(SimClock.ticksPerSecond))) + 1
        for _ in 0..<ticks { sim.step() }
        XCTAssertTrue(try XCTUnwrap(sim.engine.placedTower(atSlot: 0)?.demolitionCharge).isReady)
        XCTAssertEqual(sim.demolitionDetonations, 1)
    }
}
