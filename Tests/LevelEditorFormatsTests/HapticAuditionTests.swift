import CoreHaptics
import XCTest
@testable import LevelEditorFormats

@MainActor
final class HapticAuditionTests: XCTestCase {
    private final class Playback: HapticAuditionPlayback {
        var played: [HapticAuditionSample] = []
        var pending: CheckedContinuation<Void, Error>?
        var stopCount = 0
        func play(_ sample: HapticAuditionSample) async throws {
            precondition(pending == nil, "Patterns must never overlap")
            played.append(sample)
            try await withCheckedThrowingContinuation { pending = $0 }
        }
        func finish() {
            let next = pending; pending = nil; next?.resume()
        }
        func fail() {
            let next = pending; pending = nil
            next?.resume(throwing: NSError(domain: "Fixture", code: 1,
                                           userInfo: [NSLocalizedDescriptionKey: "Playback failed"]))
        }
        func stop() {
            stopCount += 1
            let next = pending; pending = nil
            next?.resume(throwing: CancellationError())
        }
    }

    private final class Gap {
        var durations: [Duration] = []
        var pending: CheckedContinuation<Void, Error>?
        func wait(_ duration: Duration) async throws {
            durations.append(duration)
            try await withCheckedThrowingContinuation { pending = $0 }
        }
        func finish() {
            let next = pending; pending = nil; next?.resume()
        }
    }

    private func settle() async {
        for _ in 0..<30 { await Task.yield() }
    }

    func testProductionDefaultDoesNotAutoplayOnLaunchOrReturn() async {
        let playback = Playback(), gap = Gap()
        let player = HapticAuditionPlayer(playback: playback, pause: { try await gap.wait($0) })
        player.setActive(true)
        await settle()
        player.setActive(false)
        player.setActive(true)
        await settle()
        XCTAssertFalse(HapticAuditionPlayer.enabled)
        XCTAssertTrue(playback.played.isEmpty)
        XCTAssertTrue(gap.durations.isEmpty)
        XCTAssertNil(player.current)
        XCTAssertFalse(player.isRunning)
    }

    func testTwentyDistinctValidPatternsHaveStableNumbers() throws {
        XCTAssertEqual(HapticAuditionSample.allCases.map(\.id), Array(1...20))
        var exports: Set<Data> = []
        for sample in HapticAuditionSample.allCases {
            let pattern = try sample.makePattern()
            let dictionary = try pattern.exportDictionary()
            let decoded = try CHHapticPattern(dictionary: dictionary)
            XCTAssertEqual(decoded.duration, pattern.duration, accuracy: 0.00001)
            XCTAssertGreaterThan(pattern.duration, 0)
            XCTAssertLessThan(pattern.duration, 1)
            exports.insert(try JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys]))
        }
        XCTAssertEqual(exports.count, 20)
    }

    func testAllTwentyPlayInOrderWithOneAndAQuarterSecondsOnlyAfterEachCompletion() async {
        let playback = Playback(), gap = Gap()
        let player = HapticAuditionPlayer(playback: playback, isEnabled: true, pause: { try await gap.wait($0) })
        player.setActive(true)
        await settle()
        for (index, sample) in HapticAuditionSample.allCases.enumerated() {
            XCTAssertEqual(playback.played.count, index + 1)
            XCTAssertEqual(playback.played.last, sample)
            XCTAssertEqual(player.current, sample)
            XCTAssertEqual(gap.durations.count, index, "No gap until playback completes")
            playback.finish()
            await settle()
            if index < 19 {
                XCTAssertEqual(gap.durations.last, .milliseconds(1250))
                XCTAssertEqual(playback.played.count, index + 1, "Next sample must wait for the gap")
                gap.finish()
                await settle()
            }
        }
        XCTAssertEqual(gap.durations.count, 19)
        XCTAssertFalse(player.isRunning)
        XCTAssertEqual(player.current?.id, 20)
    }

    func testLeavingScreenStopsAndReturningDoesNotAutoplayAgain() async {
        let playback = Playback()
        let player = HapticAuditionPlayer(playback: playback, isEnabled: true, pause: { _ in })
        player.setActive(true)
        await settle()
        player.setActive(false)
        await settle()
        XCTAssertNil(playback.pending)
        XCTAssertFalse(player.isRunning)
        XCTAssertEqual(playback.played.count, 1)
        player.setActive(true)
        await settle()
        XCTAssertEqual(playback.played.count, 1)
        player.replay(.rattle)
        await settle()
        XCTAssertEqual(playback.played.last, .rattle)
        playback.finish()
        await settle()
        XCTAssertEqual(player.status, "Finished #17")
    }

    func testStopDuringGapCannotLeakIntoReplay() async {
        let playback = Playback(), gap = Gap()
        let player = HapticAuditionPlayer(playback: playback, isEnabled: true, pause: { try await gap.wait($0) })
        player.setActive(true)
        await settle()
        playback.finish()
        await settle()
        player.stop()
        player.replay(.impactAndTail)
        await settle()
        gap.finish() // Late completion from the cancelled run.
        await settle()
        XCTAssertEqual(playback.played.map(\.id), [1, 20])
        XCTAssertTrue(player.isRunning)
        XCTAssertEqual(player.current, .impactAndTail)
        playback.finish()
        await settle()
        XCTAssertFalse(player.isRunning)
    }

    func testHardwareFailureEndsAuditionWithoutMislabelledFallback() async {
        let playback = Playback(), gap = Gap()
        let player = HapticAuditionPlayer(playback: playback, isEnabled: true, pause: { try await gap.wait($0) })
        player.setActive(true)
        await settle()
        playback.fail()
        await settle()
        XCTAssertEqual(playback.played.count, 1)
        XCTAssertTrue(gap.durations.isEmpty)
        XCTAssertFalse(player.isRunning)
        XCTAssertEqual(player.status, "Playback failed")
    }
}
