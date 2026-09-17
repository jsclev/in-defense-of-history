import XCTest
@testable import LevelEditorFormats

final class MeleeVisibilityTests: XCTestCase {
    func testFightersSeparateFromTheEnemyWithoutTeleportingOrLosingTheTarget() {
        for side in [-1.0, 1.0] {
            var unit = MilitiaUnit(position: Point(0, 10), hp: 100)
            unit.state = .fighting; unit.targetSpawnID = 7; unit.combatSide = side
            let context = MilitiaContext(rules: AuthoredDatabaseFixture.combatRules, freeEnemies: [], targetPosition: .zero, rallyPoint: .zero,
                                         towerPosition: .zero, leashRadius: 150, engageScanRadius: 100)
            for _ in 0..<60 {
                switch MilitiaAI.decide(unit, context: context) {
                case let .move(toward):
                    let previous = unit.position
                    let distance = previous.distance(to: toward)
                    let step = AuthoredDatabaseFixture.combatRules.meleeMoveSpeed * SimClock.dt
                    unit.position = distance <= step ? toward : Point.lerp(previous, toward, step / distance)
                    XCTAssertLessThanOrEqual(previous.distance(to: unit.position), step + 1e-8)
                case .strike(let target): XCTAssertEqual(target, 7)
                default: XCTFail("Living fighter lost its melee target")
                }
            }
            XCTAssertGreaterThan(abs(unit.position.x), 75)
            XCTAssertEqual(unit.state, .fighting)
            XCTAssertEqual(unit.targetSpawnID, 7)
        }
    }

    func testDeadOrDepartedEnemyReleasesTheFighter() {
        var unit = MilitiaUnit(position: .zero, hp: 100)
        unit.state = .fighting; unit.targetSpawnID = 7
        let context = MilitiaContext(rules: AuthoredDatabaseFixture.combatRules, freeEnemies: [], targetPosition: nil, rallyPoint: .zero,
                                     towerPosition: .zero, leashRadius: 150, engageScanRadius: 100)
        XCTAssertEqual(MilitiaAI.decide(unit, context: context), .disengage)
    }
}
