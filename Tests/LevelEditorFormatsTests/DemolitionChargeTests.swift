import XCTest
@testable import LevelEditorFormats

final class DemolitionChargeTests: XCTestCase {
    func testAutomaticChargeWaitsForOutgoingBoundaryInEitherDirection() {
        var charge = DemolitionCharge(preparationSeconds: 8)
        charge.place(at: .zero)
        for path in [Path(points: [Point(-200, 0), Point(200, 0)]),
                     Path(points: [Point(200, 0), Point(-200, 0)])] {
            XCTAssertFalse(charge.willEnemyExitBlast(on: path, from: 99, advancingBy: 3, radius: 100))
            XCTAssertFalse(charge.willEnemyExitBlast(on: path, from: 101, advancingBy: 3, radius: 100))
            XCTAssertFalse(charge.willEnemyExitBlast(on: path, from: 200, advancingBy: 3, radius: 100))
            XCTAssertTrue(charge.willEnemyExitBlast(on: path, from: 299, advancingBy: 3, radius: 100))
            XCTAssertFalse(charge.willEnemyExitBlast(on: path, from: 301, advancingBy: 3, radius: 100))
        }
    }

    func testAutomaticChargeFollowsBendsAndDoesNotSkipAnExitAndReentry() {
        var charge = DemolitionCharge(preparationSeconds: 8)
        charge.place(at: .zero)
        let turn = Path(points: [Point(-200, 0), Point(0, 0), Point(0, 200)])
        XCTAssertFalse(charge.willEnemyExitBlast(on: turn, from: 199, advancingBy: 3, radius: 100))
        XCTAssertTrue(charge.willEnemyExitBlast(on: turn, from: 299, advancingBy: 3, radius: 100))
        let loop = Path(points: [Point(0, 0), Point(120, 0), Point(0, 0), Point(-200, 0)])
        XCTAssertTrue(charge.willEnemyExitBlast(on: loop, from: 90, advancingBy: 100, radius: 100))
    }

    func testAutomaticChargeUsesDamagePointAndTheEnemiesOwnLane() {
        var charge = DemolitionCharge(preparationSeconds: 8)
        charge.place(at: .zero)
        let path = Path(points: [Point(-200, 12), Point(200, 12)])
        XCTAssertTrue(charge.willEnemyExitBlast(on: path, from: 299, advancingBy: 3,
            radius: 100, targetOffset: CGPoint(x: 0, y: -12)))
        let missedLane = Path(points: [Point(-200, 120), Point(200, 120)])
        XCTAssertFalse(charge.willEnemyExitBlast(on: missedLane, from: 299, advancingBy: 3,
            radius: 100, targetOffset: CGPoint(x: 0, y: -12)))
    }

    func testAutomaticChargeIgnoresStoppedBackwardUnplacedAndReloadingStates() {
        let path = Path(points: [Point(-200, 0), Point(200, 0)])
        var charge = DemolitionCharge(preparationSeconds: 8)
        XCTAssertFalse(charge.willEnemyExitBlast(on: path, from: 299, advancingBy: 3, radius: 100))
        charge.place(at: .zero)
        for travel in [0.0, -3, Double.nan, Double.infinity] {
            XCTAssertFalse(charge.willEnemyExitBlast(on: path, from: 299, advancingBy: travel, radius: 100))
        }
        charge.detonate()
        XCTAssertFalse(charge.willEnemyExitBlast(on: path, from: 299, advancingBy: 3, radius: 100))
        charge.advance(seconds: 8)
        XCTAssertTrue(charge.willEnemyExitBlast(on: path, from: 299, advancingBy: 3, radius: 100))
    }

    func testAutomaticChargeCoversAPathEndingWithinTheBlastAndRepeatedVertices() {
        var charge = DemolitionCharge(preparationSeconds: 8)
        charge.place(at: .zero)
        let path = Path(points: [Point(-200, 0), Point(0, 0), Point(0, 0), Point(50, 0)])
        XCTAssertFalse(charge.willEnemyExitBlast(on: path, from: 200, advancingBy: 2, radius: 100))
        XCTAssertTrue(charge.willEnemyExitBlast(on: path, from: 249, advancingBy: 3, radius: 100))
    }

    func testNewChargeIsReadyButRemainsUnplacedUntilPlayerChoosesASite() {
        var charge = DemolitionCharge(preparationSeconds: 8)
        XCTAssertTrue(charge.isReadyForPlacement)
        XCTAssertEqual(charge.remainingSeconds, 0)
        XCTAssertNil(charge.position)
        XCTAssertFalse(charge.detonate())
        charge.advance(seconds: 500)
        XCTAssertTrue(charge.isReadyForPlacement)
        XCTAssertNil(charge.position)
        XCTAssertFalse(charge.detonate())
    }

    func testFirstPlacementIsImmediatelyArmedAndOnlyDetonationStartsCooldown() {
        var charge = DemolitionCharge(preparationSeconds: 8)
        charge.place(at: CGPoint(x: 20, y: 30))
        XCTAssertFalse(charge.isReadyForPlacement)
        XCTAssertTrue(charge.isReady)
        XCTAssertTrue(charge.detonate())
        XCTAssertEqual(charge.remainingSeconds, 8)
        charge.advance(seconds: 7.9)
        XCTAssertFalse(charge.isReady)
        XCTAssertFalse(charge.detonate())
        charge.advance(seconds: 500)
        XCTAssertTrue(charge.isReady)
        XCTAssertEqual(charge.position, CGPoint(x: 20, y: 30))
        XCTAssertTrue(charge.detonate())
        XCTAssertFalse(charge.detonate())
        XCTAssertEqual(charge.remainingSeconds, 8)
        charge.advance(seconds: 7.99)
        XCTAssertFalse(charge.isReady)
    }

