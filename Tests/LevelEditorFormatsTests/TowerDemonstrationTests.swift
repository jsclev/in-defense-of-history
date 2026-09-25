import XCTest
import SQLite3
@testable import LevelEditorFormats

final class TowerDemonstrationTests: XCTestCase {
    @MainActor func testSiegeInfantryHoldsTheColumnForSolidShot() throws {
        let fixture = try AuthoredDatabaseFixture()
        let demo = try TowerDemonstration(db: fixture.db, kind: .areaOfEffect, level: 4, branch: 4)
        XCTAssertEqual(demo.supportingTowers.count, 2)
        XCTAssertEqual(demo.frames.first!.soldiers.count, 6)
        XCTAssertEqual(demo.escaped, 0)
        XCTAssertEqual(demo.frames.last!.killed.count, 6)
        XCTAssertEqual(demo.frames.last!.shots, 2)
        let finalKillIndex = try XCTUnwrap(demo.frames.firstIndex { $0.killed.count == 6 })
        XCTAssertLessThanOrEqual(demo.loopDuration - Double(finalKillIndex) * SimClock.dt,
                                2 * SimClock.dt + 1e-10, "Restart immediately after the final kill and victory tick")
        let firstShot = try XCTUnwrap(demo.frames.first { $0.shots == 1 })
        XCTAssertEqual(firstShot.blocked.count, 6, "The infantry must hold the whole column before firing")
        XCTAssertEqual(firstShot.blockingPairs.count, 6)
        XCTAssertEqual(Set(firstShot.blockingPairs.values).count, 6, "One defender per enemy")
        XCTAssertEqual(Set(firstShot.rallies.values.map { Point($0.x, $0.y) }).count, 1)
        XCTAssertTrue(firstShot.soldiers.allSatisfy { $0.hp > 0 })
        let firstBallHits = demo.frames.filter { $0.shots == 1 }.flatMap(\.projectiles)
            .compactMap { $0.solidShot?.hitIDs.count }.max()
        XCTAssertEqual(firstBallHits, 6, "The same solid ball must pass through the entire column")
        XCTAssertTrue(demo.frames.filter { $0.shots < 2 }.allSatisfy { $0.killed.isEmpty })
        for (before, after) in zip(demo.frames, demo.frames.dropFirst()) where after.killed.count > before.killed.count {
            XCTAssertEqual(after.shots, 2)
            XCTAssertGreaterThan(after.damageBySlot[0, default: 0], before.damageBySlot[0, default: 0],
                "Deaths must coincide with the artillery hit")
            for slot in 1...2 {
                XCTAssertEqual(after.damageBySlot[slot], before.damageBySlot[slot],
                    "The infantry must not quietly finish the enemies")
            }
        }
        let total = demo.frames.last!.damageBySlot.values.reduce(0, +)
        XCTAssertGreaterThan(demo.frames.last!.damageBySlot[0, default: 0] / total, 0.85)
        print("SIEGE: \(demo.loopDuration)s, two shots, six pierced and killed, all individually blocked before firing")
    }

    @MainActor func testSiegeRoadHasFlowingCurvatureInItsApproachAndDeparture() throws {
        let fixture = try AuthoredDatabaseFixture()
        let demo = try TowerDemonstration(db: fixture.db, kind: .areaOfEffect, level: 4, branch: 4)
        let points = demo.road
        XCTAssertGreaterThan(points.count, 12, "The route must describe the curve used by the renderer")
        guard points.count > 12 else { return }
        for i in 1..<(points.count - 1) {
            let incoming = atan2(points[i].y - points[i - 1].y, points[i].x - points[i - 1].x)
            let outgoing = atan2(points[i + 1].y - points[i].y, points[i + 1].x - points[i].x)
            let turn = abs(atan2(sin(outgoing - incoming), cos(outgoing - incoming)))
            XCTAssertLessThan(turn, 0.1, "No angular corners in the road or the enemy route")
        }
        for section in [Array(points.prefix(points.count / 3)), Array(points.suffix(points.count / 3))] {
            let chord = Path(points: [section.first!, section.last!])
            let departure = section.map { point in
                point.distance(to: chord.point(atDistance: chord.nearestDistance(to: point)))
            }.max()!
            XCTAssertGreaterThan(departure, demo.roadWidth * 0.08,
                "Both ends must flow naturally, not become long straight connectors")
        }
        XCTAssertTrue(demo.frames.allSatisfy { $0.presentation.paths.first?.points == points },
            "The shared engine must follow the same curve that is drawn")
    }

