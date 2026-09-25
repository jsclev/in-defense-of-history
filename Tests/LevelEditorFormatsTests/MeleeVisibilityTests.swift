import XCTest
@testable import LevelEditorFormats

final class MeleeVisibilityTests: XCTestCase {
    func testSquadsAtOneFlagHaveDistinctPostsAndSeparateFlagsKeepTheirFormation() {
        let rules = AuthoredDatabaseFixture.combatRules
        let formation = MeleeFormation(rules: rules)
        let flag = Point(100, 100), otherFlag = Point(500, 100)
        let together = formation.sharedPosts(squads: [(2, flag, 3), (1, flag, 3), (3, otherFlag, 3)])
        let shared = together[1]! + together[2]!
        XCTAssertEqual(Set(shared).count, 6, "Squads must not occupy the same three posts")
        for i in shared.indices {
            for j in shared.indices where j > i {
                XCTAssertGreaterThan(shared[i].distance(to: shared[j]), rules.meleePostSpread * 0.9)
            }
        }
        let separated = formation.sharedPosts(squads: [(1, flag, 3), (2, otherFlag, 3)])
        XCTAssertEqual(separated[1], (0..<3).map { formation.postPoint(index: $0, of: 3, rallyPoint: flag) })
        XCTAssertEqual(separated[2], together[3], "Unshared flags retain the existing formation")
        XCTAssertEqual(together, formation.sharedPosts(squads: [(3, otherFlag, 3), (1, flag, 3), (2, flag, 3)]))
    }

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
