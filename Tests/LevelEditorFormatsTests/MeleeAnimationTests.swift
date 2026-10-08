import XCTest
@testable import LevelEditorFormats

final class MeleeAnimationTests: XCTestCase {
    func testWalkUsesSixDistanceDrivenPosesAndStopsInGuard() {
        for facing in UnitFacing.allCases {
            var poses = Set<String>()
            for distance in stride(from: 0.0, to: MeleeWalkCycle.cycleDistance, by: 0.25) {
                poses.insert(MeleeWalkCycle.assetName(family: .towerMilitia, facing: facing, walkPhase: distance, isWalking: true))
            }
            XCTAssertEqual(poses.count, 6)
            XCTAssertEqual(MeleeWalkCycle.assetName(family: .towerMilitia, facing: facing, walkPhase: 48, isWalking: true),
                           "militia_soldier_walk_\(facing.assetSuffix)_0")
            XCTAssertEqual(MeleeWalkCycle.assetName(family: .towerMilitia, facing: facing, walkPhase: 31, isWalking: false),
                           "militia_soldier_attack_\(facing.assetSuffix)_0")
        }
    }

    func testSwingShowsImpactRecoveryGuardAndWindupWithoutChangingItsClock() {
        let interval = 1.2, ticks = BattleGeometry.fireTicks(interval)
        func frame(_ remaining: Int, fighting: Bool = true, moving: Bool = false, alpha: Double = 1) -> String {
            MeleeAttackCycle.assetName(family: .towerMilitia, facing: .west, walkPhase: 24, isWalking: moving,
                isFighting: fighting, swingTicksLeft: remaining, attackInterval: interval, alpha: alpha)
        }
        XCTAssertEqual(frame(ticks), "militia_soldier_attack_w_3", "Contact must match the damage tick")
        XCTAssertEqual(frame(ticks - BattleGeometry.fireTicks(0.10)), "militia_soldier_attack_w_4")
        XCTAssertEqual(frame(ticks - BattleGeometry.fireTicks(0.20)), "militia_soldier_attack_w_5")
        XCTAssertEqual(frame(ticks / 2), "militia_soldier_attack_w_0", "Most of the cooldown is a stable guard")
        XCTAssertEqual(frame(BattleGeometry.fireTicks(0.14)), "militia_soldier_attack_w_1")
        XCTAssertEqual(frame(BattleGeometry.fireTicks(0.05)), "militia_soldier_attack_w_2")
        XCTAssertEqual(frame(ticks, fighting: false), "militia_soldier_attack_w_3", "A killing blow must remain visible")
        XCTAssertEqual(frame(3, fighting: false), "militia_soldier_attack_w_0", "No anticipation without an enemy")
        XCTAssertEqual(frame(ticks, moving: true), "militia_soldier_walk_w_3", "Movement takes precedence while repositioning")
        XCTAssertEqual(frame(ticks, alpha: 0), frame(ticks), "Interpolation must not delay a real impact")
    }

