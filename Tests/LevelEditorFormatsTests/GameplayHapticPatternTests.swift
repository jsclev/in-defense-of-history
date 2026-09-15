import CoreHaptics
import XCTest
@testable import LevelEditorFormats

final class GameplayHapticPatternTests: XCTestCase {
    private func parameter(_ id: CHHapticEvent.ParameterID, in event: CHHapticEvent) throws -> Float {
        try XCTUnwrap(event.eventParameters.first { $0.parameterID == id }).value
    }

    func testEscapeRetainsLowRumbleAndLeavesAGapBetweenRepeatedCues() throws {
        let loss = GameplayHapticPattern.lifeLoss.events
        XCTAssertEqual(loss.count, 1)
        let rumble = try XCTUnwrap(loss.first)
        XCTAssertEqual(rumble.type, .hapticContinuous)
        XCTAssertEqual(rumble.duration, 0.4, accuracy: 0.00001)
        XCTAssertEqual(try parameter(.hapticIntensity, in: rumble), 0.85)
        XCTAssertEqual(try parameter(.hapticSharpness, in: rumble), 0.08)
        XCTAssertLessThan(GameplayHapticPattern.lifeLoss.duration, EnemyEscapeHapticPolicy.minimumInterval)
        let data = try JSONSerialization.data(withJSONObject: GameplayHapticPattern.lifeLoss.makePattern().exportDictionary())
        let dictionary = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let entries = try XCTUnwrap(dictionary["Pattern"] as? [[String: Any]])
        XCTAssertEqual(entries.count, 1, "The escape rumble must not gain extra events or intensity curves.")
        XCTAssertNotNil(entries.first?["Event"])
    }

    func testDefeatRetainsItsSeparateTwoRumblesWithSilenceBetweenThem() {
        let events = GameplayHapticPattern.defeat.events
        XCTAssertEqual(events.count, 2)
        XCTAssertTrue(events.allSatisfy { $0.type == .hapticContinuous })
        XCTAssertGreaterThan(events[1].relativeTime - (events[0].relativeTime + events[0].duration), 0.1)
        XCTAssertGreaterThan(GameplayHapticPattern.defeat.duration, GameplayHapticPattern.lifeLoss.duration)
        XCTAssertLessThan(GameplayHapticPattern.defeat.duration, 1)
    }

    func testActualCoreHapticsPatternsValidateAndRoundTripWithoutAudio() throws {
        for cue in GameplayHapticPattern.allCases {
            let pattern = try cue.makePattern()
            let exported = try pattern.exportDictionary()
            let decoded = try CHHapticPattern(dictionary: exported)
            XCTAssertEqual(decoded.duration, cue.duration, accuracy: 0.00001)
            for event in cue.events {
                XCTAssertTrue([.hapticContinuous, .hapticTransient].contains(event.type))
                for id in [CHHapticEvent.ParameterID.hapticIntensity, .hapticSharpness] {
                    XCTAssertTrue((0...1).contains(try parameter(id, in: event)))
                }
            }
        }
    }
}
