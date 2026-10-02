import XCTest
import SQLite3
@testable import LevelEditorFormats

final class EnemyEncyclopediaTests: XCTestCase {
    func testCompleteRosterUsesTheProductionRecordsAndRequiredHistory() throws {
        let fixture = try AuthoredDatabaseFixture()
        let entries = try fixture.db.enemyTypeDao.getEncyclopedia()
        XCTAssertEqual(entries.map(\.id), Foe.allCases.map(\.id))
        let roster = try DesignRoster(enemyTypes: fixture.db.enemyTypeDao.getAll())
        for entry in entries {
            XCTAssertEqual(entry.enemy, roster.enemyTypes.first { $0.id == entry.id })
            XCTAssertFalse(entry.strategy.isEmpty)
            XCTAssertFalse(entry.history.isEmpty)
            XCTAssertFalse(entry.inclusionReason.isEmpty)
            XCTAssertFalse(entry.adaptation.isEmpty)
            XCTAssertEqual(entry.sourceURL.scheme, "https")
        }
    }

    func testDatabaseEditsReachCopyStatsAndArtwork() throws {
        let fixture = try AuthoredDatabaseFixture()
        let id = Foe.redcoatRegular.id.uuidString.lowercased()
        XCTAssertEqual(sqlite3_exec(fixture.connection, """
            UPDATE enemy_type SET enemy_type_name='Changed name', enemy_type_long_name='Changed full name', image_name='changed_art', icon_image_name='changed_icon', max_hp=123, speed=77 WHERE id='\(id)';
            UPDATE enemy_encyclopedia SET strategy_text='Changed strategy', historical_description='Changed history',
              inclusion_reason='Changed rationale', adaptation_text='Changed adaptation', source_title='Changed source',
              source_url='https://www.nps.gov/' WHERE enemy_type_id='\(id)';
            """, nil, nil, nil), SQLITE_OK)
        let entry = try XCTUnwrap(fixture.db.enemyTypeDao.getEncyclopedia().first { $0.id == Foe.redcoatRegular.id })
        XCTAssertEqual(entry.enemy.name, "Changed name")
        XCTAssertEqual(entry.enemy.longName, "Changed full name")
        XCTAssertEqual(entry.enemy.imageName, "changed_art")
        XCTAssertEqual(entry.enemy.iconImageName, "changed_icon")
        XCTAssertEqual(entry.enemy.stats.maxHP, 123)
        XCTAssertEqual(entry.enemy.stats.speed, 77)
        XCTAssertEqual(entry.strategy, "Changed strategy")
        XCTAssertEqual(entry.history, "Changed history")
        XCTAssertEqual(entry.inclusionReason, "Changed rationale")
        XCTAssertEqual(entry.adaptation, "Changed adaptation")
        XCTAssertEqual(entry.sourceTitle, "Changed source")
        XCTAssertEqual(entry.sourceURL.absoluteString, "https://www.nps.gov/")
        let rows = EnemyEncyclopediaStats(enemy: entry.enemy, rules: try fixture.db.combatRulesDao.get()).rows
        XCTAssertEqual(rows.first { $0.label == "Health" }?.value, "123")
    }

    func testMissingAndInvalidContentFailsWithRecordAndField() throws {
        let id = Foe.redcoatRegular.id.uuidString.lowercased()
        var mutations = [("DELETE FROM enemy_encyclopedia WHERE enemy_type_id='\(id)'", "enemy_type_id")]
        for field in ["strategy_text", "historical_description", "inclusion_reason", "adaptation_text", "source_title", "source_url"] {
            mutations.append(("UPDATE enemy_encyclopedia SET \(field)=' ' WHERE enemy_type_id='\(id)'", field))
        }
        mutations.append(("UPDATE enemy_encyclopedia SET source_url='relative/path' WHERE enemy_type_id='\(id)'", "source_url"))
        for (mutation, field) in mutations {
            let fixture = try AuthoredDatabaseFixture()
            XCTAssertEqual(sqlite3_exec(fixture.connection, "PRAGMA ignore_check_constraints=ON; " + mutation, nil, nil, nil), SQLITE_OK)
            XCTAssertThrowsError(try fixture.db.enemyTypeDao.getEncyclopedia()) {
                let message = String(describing: $0)
                XCTAssertTrue(message.contains("enemy_encyclopedia"), message)
                XCTAssertTrue(message.contains(field), message)
            }
        }
        let fixture = try AuthoredDatabaseFixture()
        XCTAssertEqual(sqlite3_exec(fixture.connection, "UPDATE enemy_encyclopedia SET inclusion_reason=NULL", nil, nil, nil), SQLITE_CONSTRAINT)
    }