    @MainActor func testRealCombatPublishesEveryAttackPoseAndFacesItsOpponent() throws {
        let base = try BattleTestFixture.authored()
        let enemy = try XCTUnwrap(base.enemies.first { $0.key == "redcoat_regular" })
        let level = BattleTestFixture.level(enemy: enemy, slots: [Point(200, 90)])
        let content = try BattleTestFixture.content(level: level, enemies: [enemy], base: base)
        let battle = try BattleEngine(recording: .preview, content: content, heroesEnabled: false,
            startingMoneyOverride: nil, seed: 1776, onVictory: { _, _ in 0 })
        battle.publishesPresentation = true
        XCTAssertEqual(battle.perform(.build(slot: 0, kind: .melee)), .ok)
        let target = battle.spawnEnemy(type: enemy, pathIndex: 0, wave: 0, spawnTick: 0, pathDistance: 200)
        var garrison = try XCTUnwrap(battle.garrisonsBySlot[0])
        var unit = try XCTUnwrap(garrison.units.first)
        unit.position = Point(200 + battle.combatRules.meleeCombatSpacing, 0)
        unit.state = .fighting; unit.targetSpawnID = target
        garrison.units = [unit]; garrison.rallyPoint = Point(200, 0)
        battle.garrisonsBySlot[0] = garrison
        let interval = try XCTUnwrap(battle.garrisonMelee(slot: 0, garrison: garrison)).stats.attackInterval
        var seen = Set<String>(), hits = 0
        for _ in 0...BattleGeometry.fireTicks(interval) {
            let hp = try XCTUnwrap(battle.walkers.first).hp
            battle.militiaPrevPositions = battle.militiaPositionsById()
            battle.stepMilitiaTick(); battle.updateMilitiaPoses(); battle.publishMilitia()
            let soldier = try XCTUnwrap(battle.militia.first)
            XCTAssertTrue(soldier.assetName.hasPrefix("militia_soldier_attack_w_"))
            seen.insert(soldier.assetName)
            if try XCTUnwrap(battle.walkers.first).hp < hp {
                hits += 1
                XCTAssertEqual(soldier.assetName, "militia_soldier_attack_w_3")
            }
        }
        XCTAssertEqual(hits, 2)
        XCTAssertEqual(seen.count, 6)
        let before = battle.garrisonsBySlot[0]!.units[0]
        for alpha in [0.0, 0.25, 0.5, 1.0] { battle.publishMilitia(alpha: alpha) }
        let after = battle.garrisonsBySlot[0]!.units[0]
        XCTAssertEqual(before.position, after.position)
        XCTAssertEqual(before.hp, after.hp)
        XCTAssertEqual(before.swingTicksLeft, after.swingTicksLeft, "Display interpolation cannot advance combat")
    }

    func testLegacyFullFrameRecordingsMigrateAndNewFramesRoundTrip() throws {
        let current = BattleEngine.MilitiaSoldier(id: 1, assetName: "militia_soldier_walk_e_5",
                                                 position: .zero, hp: 20, maxHP: 50)
        let encoder = JSONEncoder(), decoder = JSONDecoder()
        let data = try encoder.encode(current)
        XCTAssertEqual(try decoder.decode(BattleEngine.MilitiaSoldier.self, from: data).assetName, current.assetName)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        legacy["assetName"] = "militia_soldier_walk_e_05"
        XCTAssertThrowsError(try decoder.decode(BattleEngine.MilitiaSoldier.self,
            from: JSONSerialization.data(withJSONObject: legacy)), "Current frame names must be canonical")
        legacy.removeValue(forKey: "animationVersion")
        for (old, expected) in [(63, "walk_e_5"), (16, "attack_e_0"), (0, "walk_e_0")] {
            legacy["assetName"] = "militia_soldier_walk_e_\(old)"
            let soldier = try decoder.decode(BattleEngine.MilitiaSoldier.self,
                from: JSONSerialization.data(withJSONObject: legacy))
            XCTAssertEqual(soldier.assetName, "militia_soldier_\(expected)")
        }
        legacy["assetName"] = "militia_soldier_walk_e_64"
        XCTAssertThrowsError(try decoder.decode(BattleEngine.MilitiaSoldier.self,
            from: JSONSerialization.data(withJSONObject: legacy)))
    }

