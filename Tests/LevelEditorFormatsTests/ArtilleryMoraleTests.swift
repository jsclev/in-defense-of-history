import XCTest
@testable import LevelEditorFormats

final class ArtilleryMoraleTests: XCTestCase {
    func testBlastUsesDistanceAndDisciplineAndStopsAtRadius() throws {
        var tuning = try AuthoredDatabaseFixture.tower("Area of Effect", level: 1, branch: 1)
        tuning.terrorMin = 24
        tuning.terrorMax = 44
        tuning.aoeRadius = 95
        let strike = ArtilleryMoraleStrike(tuning: tuning)
        XCTAssertEqual(strike.loss(distance: 0, discipline: 0.6), 17.6, accuracy: 1e-8)
        XCTAssertEqual(strike.loss(distance: 95, discipline: 0.2), 19.2, accuracy: 1e-8)
        XCTAssertEqual(strike.loss(distance: 96, discipline: 0), 0)
        XCTAssertEqual(strike.loss(distance: 0, discipline: 1), 0)
    }

    func testVisibilityIsStrictlyBelowNinetyAndRecovers() {
        var morale = EnemyMorale()
        XCTAssertFalse(morale.isVisible)
        morale.apply(loss: 10, direction: 1)
        XCTAssertFalse(morale.isVisible)
        morale.apply(loss: 1, direction: -1)
        XCTAssertTrue(morale.isVisible)
        morale.advance(seconds: 3)
        XCTAssertEqual(morale.value, 89)
        morale.advance(seconds: 2)
        XCTAssertEqual(morale.value, 90)
        XCTAssertFalse(morale.isVisible)
    }

    func testConsecutiveHitsRestartAnimationWithoutLosingMoraleDamage() {
        var morale = EnemyMorale()
        morale.apply(loss: 25, direction: -1)
        morale.advance(seconds: 0.1)
        let currentVisual = morale.displayedValue
        morale.apply(loss: 30, direction: 1)
        XCTAssertEqual(morale.value, 45)
        XCTAssertEqual(morale.displayedValue, currentVisual)
        XCTAssertEqual(morale.impactAge, 0)
        XCTAssertEqual(morale.flinchDirection, 1)
        morale.advance(seconds: 0.8)
        XCTAssertEqual(morale.displayedValue, 45)
        XCTAssertEqual(morale.response, 0)
    }

    func testPauseRecoveryFrameRateAndClamping() {
        var once = EnemyMorale()
        once.apply(loss: 500, direction: 1)
        var many = once
        once.advance(seconds: 0)
        XCTAssertEqual(once.value, 0)
        once.advance(seconds: 20)
        for _ in 0..<1200 { many.advance(seconds: 1 / 60.0) }
        XCTAssertEqual(once.value, many.value, accuracy: 1e-8)
        once.advance(seconds: 500)
        XCTAssertEqual(once.value, 100)
    }

    func testSwivelShotAndTuningSnapshot() throws {
        var tuning = try AuthoredDatabaseFixture.tower("Area of Effect", level: 4, branch: 2)
        tuning.terrorMin = 20
        tuning.terrorMax = 32
        let strike = ArtilleryMoraleStrike(tuning: tuning)
        tuning.terrorMax = 100
        XCTAssertEqual(strike.loss(distance: 0, discipline: 0.6), 12.8, accuracy: 1e-8)
        var morale = EnemyMorale()
        XCTAssertFalse(morale.apply(loss: 0, direction: 1))
        XCTAssertFalse(morale.isVisible)
    }

    func testLevelOneHitsDrainTheDisplayedMeterWithoutRefillingAfterTheHit() throws {
        var tuning = try AuthoredDatabaseFixture.tower("Area of Effect", level: 1, branch: 1)
        tuning.terrorMin = 24
        tuning.terrorMax = 44
        tuning.aoeRadius = 95
        let strike = ArtilleryMoraleStrike(tuning: tuning)
        var morale = EnemyMorale()
        for remaining in [0.824, 0.648, 0.472, 0.296, 0.12, 0.0] {
            let before = morale.displayedFraction
            morale.apply(loss: strike.loss(distance: 0, discipline: 0.6), direction: 1)
            XCTAssertEqual(morale.remainingFraction, remaining, accuracy: 1e-8)
            XCTAssertEqual(morale.displayedFraction, before, accuracy: 1e-8)
            var previous = before
            for _ in 0..<20 {
                morale.advance(seconds: 0.02)
                XCTAssertLessThanOrEqual(morale.displayedFraction, previous)
                XCTAssertGreaterThanOrEqual(morale.displayedFraction + 1e-8, remaining)
                previous = morale.displayedFraction
            }
            XCTAssertEqual(morale.displayedFraction, remaining, accuracy: 1e-8)
            morale.advance(seconds: 1)
            XCTAssertEqual(morale.displayedFraction, remaining, accuracy: 1e-8)
        }
        XCTAssertTrue(morale.isVisible)
        XCTAssertEqual(morale.displayedFraction, 0)
    }

    func testEmptyMeterOnlyRefillsWhenMoraleActuallyRecovers() {
        var morale = EnemyMorale()
        morale.apply(loss: 100, direction: 1)
        morale.advance(seconds: EnemyMorale.recoveryDelay)
        XCTAssertEqual(morale.displayedFraction, 0)
        morale.advance(seconds: 2)
        XCTAssertEqual(morale.remainingFraction, 0.01, accuracy: 1e-8)
        XCTAssertEqual(morale.displayedFraction, 0.01, accuracy: 1e-8)
    }
}