    @MainActor func testEveryEnemyCompletesAnUnmodifiedSharedEngineEncounter() throws {
        let fixture = try AuthoredDatabaseFixture()
        let enemies = try fixture.db.enemyTypeDao.getEncyclopedia()
        let roster = Dictionary(uniqueKeysWithValues: enemies.map { ($0.id, $0.enemy) })
        let difficulty = try XCTUnwrap(fixture.db.difficultyDao.getSelected())
        for entry in enemies {
            let demo = try TowerDemonstration(db: fixture.db, enemyID: entry.id)
            XCTAssertNotNil(demo.outcome, entry.enemy.key)
            let study = try XCTUnwrap(demo.enemyStudy)
            XCTAssertEqual(study.subjectTypeID, entry.id)
            XCTAssertEqual(study.spawnedTypes.values.filter { $0 == entry.id }.count, 1)
            let final = try XCTUnwrap(demo.frames.last)
            let survivors = Set(final.enemies.map(\.id))
            let removed = Set(study.removed.keys)
            XCTAssertTrue(survivors.isDisjoint(with: removed))
            XCTAssertEqual(survivors.union(removed), Set(study.spawnedTypes.keys))
            if demo.outcome == .victory {
                XCTAssertTrue(survivors.isEmpty, entry.enemy.key)
            } else {
                // A boss reaching the exit can end the battle while its
                // escort or already dispatched reserves are still alive.
                XCTAssertEqual(demo.outcome, .defeat, entry.enemy.key)
            }
            XCTAssertEqual(final.killed.count, study.removed.values.filter { $0 == .killed }.count)
            XCTAssertEqual(demo.escaped, study.removed.values.filter { $0 == .leaked }.count)
            XCTAssertGreaterThan(demo.frames.last!.shots, 0, entry.enemy.key)
            XCTAssertTrue(demo.frames.contains { frame in frame.enemies.contains {
                study.spawnedTypes[$0.id] == entry.id && $0.hp < $0.maxHP
            } }, entry.enemy.key)
            for enemy in demo.frames.flatMap(\.enemies) {
                let typeID = try XCTUnwrap(study.spawnedTypes[enemy.id])
                let type = try XCTUnwrap(roster[typeID])
                XCTAssertEqual(enemy.assetName, type.imageName)
                XCTAssertEqual(enemy.speed, type.stats.speed)
                XCTAssertEqual(enemy.damageMin, type.stats.damageMin)
                XCTAssertEqual(enemy.discipline, type.stats.discipline)
                XCTAssertEqual(enemy.maxHP, type.stats.maxHP * difficulty.enemyHPMultiplier)
            }
            if entry.enemy.has(.rideDown) {
                XCTAssertTrue(demo.frames.allSatisfy { $0.blocked.isEmpty })
                XCTAssertGreaterThan(demo.escaped, 0)
            }
            print("ENEMY \(entry.enemy.key): \(demo.loopDuration)s, killed \(demo.frames.last!.killed.count), escaped \(demo.escaped)")
        }
    }

    @MainActor func testCommanderStudiesActuallySignalAndAdmitTheirReserves() throws {
        let fixture = try AuthoredDatabaseFixture()
        for foe in [Foe.mountedOfficer, .hillRearguard] {
            let demo = try TowerDemonstration(db: fixture.db, enemyID: foe.id)
            let study = try XCTUnwrap(demo.enemyStudy)
            let caller = try XCTUnwrap(study.spawnedTypes.first { $0.value == foe.id }?.key)
            XCTAssertTrue(demo.frames.contains { frame in
                frame.enemies.contains { $0.id == caller && ($0.reinforcementCall?.signalProgress ?? 0) > 0 }
            }, foe.rawValue)
            let callsMade = demo.frames.flatMap(\.enemies).filter { $0.id == caller }
                .compactMap { $0.reinforcementCall?.callsMade }.max() ?? 0
            XCTAssertGreaterThan(callsMade, 0, foe.rawValue)
            let children = study.spawnedTypes.filter { $0.value == Foe.redcoatRegular.id }
            XCTAssertFalse(children.isEmpty, foe.rawValue)
            let subject = try XCTUnwrap(fixture.db.enemyTypeDao.getAll().first { $0.id == foe.id })
            let rules = try XCTUnwrap(subject.reinforcementCallRules)
            XCTAssertLessThanOrEqual(children.count, rules.count * rules.maxCalls)
            for id in children.keys {
                let first = try XCTUnwrap(demo.frames.lazy.compactMap { $0.enemies.first { $0.id == id } }.first)
                XCTAssertLessThanOrEqual(first.pathDistance, first.speed * SimClock.dt + 0.001,
                                         "Reserves enter through the path entrance, not the commander's body")
            }
        }
    }