    @MainActor func testEventPlaybackUsesRecordedSwingAndStillReadsSevenFieldHistory() throws {
        let battle = try BattleEngine(recording: .preview, content: BattleTestFixture.authored(),
            heroesEnabled: false, startingMoneyOverride: 1000, seed: 1776, onVictory: { _, _ in 0 })
        XCTAssertEqual(battle.perform(.build(slot: 17, kind: .melee)), .ok)
        var garrison = try XCTUnwrap(battle.garrisonsBySlot[17])
        let stats = try XCTUnwrap(battle.garrisonMelee(slot: 17, garrison: garrison)).stats
        garrison.units = [garrison.units[0]]
        garrison.units[0].state = .fighting
        garrison.units[0].swingTicksLeft = BattleGeometry.fireTicks(stats.attackInterval)
        battle.garrisonsBySlot[17] = garrison
        let id = 17 * 8, position = garrison.units[0].position
        battle.recordedFacingTargets[BattleEventUnitKey(hero: false, id: id)] =
            CGPoint(x: position.x + 100, y: position.y)
        let state = BattleEventState(battle)
        var block = BattleEventBlock(firstTick: 0)
        try block.append(state)
        let setup = LevelReplaySetup(engine: battle, seed: 1776, heroesEnabled: false)
        let current = try BattleEventPlayback().frame(block: block, tick: 0, setup: setup, previous: nil)
        XCTAssertEqual(current.militia.first?.assetName, "militia_soldier_attack_e_3")

        let legacyUnits = state.units.map { BattleEventUnit(id: $0.id, hero: $0.hero,
                                                           baseAsset: "", maxHP: $0.maxHP) }
        block.units = BattleEventChanges<[BattleEventUnit]>()
        block.units.append(legacyUnits, at: 0)
        XCTAssertThrowsError(try BattleEventPlayback().frame(block: block, tick: 0, setup: setup, previous: nil),
                             "New swing records require their saved authored interval")
        block.unitNumbers = BattleEventNumbers()
        block.unitNumbers.append(Array(state.unitNumbers.prefix(7)), at: 0)
        let old = try BattleEventPlayback().frame(block: block, tick: 0, setup: setup, previous: nil)
        XCTAssertEqual(old.militia.first?.assetName, "militia_soldier_attack_e_0")
        XCTAssertEqual(old.militia.first?.hp, current.militia.first?.hp)
        XCTAssertEqual(old.militia.first?.position, current.militia.first?.position)
    }

    @MainActor func testReinforcementsKeepTheirOwnSpritesAndStatsWhenTowerTroopsUpgrade() throws {
        let base = try BattleTestFixture.authored()
        let enemy = try XCTUnwrap(base.enemies.first { $0.key == "redcoat_regular" })
        let level = BattleTestFixture.level(enemy: enemy, slots: [Point(200, 90)])
        let content = try BattleTestFixture.content(level: level, enemies: [enemy], base: base)
        let battle = try BattleEngine(recording: .preview, content: content, heroesEnabled: false,
            startingMoneyOverride: nil, seed: 1776, onVictory: { _, _ in 0 })
        battle.publishesPresentation = true
        XCTAssertEqual(battle.perform(.build(slot: 0, kind: .melee)), .ok)
        XCTAssertEqual(battle.perform(.reinforcements(point: Point(200, 0))), .ok)
        let originalReinforcements = try XCTUnwrap(battle.garrisonsBySlot[-1])
        let stats = try XCTUnwrap(originalReinforcements.stats)
        let reinforcementCount = battle.combatRules.reinforcementSoldierCount
        func checkFamilies() {
            XCTAssertEqual(battle.militia.filter { $0.family == .reinforcement }.count, reinforcementCount)
            XCTAssertTrue(battle.militia.contains { $0.family == .towerMilitia })
            for soldier in battle.militia {
                XCTAssertTrue(soldier.assetName.hasPrefix(soldier.family.rawValue + "_"))
            }
        }
        checkFamilies()
        XCTAssertEqual(battle.perform(.upgrade(slot: 0, branch: 1)), .ok)
        battle.publishMilitia()
        checkFamilies()
        XCTAssertEqual(battle.garrisonsBySlot[-1]?.stats, stats)
        XCTAssertEqual(battle.garrisonsBySlot[-1]?.units.map(\.hp), originalReinforcements.units.map(\.hp))
        XCTAssertGreaterThan(try XCTUnwrap(battle.garrisonMelee(slot: 0,
            garrison: XCTUnwrap(battle.garrisonsBySlot[0]))).stats.hp, stats.hp)

        var block = BattleEventBlock(firstTick: 0)
        let state = BattleEventState(battle)
        try block.append(state)
        let setup = LevelReplaySetup(engine: battle, seed: 1776, heroesEnabled: false)
        for historical in [false, true] {
            if historical {
                block.units = BattleEventChanges<[BattleEventUnit]>()
                block.units.append(state.units.map { BattleEventUnit(id: $0.id, hero: $0.hero,
                    baseAsset: "", maxHP: $0.maxHP, attackInterval: $0.attackInterval) }, at: 0)
            }
            let replay = try BattleEventPlayback().frame(block: block, tick: 0, setup: setup, previous: nil)
            XCTAssertEqual(replay.militia.map(\.assetName), battle.militia.map(\.assetName))
        }
        block.units = BattleEventChanges<[BattleEventUnit]>()
        block.units.append(state.units.map { BattleEventUnit(id: $0.id, hero: $0.hero,
            baseAsset: "unknown_soldier", maxHP: $0.maxHP, attackInterval: $0.attackInterval) }, at: 0)
        XCTAssertThrowsError(try BattleEventPlayback().frame(block: block, tick: 0, setup: setup, previous: nil))
    }

