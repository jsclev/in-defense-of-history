import XCTest
import SQLite3
@testable import LevelEditorFormats

final class RangerDemonstrationTests: XCTestCase {
    @MainActor func testRangerLessonShowsDamageConcealmentAndWashingtonRevealInOrder() throws {
        let fixture = try AuthoredDatabaseFixture()
        let writes = sqlite3_total_changes(fixture.connection)
        let demo = try TowerDemonstration(db: fixture.db, enemyID: Foe.queensRanger.id)
        XCTAssertEqual(sqlite3_total_changes(fixture.connection), writes, "Staging must not alter player state")
        XCTAssertEqual(demo.tower.kind, .ranged)
        XCTAssertEqual(demo.supportingTowers.map(\.kind), [.melee, .ranged])
        let frames = demo.frames
        let damage = try XCTUnwrap(frames.firstIndex { $0.damageBySlot[0, default: 0] > 0 })
        let hide = try XCTUnwrap(frames.firstIndex { $0.enemies.first?.isConcealed == true })
        let reveal = try XCTUnwrap(frames.indices.first { $0 > hide && frames[$0].enemies.first?.isConcealed == false })
        let lastTowerHit = try XCTUnwrap(frames.firstIndex { $0.damageBySlot[2, default: 0] > 0 })
        XCTAssertLessThan(damage, hide)
        XCTAssertGreaterThanOrEqual(lastTowerHit, reveal)
        let firstHero = try XCTUnwrap(frames.first?.heroes.first)
        let washington = try XCTUnwrap(fixture.db.heroDao.getAll().first { $0.id == UUID(uuidString: "fac6c094-9cbc-474a-975e-8d2a170e07da") })
        XCTAssertEqual(firstHero.baseAssetName, washington.unitImageName)
        XCTAssertGreaterThan(firstHero.position.x, demo.road[demo.road.count / 2].x)
        XCTAssertEqual(firstHero.maxHP, try fixture.db.heroDao.getCombatStats(heroID: washington.id).hp)
        for frame in frames[...reveal] {
            XCTAssertEqual(frame.heroes.first?.position, firstHero.position,
                           "Washington waits at his station until the Ranger reaches him")
            XCTAssertFalse(frame.heroPoses[0]?.isWalking ?? true)
        }
        let hidden = frames[hide..<reveal]
        let clearOfInfantry = try XCTUnwrap(hidden.firstIndex { frame in
            guard let enemy = frame.enemies.first, let lastInfantry = frame.soldiers.map(\.position.x).max() else { return false }
            return enemy.position.x > lastInfantry + 45
        })
        XCTAssertGreaterThan(frames[reveal].seconds - frames[clearOfInfantry].seconds, 0.8,
                             "Show a distinct hidden walk after clearing the infantry")
        for pair in zip(hidden, hidden.dropFirst()) {
            XCTAssertEqual(pair.0.enemies.first?.hp, pair.1.enemies.first?.hp)
            XCTAssertEqual(pair.0.shotsBySlot, pair.1.shotsBySlot, "Ranged towers lose the concealed target")
            XCTAssertTrue(pair.1.blocked.isEmpty)
        }
        let exposed = try XCTUnwrap(frames[reveal].enemies.first)
        let hero = try XCTUnwrap(frames[reveal].heroes.first)
        let rules = try XCTUnwrap(exposed.concealment?.rules)
        XCTAssertLessThanOrEqual(hypot(exposed.position.x - hero.position.x, exposed.position.y - hero.position.y), rules.heroRevealRadius + 6)
        XCTAssertLessThan(Int64((frames[reveal].seconds / SimClock.dt).rounded()),
                          try XCTUnwrap(frames[reveal - 1].enemies.first?.concealment?.hiddenUntilTick),
                          "Washington must reveal the Ranger before its hiding timer expires")
        let engaged = try XCTUnwrap(frames.indices.first { $0 >= reveal && frames[$0].blocked.contains(exposed.id) })
        XCTAssertGreaterThan(exposed.position.x - (frames[reveal].soldiers.map(\.position.x).max() ?? exposed.position.x), 150,
                             "The reveal must be clearly separated from the infantry")
        let hitsDuringEngagement = zip(frames.dropFirst(), frames).filter { current, previous in
            previous.blocked.contains(exposed.id)
                && current.damageBySlot[2, default: 0] > previous.damageBySlot[2, default: 0]
        }
        XCTAssertGreaterThanOrEqual(hitsDuringEngagement.count, 2,
                                    "Show the final ranged post repeatedly damaging the Ranger held by Washington")
        XCTAssertEqual(frames.last?.damageBySlot[1, default: 0], 0)
        XCTAssertEqual(demo.escaped, 0)
        XCTAssertEqual(frames.last?.killed.count, 1)
        let killed = try XCTUnwrap(frames.firstIndex { $0.killed.contains(exposed.id) })
        XCTAssertTrue(frames[killed - 1].blocked.contains(exposed.id),
                      "The Ranger dies during the final engagement instead of escaping")
        func seconds(_ index: Int) -> Double { Double(index) * SimClock.dt }
        print("RANGER LESSON: hit \(seconds(damage))s; hide \(seconds(hide))s; clear of infantry \(seconds(clearOfInfantry))s; stationary Washington reveals \(seconds(reveal))s; engages \(seconds(engaged))s; final tower hit \(seconds(lastTowerHit))s; \(hitsDuringEngagement.count) hits while engaged; ends \(demo.loopDuration)s")
    }
}
