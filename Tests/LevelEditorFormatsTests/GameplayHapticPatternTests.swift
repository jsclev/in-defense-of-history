import CoreHaptics
import XCTest
@testable import LevelEditorFormats

final class GameplayHapticPatternTests: XCTestCase {
    private func parameter(_ id: CHHapticEvent.ParameterID, in event: CHHapticEvent) throws -> Float {
        try XCTUnwrap(event.eventParameters.first { $0.parameterID == id }).value
    }

    private func exported(_ pattern: CHHapticPattern) throws -> Data {
        try JSONSerialization.data(withJSONObject: pattern.exportDictionary(), options: [.sortedKeys])
    }

    func testBuildRetainsSingleHeavyThudWithFirmerAttack() throws {
        let events = GameplayHapticPattern.build.events
        XCTAssertEqual(events.count, 1)
        XCTAssertTrue(events.allSatisfy { $0.type == .hapticTransient })
        XCTAssertEqual(events.map(\.relativeTime), [0])
        XCTAssertEqual(try events.map { try parameter(.hapticIntensity, in: $0) }, [1])
        XCTAssertEqual(try events.map { try parameter(.hapticSharpness, in: $0) }, [0.35])
        var expected = try XCTUnwrap(JSONSerialization.jsonObject(
            with: exported(HapticAuditionSample.heavyThud.makePattern())) as? [String: Any])
        var entries = try XCTUnwrap(expected["Pattern"] as? [[String: Any]])
        var event = try XCTUnwrap(entries[0]["Event"] as? [String: Any])
        var parameters = try XCTUnwrap(event["EventParameters"] as? [[String: Any]])
        let sharpnessIndex = try XCTUnwrap(parameters.firstIndex { $0["ParameterID"] as? String == "HapticSharpness" })
        parameters[sharpnessIndex]["ParameterValue"] = Float(0.35)
        event["EventParameters"] = parameters
        entries[0]["Event"] = event
        expected["Pattern"] = entries
        XCTAssertEqual(try exported(GameplayHapticPattern.build.makePattern()),
                       try JSONSerialization.data(withJSONObject: expected, options: [.sortedKeys]))
    }

    func testLossUsesDistinctSustainedShapeAndLeavesAGapBetweenRepeatedCues() throws {
        let build = GameplayHapticPattern.build.events
        let loss = GameplayHapticPattern.lifeLoss.events
        XCTAssertEqual(loss.count, 1)
        let rumble = try XCTUnwrap(loss.first)
        XCTAssertEqual(rumble.type, .hapticContinuous)
        XCTAssertEqual(rumble.duration, 0.4, accuracy: 0.00001)
        XCTAssertEqual(try parameter(.hapticIntensity, in: rumble), 0.85)
        XCTAssertEqual(try parameter(.hapticSharpness, in: rumble), 0.08)
        XCTAssertLessThan(GameplayHapticPattern.lifeLoss.duration, EnemyEscapeHapticPolicy.minimumInterval)
        for click in build {
            XCTAssertLessThan(try parameter(.hapticSharpness, in: rumble),
                              try parameter(.hapticSharpness, in: click))
        }
        // Compare the actual audition export, changing only its duration. This
        // catches accidental intensity curves or other changes to the chosen feel.
        var expected = try XCTUnwrap(JSONSerialization.jsonObject(
            with: exported(HapticAuditionSample.longRumble.makePattern())) as? [String: Any])
        var entries = try XCTUnwrap(expected["Pattern"] as? [[String: Any]])
        XCTAssertEqual(entries.count, 1)
        var event = try XCTUnwrap(entries[0]["Event"] as? [String: Any])
        event["EventDuration"] = 0.4
        entries[0]["Event"] = event
        expected["Pattern"] = entries
        XCTAssertEqual(try exported(GameplayHapticPattern.lifeLoss.makePattern()),
                       try JSONSerialization.data(withJSONObject: expected, options: [.sortedKeys]))
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