    func testBothFamiliesUseTheirOwnWalkGuardAndDamageSynchronizedAttackAssets() {
        for family in MeleeUnitFamily.allCases {
            for facing in UnitFacing.allCases {
                for frame in 0..<MeleeWalkCycle.frameCount {
                    XCTAssertEqual(MeleeWalkCycle.assetName(family: family, facing: facing,
                        walkPhase: Double(frame) * 8, isWalking: true),
                        "\(family.rawValue)_walk_\(facing.assetSuffix)_\(frame)")
                }
                XCTAssertEqual(MeleeWalkCycle.assetName(family: family, facing: facing,
                    walkPhase: 24, isWalking: false), "\(family.rawValue)_attack_\(facing.assetSuffix)_0")
                XCTAssertEqual(MeleeAttackCycle.assetName(family: family, facing: facing,
                    walkPhase: 0, isWalking: false, isFighting: true,
                    swingTicksLeft: BattleGeometry.fireTicks(1.2), attackInterval: 1.2),
                    "\(family.rawValue)_attack_\(facing.assetSuffix)_3")
            }
        }
    }

    func testHistoricalReinforcementFramesRecoverTheirDistinctFamilyFromDeploymentID() throws {
        let current = BattleEngine.MilitiaSoldier(id: -8, assetName: "reinforcement_soldier_walk_e_5",
                                                 position: .zero, hp: 20, maxHP: 50)
        let encoder = JSONEncoder(), decoder = JSONDecoder()
        let data = try encoder.encode(current)
        XCTAssertEqual(try decoder.decode(BattleEngine.MilitiaSoldier.self, from: data).assetName, current.assetName)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        legacy["animationVersion"] = 2
        legacy["assetName"] = "militia_soldier_attack_e_3"
        XCTAssertEqual(try decoder.decode(BattleEngine.MilitiaSoldier.self,
            from: JSONSerialization.data(withJSONObject: legacy)).assetName, "reinforcement_soldier_attack_e_3")
        legacy.removeValue(forKey: "animationVersion")
        legacy["assetName"] = "militia_soldier_walk_e_63"
        XCTAssertEqual(try decoder.decode(BattleEngine.MilitiaSoldier.self,
            from: JSONSerialization.data(withJSONObject: legacy)).assetName, "reinforcement_soldier_walk_e_5")
        legacy["animationVersion"] = 3
        legacy["assetName"] = "militia_soldier_walk_e_5"
        XCTAssertThrowsError(try decoder.decode(BattleEngine.MilitiaSoldier.self,
            from: JSONSerialization.data(withJSONObject: legacy)))
    }

