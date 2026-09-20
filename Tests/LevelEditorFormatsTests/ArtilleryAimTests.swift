import XCTest
@testable import LevelEditorFormats

final class ArtilleryAimTests: XCTestCase {
    private let origin = CGPoint.zero
    private func point(_ angle: Double) -> CGPoint {
        CGPoint(x: cos(angle) * 100, y: sin(angle) * 100)
    }

    func testGunMovesThroughSpritesBeforeItCanFire() {
        var aim = ArtilleryAim(heading: 0, firingTolerance: AuthoredDatabaseFixture.combatRules.firingTolerance)
        let aligned = aim.track(from: origin, to: point(.pi / 2),
                                radiansPerSecond: .pi / 2, deltaTime: 0.25)
        XCTAssertFalse(aligned)
        XCTAssertEqual(aim.heading, .pi / 8, accuracy: 1e-10)
        XCTAssertEqual(aim.facing.frameIndex, 30)
        XCTAssertTrue(aim.track(from: origin, to: point(.pi / 2),
                               radiansPerSecond: .pi / 2, deltaTime: 0.75))
        XCTAssertEqual(aim.heading, .pi / 2, accuracy: 1e-10)
    }

    func testWrapUsesShortPathAcrossWest() {
        var aim = ArtilleryAim(heading: 179 * .pi / 180, firingTolerance: AuthoredDatabaseFixture.combatRules.firingTolerance)
        XCTAssertTrue(aim.track(from: origin, to: point(-179 * .pi / 180),
                               radiansPerSecond: 10 * .pi / 180, deltaTime: 0.2))
        XCTAssertEqual(aim.heading, -179 * .pi / 180, accuracy: 1e-10)
    }

    func testNoOvershootAndEquivalentElapsedTime() {
        var once = ArtilleryAim(heading: 0, firingTolerance: AuthoredDatabaseFixture.combatRules.firingTolerance)
        var many = once
        once.track(from: origin, to: point(.pi), radiansPerSecond: 1, deltaTime: 1)
        for _ in 0..<60 {
            many.track(from: origin, to: point(.pi), radiansPerSecond: 1, deltaTime: 1.0 / 60)
        }
        XCTAssertEqual(once.heading, many.heading, accuracy: 1e-10)
        XCTAssertTrue(once.track(from: origin, to: point(.pi / 2), radiansPerSecond: 10, deltaTime: 1))
        XCTAssertEqual(once.heading, .pi / 2, accuracy: 1e-10)
    }

    func testMovingTargetKeepsChangingFacingDuringReloadPeriod() {
        var aim = ArtilleryAim(heading: 0, firingTolerance: AuthoredDatabaseFixture.combatRules.firingTolerance)
        var frames = Set<Int>()
        // No shots occur during this two-second reload; laying still follows
        // an enemy crossing from east to north at 45 degrees per second.
        for tick in 1...120 {
            let heading = Double(tick) / 120 * .pi / 2
            XCTAssertTrue(aim.track(from: origin, to: point(heading),
                                   radiansPerSecond: .pi, deltaTime: 1.0 / 60))
            frames.insert(aim.facing.frameIndex)
        }
        XCTAssertEqual(aim.heading, .pi / 2, accuracy: 1e-10)
        XCTAssertGreaterThan(frames.count, 6)
    }

    func testPauseInvalidTargetAndNewTargetDoNotSnapGun() {
        var aim = ArtilleryAim(heading: 0, firingTolerance: AuthoredDatabaseFixture.combatRules.firingTolerance)
        XCTAssertFalse(aim.track(from: origin, to: point(.pi / 2), radiansPerSecond: 1, deltaTime: 0))
        XCTAssertFalse(aim.track(from: origin, to: origin, radiansPerSecond: 1, deltaTime: 1))
        XCTAssertFalse(aim.track(from: origin, to: CGPoint(x: CGFloat.nan, y: 1), radiansPerSecond: 1, deltaTime: 1))
        XCTAssertEqual(aim.heading, 0)
        XCTAssertFalse(aim.track(from: origin, to: point(-.pi / 2), radiansPerSecond: 1, deltaTime: 0.1))
        XCTAssertEqual(aim.heading, -0.1, accuracy: 1e-10)
    }

    func testSwivelAcquiresTargetBeforeSiegeGun() throws {
        var swivel = ArtilleryAim(heading: 0, firingTolerance: AuthoredDatabaseFixture.combatRules.firingTolerance), siege = swivel
        XCTAssertTrue(swivel.track(from: origin, to: point(.pi / 2),
            radiansPerSecond: try AuthoredDatabaseFixture.tower(.areaOfEffect, level: 4, branch: 2).turnRate, deltaTime: 0.5))
        XCTAssertFalse(siege.track(from: origin, to: point(.pi / 2),
            radiansPerSecond: try AuthoredDatabaseFixture.tower(.areaOfEffect, level: 4, branch: 4).turnRate, deltaTime: 0.5))
        XCTAssertEqual(try AuthoredDatabaseFixture.tower(.areaOfEffect, level: 4, branch: 2).attackMode, .grapeshot)
        XCTAssertEqual(try AuthoredDatabaseFixture.tower(.areaOfEffect, level: 3, branch: 1).attackMode, .shell)
    }

    func testSweptGrapeshotHitsBetweenTicksAndRejectsOffAxisTargets() {
        XCTAssertEqual(GrapeshotFlight.hitFraction(from: origin, to: CGPoint(x: 100, y: 0),
                                                  target: CGPoint(x: 50, y: 5), radius: AuthoredDatabaseFixture.combatRules.grapeshotHitRadius), 0.5)
        XCTAssertNil(GrapeshotFlight.hitFraction(from: origin, to: CGPoint(x: 100, y: 0),
                                               target: CGPoint(x: 50, y: 25), radius: AuthoredDatabaseFixture.combatRules.grapeshotHitRadius))
        XCTAssertNil(GrapeshotFlight.hitFraction(from: origin, to: CGPoint(x: 100, y: 0),
                                               target: CGPoint(x: 125, y: 0), radius: AuthoredDatabaseFixture.combatRules.grapeshotHitRadius))
        XCTAssertEqual(AuthoredDatabaseFixture.combatRules.grapeshotSpread[2], 0)
        XCTAssertEqual(AuthoredDatabaseFixture.combatRules.grapeshotSpread.first!, -AuthoredDatabaseFixture.combatRules.grapeshotSpread.last!)
    }
}