    @MainActor func testHoweStudyShowsDamagedEscortMoraleRecoveringDuringRecoveryDelay() throws {
        let fixture = try AuthoredDatabaseFixture()
        let demo = try TowerDemonstration(db: fixture.db, enemyID: Foe.howeAssault.id)
        let study = try XCTUnwrap(demo.enemyStudy)
        let escortIDs = Set(study.spawnedTypes.filter { $0.value == Foe.redcoatRegular.id }.map(\.key))
        XCTAssertEqual(escortIDs.count, 2)
        var sawRally = false
        for (previous, current) in zip(demo.frames, demo.frames.dropFirst()) {
            for enemy in current.enemies where escortIDs.contains(enemy.id) {
                guard let before = previous.enemies.first(where: { $0.id == enemy.id }) else { continue }
                if enemy.morale.impactAge < enemy.morale.rules.moraleRecoveryDelay,
                   enemy.morale.value > before.morale.value,
                   before.morale.value < before.morale.rules.moraleMax {
                    sawRally = true
                }
            }
        }
        XCTAssertTrue(sawRally, "Ordinary artillery damage and actual boss recovery must both occur")
    }

    @MainActor func testClintonStudyShowsAimedBarrageAndDefenderDamage() throws {
        let fixture = try AuthoredDatabaseFixture()
        let demo = try TowerDemonstration(db: fixture.db, enemyID: Foe.clintonSiege.id)
        XCTAssertTrue(demo.frames.contains { $0.enemies.contains { $0.boss?.barrageTarget != nil } })
        var damagedAtImpact = false
        for index in 1..<demo.frames.count {
            let previous = demo.frames[index - 1]
            let current = demo.frames[index]
            guard let oldBoss = previous.enemies.first(where: { $0.boss?.barrageTarget != nil }),
                  let target = oldBoss.boss?.barrageTarget,
                  let radius = oldBoss.boss?.rules.barrageRadius,
                  current.impacts.contains(where: {
                      Point($0.position.x, $0.position.y).distance(to: target) < 0.01
                  }) else { continue }
            let aftermath = demo.frames[index..<min(index + 4, demo.frames.count)]
            for before in previous.soldiers where Point(before.position.x, before.position.y).distance(to: target) <= radius {
                for frame in aftermath {
                    if let after = frame.soldiers.first(where: { $0.id == before.id }) {
                        if after.hp < before.hp { damagedAtImpact = true }
                    } else {
                        // Dead defenders leave the production presentation.
                        damagedAtImpact = true
                    }
                }
            }
        }
        XCTAssertTrue(damagedAtImpact, "The recorded warning must culminate in a real bombardment strike")
    }

    @MainActor func testEnemyMutationChangesDemonstrationAndInvalidDataStopsIt() throws {
        let fixture = try AuthoredDatabaseFixture()
        let original = try TowerDemonstration(db: fixture.db, enemyID: Foe.redcoatRegular.id)
        XCTAssertEqual(sqlite3_exec(fixture.connection, "UPDATE enemy_type SET speed=100 WHERE enemy_type_key='redcoat_regular'", nil, nil, nil), SQLITE_OK)
        let changed = try TowerDemonstration(db: fixture.db, enemyID: Foe.redcoatRegular.id)
        XCTAssertEqual(changed.frames.first!.enemies.first!.speed, 100)
        XCTAssertNotEqual(original.frames[30].enemies.first!.position, changed.frames[30].enemies.first!.position)
        XCTAssertEqual(sqlite3_exec(fixture.connection, "PRAGMA ignore_check_constraints=ON; UPDATE enemy_type SET max_hp=-1 WHERE enemy_type_key='redcoat_regular'", nil, nil, nil), SQLITE_OK)
        XCTAssertThrowsError(try TowerDemonstration(db: fixture.db, enemyID: Foe.redcoatRegular.id))
    }
}