    @MainActor func testDualFamilyDeviceReviewEncounterContainsBothApproachAndRepeatedAttacks() throws {
        // Exercise the DEBUG capture's geometry, commands and capture window
        // on the normal host engine. UIKit screenshot delivery is device-only.
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let settings = try fixture.db.encyclopediaDemoDao.get()
        let authored = try fixture.db.levelInfoDao.getBy(id: settings.contextLevelID)
        let canvas = try fixture.db.virtualCanvasDao.get()
        func world(_ x: Double, _ y: Double) -> Point {
            Point(canvas.playAreaRect.midX + x, canvas.playAreaRect.midY + y)
        }
        let roads = [[world(-260, 0), world(600, 0)], [world(-260, -250), world(600, -250)]]
        let geometry: [String: Any] = ["type": "FeatureCollection", "features": roads.map { road in
            ["type": "Feature", "properties": ["category": "gameplay", "kind": "enemy_path", "widthPx": canvas.pathWidth],
             "geometry": ["type": "LineString", "coordinates": road.map { [$0.x, $0.y] }]]
        }]
        let movement = try HeroMovementArea(geoJSON: JSONSerialization.data(withJSONObject: geometry),
                                           defaultPathWidth: canvas.pathWidth)
        let wave = Wave(startTime: 0, spawns: roads.indices.map {
            SpawnEntry(enemyTypeID: Foe.redcoatRegular.id, count: 3, interval: 0.6, pathIndex: $0)
        }, callButtonDelay: 0, autoStartCountdown: 0, earlyCallBonus: 0)
        let level = LevelInfo(id: authored.id, name: authored.name, campaign: authored.campaign,
            startedAt: authored.startedAt, endedAt: authored.endedAt, startingMoney: authored.startingMoney,
            numStartingLives: authored.numStartingLives, numWaves: 1, playArea: authored.playArea,
            mapImageName: authored.mapImageName, paths: roads.map { Path(points: $0) },
            towerSlots: [TowerSlot(id: UUID(), position: world(0, 140))], waves: [wave])
        let draft = BattleDraft(level: level, heroes: try LevelHeroConfiguration(heroCount: 0, spawns: []),
            movementArea: movement, callButtons: [CallWaveButtonPosition(position: roads[0][0])], exits: roads.map { $0[1] })
        let content = try BattleContent(db: fixture.db, levelID: authored.id, draft: draft)
        let game = try BattleEngine(recording: .preview, content: content, heroesEnabled: false,
            startingMoneyOverride: nil, seed: 1776, onVictory: { _, _ in 0 })
        game.publishesPresentation = true
        for command in [BattleCommand.build(slot: 0, kind: .melee), .rally(slot: 0, point: world(0, 0)),
                        .reinforcements(point: world(0, -250)), .startWave] {
            XCTAssertEqual(game.perform(command), .ok)
        }
        var frames: [[BattleEngine.MilitiaSoldier]] = []
        var firstImpactTick: Int64?
        var previousDamage: [Int: Double] = [:], hitCounts: [MeleeUnitFamily: Int] = [:]
        for _ in 0..<(SimClock.ticksPerSecond * 20) {
            game.advance(ticks: 1, interpolation: 1)
            for (slot, damage) in game.damageTotalBySlot where damage > previousDamage[slot, default: 0] {
                hitCounts[MeleeUnitFamily(garrisonSlot: slot), default: 0] += 1
                if firstImpactTick == nil { firstImpactTick = game.timer.tick }
            }
            previousDamage = game.damageTotalBySlot
            frames.append(game.militia)
            if let firstImpactTick, game.timer.tick >= firstImpactTick + Int64(SimClock.ticksPerSecond * 4) { break }
            if firstImpactTick == nil, frames.count > SimClock.ticksPerSecond { frames.removeFirst() }
        }
        XCTAssertNotNil(firstImpactTick)
        XCTAssertEqual(frames.count, SimClock.ticksPerSecond * 5 + 1)
        for family in MeleeUnitFamily.allCases {
            XCTAssertGreaterThanOrEqual(hitCounts[family, default: 0], 3, family.rawValue)
            XCTAssertTrue(frames.contains { $0.contains { $0.family == family && $0.assetName.contains("_walk_") } }, family.rawValue)
            XCTAssertTrue(frames.contains { $0.contains { $0.family == family && $0.assetName.contains("_attack_") && $0.assetName.hasSuffix("_3") } }, family.rawValue)
        }
        print("Dual-family review: first impact tick \(firstImpactTick ?? -1), frames \(frames.count), hit ticks \(hitCounts)")
        XCTAssertNil(game.runRecorder, "The diagnostic must not write a player recording")
    }
}