    func testDemonstrationOnlyStagesInputsAndRecordsSharedEngineResults() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Engine/Models/TowerDemonstration.swift"), encoding: .utf8)
        for forbidden in ["applyImpact(", "updateCombat(", "advanceWalkers(", "buildTower(",
                          "hp -=", "shotMinDamage:", "enemyHPMultiplier:", "game.walkers =", "game.money ="] {
            XCTAssertFalse(source.contains(forbidden), "Demonstration owns gameplay: \(forbidden)")
        }
        XCTAssertTrue(source.contains("game.perform(.build("))
        XCTAssertTrue(source.contains("game.perform(.startWave)"))
        XCTAssertTrue(source.contains("game.advance(ticks: 1, interpolation: 0)"))
        XCTAssertTrue(source.contains("BattleContent(db: db"))
    }

    @MainActor func testRangedExampleClearsWithRealShotsAtNormalSpeed() throws {
        let fixture = try AuthoredDatabaseFixture()
        let demo = try TowerDemonstration(db: fixture.db, kind: .ranged, level: 1, branch: 1)
        XCTAssertEqual(demo.outcome, .victory)
        XCTAssertEqual(demo.escaped, 0)
        XCTAssertTrue(demo.frames.contains { $0.enemies.count == 2 })
        XCTAssertTrue(demo.frames.contains { $0.enemies.contains { $0.hp < $0.maxHP } })
        XCTAssertGreaterThan(demo.frames.last!.shots, 2)
        XCTAssertGreaterThan(demo.loopDuration, 5)
        XCTAssertEqual(demo.frameIndex(at: 0), demo.frameIndex(at: demo.loopDuration))
        XCTAssertEqual(demo.frameIndex(at: demo.loopDuration - SimClock.dt / 2), demo.frames.count - 1)
        XCTAssertTrue(demo.frames.last!.enemies.isEmpty,
                      "The encounter must finish before the loop restarts")
        print("Tower demo: \(demo.frames.count) ticks, \(demo.frames.last!.seconds) game seconds, \(demo.frames.last!.shots) shots")

    }

    @MainActor func testDatabaseTuningChangesTheRecordedEncounter() throws {
        let fixture = try AuthoredDatabaseFixture()
        let before = try TowerDemonstration(db: fixture.db, kind: .ranged, level: 1, branch: 1)
        XCTAssertEqual(sqlite3_exec(fixture.connection, """
            UPDATE tower SET shot_min_damage = 100, shot_max_damage = 100
            WHERE tower_name = 'Musketmen';
            """, nil, nil, nil), SQLITE_OK)
        let after = try TowerDemonstration(db: fixture.db, kind: .ranged, level: 1, branch: 1)
        XCTAssertLessThan(after.frames.last!.shots, before.frames.last!.shots)
        XCTAssertLessThan(after.frames.count, before.frames.count)
        XCTAssertEqual(after.tower.tuning.shotMinDamage, 100)
    }

    @MainActor func testMortarStudyShowsSharedBlastAndSeparatedArrivalsUsingRealCombat() throws {
        let fixture = try AuthoredDatabaseFixture()
        let demo = try TowerDemonstration(db: fixture.db, kind: .areaOfEffect, level: 4, branch: 1)
        XCTAssertTrue(demo.isMortarStudy)
        XCTAssertGreaterThanOrEqual(demo.frames.map { $0.enemies.count }.max()!, 4)
        let spawns = demo.frames.flatMap(\.enemies).reduce(into: [Int: Int64]()) { $0[$1.id] = $1.spawnTick }
        XCTAssertEqual(spawns.count, 6)
        XCTAssertGreaterThan(spawns.values.max()! - spawns.values.min()!, Int64(7 * SimClock.ticksPerSecond))
        var biggestSharedHit = 0
        for (before, after) in zip(demo.frames, demo.frames.dropFirst()) {
            let damaged = before.enemies.filter { enemy in
                after.killed.contains(enemy.id) || after.enemies.contains { $0.id == enemy.id && $0.hp < enemy.hp }
            }.count
            biggestSharedHit = max(biggestSharedHit, damaged)
        }
        XCTAssertGreaterThanOrEqual(biggestSharedHit, 3, "The blast must visibly affect several enemies together")
        XCTAssertTrue(demo.frames.contains { $0.enemies.contains { $0.morale.remainingFraction < 0.95 } })
        XCTAssertEqual(demo.escaped, 2, "The separated arrivals reveal the battery's limitation")
        let columnIDs = Set(spawns.filter { $0.value < Int64(SimClock.ticksPerSecond) }.keys)
        XCTAssertEqual(columnIDs.count, 4)
        XCTAssertTrue(columnIDs.isSubset(of: demo.frames.last!.killed))
        print("MORTAR STUDY: \(demo.loopDuration)s; largest shared hit \(biggestSharedHit); shots \(demo.frames.last!.shots); escaped \(demo.escaped)")
        XCTAssertEqual(demo.outcome, .victory, "Complete the encounter before repeating it")
        XCTAssertTrue(demo.frames.last!.enemies.isEmpty)
        XCTAssertTrue(demo.frames.flatMap(\.enemies).allSatisfy {
            $0.position.x > demo.bounds.minX + 20 && $0.position.x < demo.bounds.maxX + 30
        }, "Resolve departures just beyond the visible road edge")
        XCTAssertEqual(sqlite3_exec(fixture.connection, """
            UPDATE tower SET fire_interval = 3.5 WHERE id = 'f614aea2-b5cb-4cd3-a30d-e33a02c27c90';
            """, nil, nil, nil), SQLITE_OK)
        let slower = try TowerDemonstration(db: fixture.db, kind: .areaOfEffect, level: 4, branch: 1)
        XCTAssertEqual(slower.tower.tuning.fireInterval, 3.5)
        let secondShot = try XCTUnwrap(demo.frames.first { $0.shots == 2 })
        let slowerSecondShot = try XCTUnwrap(slower.frames.first { $0.shots == 2 })
        XCTAssertGreaterThan(slowerSecondShot.seconds, secondShot.seconds)
    }

    @MainActor func testRangedUpgradesFaceIdenticalConditionsAndShowTheirAdvantages() throws {
        let fixture = try AuthoredDatabaseFixture()
        let arsenal = try fixture.db.towerTypeDao.getDesignArsenal()
        let ranged = try XCTUnwrap(arsenal.towers.first { $0.kind == .ranged })
        let demos = try ranged.tiers.map {
            try TowerDemonstration(db: fixture.db, kind: .ranged, level: $0.level, branch: $0.branch)
        }
        let baseline = try XCTUnwrap(demos.first)
        let baselineEnemy = try XCTUnwrap(baseline.frames.first?.enemies.first)
        let baselineSpawns = baseline.frames.flatMap(\.enemies)
            .reduce(into: [Int: Int64]()) { $0[$1.id] = $1.spawnTick }
        var firstShotTimes: [Double] = []
        var firstKillTimes: [Double] = []
        var shotsToKill: [Int] = []
        var firstHitDamage: [Double] = []
        for demo in demos {
            XCTAssertEqual(demo.road, baseline.road)
            if demo.tower.level <= 3 { XCTAssertEqual(demo.bounds, baseline.bounds) }
            XCTAssertEqual(demo.roadWidth, baseline.roadWidth)
            XCTAssertEqual(demo.tower.position, baseline.tower.position)
            let spawns = demo.frames.flatMap(\.enemies).reduce(into: [Int: Int64]()) { $0[$1.id] = $1.spawnTick }
            XCTAssertEqual(spawns, baselineSpawns)
            for enemy in demo.frames.flatMap(\.enemies) {
                XCTAssertEqual(enemy.assetName, baselineEnemy.assetName)
                XCTAssertEqual(enemy.maxHP, baselineEnemy.maxHP)
                XCTAssertEqual(enemy.cover, baselineEnemy.cover)
                XCTAssertEqual(enemy.speed, baselineEnemy.speed)
                XCTAssertEqual(enemy.damageMin, baselineEnemy.damageMin)
                XCTAssertEqual(enemy.damageMax, baselineEnemy.damageMax)
            }
            let firstShot = try XCTUnwrap(demo.frames.first { $0.shots > 0 })
            let firstKill = try XCTUnwrap(demo.frames.first { $0.killed.contains(baselineEnemy.id) })
            let firstDamage = try XCTUnwrap(demo.frames.lazy.flatMap(\.enemies).first {
                $0.id == baselineEnemy.id && $0.hp < $0.maxHP
            })
            if demo.tower.level <= 3 {
                firstShotTimes.append(firstShot.seconds)
                firstKillTimes.append(firstKill.seconds)
                shotsToKill.append(firstKill.shots)
                firstHitDamage.append(firstDamage.maxHP - firstDamage.hp)
            }
            print("RANGED COMPARISON \(demo.tower.name): first shot \(firstShot.seconds)s, first kill \(firstKill.seconds)s in \(firstKill.shots) shots, first hit \(firstDamage.maxHP - firstDamage.hp) HP")
        }
        for next in 1..<3 {
            XCTAssertLessThanOrEqual(firstShotTimes[next], firstShotTimes[next - 1], "Extra range must engage at least as soon on the same path")
            XCTAssertLessThan(firstKillTimes[next], firstKillTimes[next - 1], "The upgraded tower must visibly kill sooner")
            XCTAssertLessThan(shotsToKill[next], shotsToKill[next - 1], "Stronger damage must take fewer shots against the same enemy")
            XCTAssertGreaterThan(firstHitDamage[next], firstHitDamage[next - 1], "The same health bar must lose a larger fraction per hit")
        }
        XCTAssertLessThanOrEqual(firstShotTimes[0], 0.5, "Do not make the player wait for the weakest tower's first engagement")
    }

    @MainActor func testInvalidContentStopsTheDemonstration() throws {
        for mutation in ["DELETE FROM tower WHERE tower_name = 'Musketmen'",
                         "UPDATE enemy_type SET image_name = '' WHERE enemy_type_key = 'loyalist_militia'",
                         "UPDATE tower SET projectile_speed = -1 WHERE tower_name = 'Musketmen'",
                         "DELETE FROM encyclopedia_demo",
                         "UPDATE encyclopedia_demo SET starting_money = -1",
                         "UPDATE encyclopedia_demo SET starting_money = 'bad'",
                         "UPDATE encyclopedia_demo SET context_level_id = 'bad'"] {
            let fixture = try AuthoredDatabaseFixture()
            XCTAssertEqual(sqlite3_exec(fixture.connection, "PRAGMA ignore_check_constraints = ON; " + mutation,
                                       nil, nil, nil), SQLITE_OK)
            XCTAssertThrowsError(try TowerDemonstration(db: fixture.db, kind: .ranged, level: 1, branch: 1), mutation)
        }
    }
    @MainActor func testEveryAuthoredTowerDemonstratesItsRealCapability() throws {
        let fixture = try AuthoredDatabaseFixture()
        let arsenal = try fixture.db.towerTypeDao.getDesignArsenal()
        let catalog = TowerDemonstrationCatalog(db: fixture.db)
        var count = 0
        var lessons = Set<String>()
        var opponents = Set<String>()
        for family in arsenal.towers {
            for tier in family.tiers {
                let demo = try catalog.recording(kind: family.kind, tier: tier)
                count += 1
                lessons.insert(demo.lesson.rawValue)
                let damaged = Set(demo.frames.flatMap { $0.enemies.filter { $0.hp < $0.maxHP }.map(\.id) })
                let blocked = demo.frames.contains { !$0.blocked.isEmpty }
                let slowed = demo.frames.contains { !$0.slowed.isEmpty }
                let healed = demo.frames.contains { !$0.healing.isEmpty }
                let pierced = demo.frames.flatMap(\.projectiles).compactMap { $0.solidShot?.hitIDs.count }.max() ?? 0
                print("DEMO \(family.kind.rawValue)-\(tier.level)-\(tier.branch) \(demo.lesson.rawValue): \(demo.frames.count) frames, \(demo.frames.last!.shots) shots, \(damaged.count) hurt, blocked=\(blocked) slowed=\(slowed) healed=\(healed) pierced=\(pierced) escaped=\(demo.escaped)")
                XCTAssertEqual(demo.tower.name, tier.details.name)
                XCTAssertEqual(demo.tower.level, tier.level)
                XCTAssertEqual(demo.tower.branch, tier.branch)
                XCTAssertGreaterThan(demo.frames.count, 20)
                if demo.lesson != .piercing {
                    XCTAssertEqual(demo.escaped, demo.isMortarStudy ? 2 : 0, tier.details.name)
                }
                XCTAssertEqual(demo.frameIndex(at: 0), demo.frameIndex(at: demo.loopDuration))
                XCTAssertEqual(demo.frameIndex(at: demo.loopDuration - SimClock.dt / 2), demo.frames.count - 1)
                let first = try XCTUnwrap(demo.frames.first)
                // Exercise the camera used by the native view at its measured
                // iPhone size, including the sprite and health-bar clearance.
                let sceneSize = demo.lesson == .piercing
                    ? CGSize(width: 321.3333, height: 256.3333)
                    : CGSize(width: 313.6667, height: 161.6667)
                let projection = DemonstrationProjection(bounds: demo.bounds, size: sceneSize, virtualCanvas: demo.virtualCanvas)
                let firstEnemy = try XCTUnwrap(first.enemies.first)
                let entrance = projection.point(firstEnemy.position)
                XCTAssertGreaterThanOrEqual(entrance.x, 11, "\(tier.details.name): enemy must enter in view")
                XCTAssertLessThanOrEqual(entrance.x, sceneSize.width - 11, tier.details.name)
                XCTAssertGreaterThanOrEqual(entrance.y - projection.unitHeight - 9, 0, tier.details.name)
                XCTAssertLessThan(entrance.y, sceneSize.height, tier.details.name)
                let verticallyClippedEnemies = demo.frames.flatMap(\.enemies).filter { enemy in
                    let anchor = projection.point(enemy.position)
                    return anchor.y > sceneSize.height || anchor.y - projection.unitHeight - 9 < 0
                }
                XCTAssertTrue(verticallyClippedEnemies.isEmpty,
                    "\(tier.details.name): keep moving enemies and their health bars within the camera; clipped anchors \(verticallyClippedEnemies.map { projection.point($0.position).y }.min() ?? 0)...\(verticallyClippedEnemies.map { projection.point($0.position).y }.max() ?? 0), unit height \(projection.unitHeight)")
                let range = demo.tower.tuning.meleeUnit?.rallyPointRadius ?? demo.tower.tuning.range
                if range > 0 {
                    XCTAssertGreaterThanOrEqual(range * 2 * projection.scale / sceneSize.width, 0.8,
                        "\(tier.details.name): range must occupy most of the canvas width")
                }
                let road = Path(points: demo.road)
                for emplacement in demo.frames.last!.towers {
                    let base = Point(emplacement.position.x, emplacement.position.y)
                    let nearest = road.point(atDistance: road.nearestDistance(to: base))
                    XCTAssertGreaterThan(base.distance(to: nearest),
                        demo.roadWidth / 2 + demo.virtualCanvas.towerSlotSize.height / 2,
                        "\(tier.details.name): every tower must stand beside the road, never on it")
                    let anchor = projection.point(emplacement.position)
                    let halfWidth = projection.towerHeight * 0.7
                    XCTAssertGreaterThanOrEqual(anchor.x - halfWidth, 0, tier.details.name)
                    XCTAssertLessThanOrEqual(anchor.x + halfWidth, sceneSize.width, tier.details.name)
                    XCTAssertGreaterThanOrEqual(anchor.y - projection.towerHeight, 0,
                        "\(tier.details.name): leave room above both towers for their artwork")
                }
                opponents.formUnion(demo.frames.flatMap(\.enemies).map(\.assetName))
                XCTAssertFalse(first.enemies.isEmpty, "\(tier.details.name) must start with enemies entering")
                for elapsed in [0.0, 0.1, 0.5, 1.0, 2.0, 5.0] {
                    let played = demo.frames[demo.frameIndex(at: elapsed)]
                    let loopElapsed = elapsed.truncatingRemainder(dividingBy: demo.loopDuration)
                    // Playback contains only engine ticks and wraps directly
                    // after the completed encounter.
                    let combatElapsed = min(loopElapsed, demo.frames.last!.seconds - first.seconds)
                    XCTAssertEqual(played.seconds - first.seconds, combatElapsed, accuracy: SimClock.dt,
                                   "\(tier.details.name) must play at 1× throughout the encounter")
                    XCTAssertLessThanOrEqual(abs(demo.frameIndex(at: elapsed + demo.loopDuration) - demo.frameIndex(at: elapsed)), 1,
                                   "\(tier.details.name) must repeat without an opening hold")
                }
                switch demo.lesson {
                case .singleTargets:
                    XCTAssertGreaterThan(demo.frames.last!.shots, 0, tier.details.name)
                    XCTAssertFalse(damaged.isEmpty, tier.details.name)
                case .blast, .grapeshot, .piercing:
                    XCTAssertGreaterThanOrEqual(damaged.count, 2, tier.details.name)
                    XCTAssertTrue(demo.frames.contains { $0.enemies.contains { $0.morale.remainingFraction < 0.95 } }, tier.details.name)
                    if demo.lesson == .piercing {
                        XCTAssertGreaterThanOrEqual(pierced, 2)
                        XCTAssertNotNil(demo.outcome, "Finish the roadside encounter before looping")
                        XCTAssertEqual(demo.frames.last!.killed.count + demo.escaped, 6,
                            "Resolve every arrival; a roadside battery need not guarantee a perfect defense")
                    }
                    if demo.lesson == .grapeshot {
                        XCTAssertTrue(demo.frames.contains { $0.projectiles.filter { $0.grapeshot != nil }.count > 1 })
                    }
                case .blocking:
                    XCTAssertTrue(blocked, tier.details.name)
                    XCTAssertTrue(demo.frames.contains { $0.soldiers.count == tier.tuning.meleeUnit!.soldierCount })
                    XCTAssertFalse(damaged.isEmpty, tier.details.name)
                case .slowing:
                    XCTAssertTrue(slowed, tier.details.name)
                    XCTAssertTrue(demo.frames.contains { !$0.obstacles.isEmpty })
                    XCTAssertEqual(demo.frames.last!.shots, 0)
                    XCTAssertGreaterThan(demo.frames.last!.shotsBySlot[1, default: 0], 0)
                case .demolition:
                    XCTAssertNil(demo.frames.first!.towers.first!.demolitionCharge!.position)
                    XCTAssertTrue(demo.frames.contains { $0.impacts.contains { $0.isDemolition } })
                    XCTAssertTrue(demo.frames.contains { $0.towers.first!.demolitionCharge!.progress < 0.2 })
                    XCTAssertTrue(demo.frames.suffix(20).contains { $0.towers.first!.demolitionCharge!.isReady == true })
                    XCTAssertGreaterThanOrEqual(damaged.count + demo.frames.last!.killed.count, 2)
                case .income:
                    XCTAssertEqual(demo.frames.first!.waveIncome, demo.tower.tuning.support.incomePerWave)
                    XCTAssertEqual(demo.frames.last!.waveIncome, demo.tower.tuning.support.incomePerWave)
                    XCTAssertEqual(demo.frames.first!.towers.count, 1)
                    XCTAssertEqual(demo.frames.last!.towers.count, 2)
                case .attackSupport:
                    let helper = try XCTUnwrap(demo.supportingTowers.first)
                    XCTAssertGreaterThan(try XCTUnwrap(demo.supportedFireRates[helper.slot]), 1 / helper.tuning.fireInterval)
                    XCTAssertGreaterThan(demo.frames.last!.shotsBySlot[helper.slot, default: 0], 0)
                case .healing:
                    XCTAssertTrue(healed)
                    XCTAssertTrue(demo.frames.contains { $0.soldiers.contains { $0.hp < $0.maxHP * 0.95 } })
                }
            }
        }
        XCTAssertEqual(count, arsenal.towers.reduce(0) { $0 + $1.tiers.count })
        XCTAssertEqual(count, 30)
        XCTAssertEqual(lessons.count, 10)
        XCTAssertEqual(opponents.count, 1, "Do not hide stronger towers behind stronger demonstration enemies")
    }

    @MainActor func testDemoBudgetIsAuthoredAndDoesNotChangeCampaignState() throws {
        let fixture = try AuthoredDatabaseFixture()
        let settings = try fixture.db.encyclopediaDemoDao.get()
        let before = try fixture.db.levelInfoDao.getBy(id: settings.contextLevelID)
        XCTAssertEqual(sqlite3_exec(fixture.connection,
            "UPDATE encyclopedia_demo SET starting_money = 2500", nil, nil, nil), SQLITE_OK)
        let demo = try TowerDemonstration(db: fixture.db, kind: .supply, level: 4, branch: 2)
        XCTAssertEqual(demo.startingMoney, 2500)
        XCTAssertEqual(try fixture.db.levelInfoDao.getBy(id: settings.contextLevelID).startingMoney, before.startingMoney)
        XCTAssertEqual(sqlite3_exec(fixture.connection,
            "UPDATE encyclopedia_demo SET starting_money = 1", nil, nil, nil), SQLITE_OK)
        XCTAssertThrowsError(try TowerDemonstration(db: fixture.db, kind: .supply, level: 4, branch: 2))
    }

}