    func testPauseAndInvalidTimeDoNotAdvancePreparation() {
        var charge = DemolitionCharge(preparationSeconds: 8)
        charge.place(at: .zero)
        XCTAssertTrue(charge.detonate())
        for elapsed in [0.0, -2, Double.infinity, Double.nan] { charge.advance(seconds: elapsed) }
        XCTAssertEqual(charge.remainingSeconds, 8)
        charge.advance(seconds: 2)
        XCTAssertEqual(charge.progress, 0.25)
    }

    func testRelocatingRestartsPreparationButSelectingSameSiteDoesNot() {
        var charge = DemolitionCharge(preparationSeconds: 8)
        charge.place(at: .zero)
        charge.place(at: .zero)
        XCTAssertTrue(charge.isReady)
        charge.place(at: CGPoint(x: 10, y: 20))
        XCTAssertFalse(charge.isReady)
        XCTAssertEqual(charge.remainingSeconds, 8)
    }

    func testPathPlacementClipsLongSegmentsAtTheRealRangeBoundary() throws {
        let reach = TowerAttackRange(300, verticalFraction: AuthoredDatabaseFixture.combatRules.rangeVerticalFraction)
        let path = Path(points: [Point(-1000, 0), Point(1000, 0)])
        let point = try XCTUnwrap(reach.nearestPathPoint(to: CGPoint(x: 400, y: 50), from: .zero, paths: [path]))
        XCTAssertEqual(point.x, 300, accuracy: 1e-8)
        XCTAssertEqual(point.y, 0, accuracy: 1e-8)
        XCTAssertTrue(reach.contains(point, from: .zero))
        XCTAssertNil(reach.nearestPathPoint(to: .zero, from: .zero,
            paths: [Path(points: [Point(-500, 211), Point(500, 211)])]))
    }

    func testPlacementChoosesNearestReachableLaneAndHandlesDegenerateSegments() throws {
        let reach = TowerAttackRange(300, verticalFraction: AuthoredDatabaseFixture.combatRules.rangeVerticalFraction)
        let near = Path(points: [Point(0, 30), Point(0, 30), Point(100, 30)])
        let far = Path(points: [Point(0, 130), Point(100, 130)])
        XCTAssertEqual(reach.nearestPathPoint(to: CGPoint(x: 50, y: 40), from: .zero,
            paths: [far, near]), CGPoint(x: 50, y: 30))
        XCTAssertNil(reach.nearestPathPoint(to: .zero, from: .zero, paths: []))
        XCTAssertNil(TowerAttackRange(0, verticalFraction: AuthoredDatabaseFixture.combatRules.rangeVerticalFraction).nearestPathPoint(to: .zero, from: .zero, paths: [near]))
    }

    func testSappersMoveToEngineersWhileThreeArtilleryChoicesRemain() throws {
        let db = Db(dbPath: Db.authoredDatabaseURL.path, fullRefresh: false)
        defer { db.close() }
        let all = try db.towerTypeDao.getTowerLevelsByBranch()
        let branches = try XCTUnwrap(all[.areaOfEffect]?[4])
        XCTAssertEqual(branches.count, 3)
        XCTAssertEqual(branches.keys.sorted(), [1, 2, 4])
        let siege = try XCTUnwrap(branches[4])
        XCTAssertEqual(siege.fireInterval, 4.8)
        XCTAssertEqual(siege.range, 478.63)
        XCTAssertEqual(siege.aoeRadius, 0)
        XCTAssertTrue(branches.values.allSatisfy { $0.demolitionPreparationSeconds == nil })
        let engineers = try XCTUnwrap(all[.special]?[4])
        XCTAssertEqual(engineers.keys.sorted(), [1, 2, 3])
        let tuning = try XCTUnwrap(engineers[3])
        XCTAssertEqual(tuning.demolitionPreparationSeconds, 8)
        XCTAssertEqual(tuning.fireInterval, 0)
        XCTAssertEqual(tuning.range, 410.25)
        XCTAssertEqual(tuning.aoeRadius, 180)
        XCTAssertTrue(branches.filter { $0.key != 4 }.allSatisfy { $0.value.demolitionPreparationSeconds == nil })
        let names = try db.towerTypeDao.getNamesByLevel()
        XCTAssertEqual(try XCTUnwrap(names[.areaOfEffect]?[4]).keys.sorted(), [1, 2, 4])
        XCTAssertEqual(try XCTUnwrap(names[.special]?[4]).keys.sorted(), [1, 2, 3])
    }

    func testExistingSerializedTowerTuningRemainsAutomatic() throws {
        let old = try AuthoredDatabaseFixture.tower(.ranged, level: 1, branch: 1)
        let bytes = try JSONEncoder().encode(old)
        XCTAssertNil(try JSONDecoder().decode(TowerLevel.self, from: bytes).demolitionPreparationSeconds)
        let new = try AuthoredDatabaseFixture.tower(.special, level: 4, branch: 3)
        XCTAssertEqual(try JSONDecoder().decode(TowerLevel.self, from: JSONEncoder().encode(new)), new)
    }
}
