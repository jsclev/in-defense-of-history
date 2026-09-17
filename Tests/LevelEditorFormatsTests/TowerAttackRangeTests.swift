import XCTest
@testable import LevelEditorFormats

final class TowerAttackRangeTests: XCTestCase {
    private func enemy(_ id: Int, _ x: Double, _ y: Double, hp: Double = 10) -> TargetCandidate {
        TargetCandidate(id: id, position: Point(x, y), pathIndex: 0,
                        pathDistance: Double(id), hp: hp, morale: 100, isBroken: false)
    }

    func testTargetingRejectsTheOldCircularOverreach() {
        // At range 300 the visible top/bottom boundary is 210 map units.
        // The previous targeting circle incorrectly accepted y=250.
        let command = RangedTargetCommand(tower: TowerTargetingContext(
            slotIndex: 0, position: .zero, range: 300, targeting: .strongest),
            enemies: [enemy(0, 0, 250, hp: 1000), enemy(1, 0, 209)], paths: [])
        XCTAssertFalse(command.isInRange(command.enemies[0]))
        XCTAssertTrue(command.isInRange(command.enemies[1]))
        XCTAssertEqual(command.execute()?.id, 1)
    }

    func testAllTargetPrioritiesRejectEnemiesOutsideRange() {
        for targeting in Targeting.allCases {
            let command = RangedTargetCommand(tower: TowerTargetingContext(
                slotIndex: 0, position: .zero, range: 300, targeting: targeting),
                enemies: [enemy(0, 301, 0), enemy(1, 0, -211)], paths: [])
            XCTAssertNil(command.execute())
        }
        let zeroRange = RangedTargetCommand(tower: TowerTargetingContext(
            slotIndex: 0, position: .zero, range: 0, targeting: .first),
            enemies: [enemy(0, 0, 0)], paths: [])
        XCTAssertFalse(zeroRange.isInRange(zeroRange.enemies[0]))
        XCTAssertNil(zeroRange.execute())
    }

    func testPelletTravelEndsAtTheVisibleBoundaryInEveryDirection() {
        let reach = TowerAttackRange(300)
        for degrees in 0..<360 {
            let heading = Double(degrees) * .pi / 180
            let distance = reach.travelDistance(heading: heading)
            let x = cos(heading) * distance, y = sin(heading) * distance
            XCTAssertEqual(pow(x / 300, 2) + pow(y / 210, 2), 1, accuracy: 1e-10)
            XCTAssertFalse(reach.contains(CGPoint(x: x * 1.001, y: y * 1.001), from: .zero))
        }
    }

    func testBodyOffsetIsClampedWithoutMovingAnInRangeAim() {
        let reach = TowerAttackRange(300)
        let origin = CGPoint(x: 500, y: 400)
        let inside = CGPoint(x: 500, y: 195)
        XCTAssertEqual(reach.clamped(inside, from: origin), inside)
        let outsideBody = CGPoint(x: 500, y: 183)
        XCTAssertEqual(reach.clamped(outsideBody, from: origin), CGPoint(x: 500, y: 190))
    }

    func testBlastRadiusAndFiringRangeAreIndependent() throws {
        var tuning = try AuthoredDatabaseFixture.tower("Area of Effect", level: 1, branch: 1)
        tuning.aoeRadius = 95
        let reach = tuning.attackRange
        tuning.aoeRadius *= 1.35
        XCTAssertEqual(tuning.attackRange, reach)
        let shock = ArtilleryMoraleStrike(tuning: tuning)
        tuning.range *= 2
        XCTAssertEqual(tuning.aoeRadius, 128.25)
        XCTAssertEqual(ArtilleryMoraleStrike(tuning: tuning), shock)
    }
}
