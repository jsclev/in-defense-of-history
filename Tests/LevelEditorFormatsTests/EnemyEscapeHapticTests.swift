import XCTest
@testable import LevelEditorFormats

final class EnemyEscapeHapticTests: XCTestCase {
    func testSeparateEscapesSignalLossAndBurstDoesNotAccumulateDelayedFeedback() {
        var policy = EnemyEscapeHapticPolicy()
        XCTAssertEqual(policy.feedback(previousCount: 0, escapeCount: 1, livesRemaining: 19,
                                       isEnabled: true, isActive: true, at: 10), .lifeLoss)
        XCTAssertNil(policy.feedback(previousCount: 1, escapeCount: 5, livesRemaining: 15,
                                     isEnabled: true, isActive: true, at: 10.1))
        XCTAssertNil(policy.feedback(previousCount: 5, escapeCount: 6, livesRemaining: 14,
                                     isEnabled: true, isActive: true, at: 10.499))
        XCTAssertNil(policy.feedback(previousCount: 6, escapeCount: 6, livesRemaining: 14,
                                     isEnabled: true, isActive: true, at: 11))
        XCTAssertEqual(policy.feedback(previousCount: 6, escapeCount: 7, livesRemaining: 13,
                                       isEnabled: true, isActive: true, at: 11.1), .lifeLoss)
    }

    func testLossBecomesAvailableAtHalfSecondRegardlessOfEscapeCount() {
        var policy = EnemyEscapeHapticPolicy()
        XCTAssertEqual(policy.feedback(previousCount: 0, escapeCount: 20, livesRemaining: 80,
                                       isEnabled: true, isActive: true, at: 10), .lifeLoss)
        XCTAssertEqual(policy.feedback(previousCount: 20, escapeCount: 40, livesRemaining: 60,
                                       isEnabled: true, isActive: true, at: 10.5), .lifeLoss)
    }

    func testDefeatOverridesRecentLossAndCoalescedLossesPlayOnlyDefeat() {
        var policy = EnemyEscapeHapticPolicy()
        XCTAssertEqual(policy.feedback(previousCount: 0, escapeCount: 1, livesRemaining: 1,
                                       isEnabled: true, isActive: true, at: 10), .lifeLoss)
        XCTAssertEqual(policy.feedback(previousCount: 1, escapeCount: 2, livesRemaining: 0,
                                       isEnabled: true, isActive: true, at: 10.01), .defeat)
        XCTAssertNil(policy.feedback(previousCount: 2, escapeCount: 2, livesRemaining: 0,
                                     isEnabled: true, isActive: true, at: 11))
        var coalesced = EnemyEscapeHapticPolicy()
        XCTAssertEqual(coalesced.feedback(previousCount: 0, escapeCount: 20, livesRemaining: 0,
                                          isEnabled: true, isActive: true, at: 1), .defeat)
    }

    func testMutedAndInactiveLossesDoNotReplayWhenEnabledOrResumed() {
        var policy = EnemyEscapeHapticPolicy()
        XCTAssertNil(policy.feedback(previousCount: 0, escapeCount: 1, livesRemaining: 19,
                                     isEnabled: false, isActive: true, at: 10))
        XCTAssertNil(policy.feedback(previousCount: 1, escapeCount: 2, livesRemaining: 18,
                                     isEnabled: true, isActive: false, at: 10.1))
        XCTAssertNil(policy.feedback(previousCount: 2, escapeCount: 2, livesRemaining: 18,
                                     isEnabled: true, isActive: true, at: 10.2))
        XCTAssertEqual(policy.feedback(previousCount: 2, escapeCount: 3, livesRemaining: 17,
                                       isEnabled: true, isActive: true, at: 10.2), .lifeLoss)
        XCTAssertNil(policy.feedback(previousCount: 3, escapeCount: 4, livesRemaining: 0,
                                     isEnabled: false, isActive: true, at: 11))
    }

    func testLoadingAndCounterResetDoNotProduceLossFeedback() {
        var policy = EnemyEscapeHapticPolicy()
        for (old, new, lives) in [(0, 0, 20), (8, 0, 20), (0, 0, 0)] {
            XCTAssertNil(policy.feedback(previousCount: old, escapeCount: new, livesRemaining: lives,
                                         isEnabled: true, isActive: true, at: 10))
        }
    }
}
