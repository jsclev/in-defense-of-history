import XCTest

@MainActor
final class TowerMenuLayeringTests: XCTestCase {
    func testBuildMenuReceivesTapsWhereItOverlapsCallWave() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeRight
        let app = XCUIApplication()
        app.launchArguments = ["--play-level", "15"]
        app.launch()
        defer { app.terminate() }
        let wave = app.buttons["Select wave 1"].firstMatch
        XCTAssertTrue(wave.waitForExistence(timeout: 20))
        let waveFrame = wave.frame
        // Charleston's entrance-side slot has a build choice over the horn.
        let slot = app.buttons["tower-slot-17"]
        slot.tap()
        XCTAssertTrue(app.buttons["tower-build-ranged"].waitForExistence(timeout: 3))
        let choices = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tower-build-")).allElementsBoundByIndex
        let overlapping = choices.compactMap { choice -> (XCUIElement, CGPoint)? in
            let interior = choice.frame.insetBy(dx: 3, dy: 3)
            let point = CGPoint(x: min(max(waveFrame.midX, interior.minX), interior.maxX),
                                y: min(max(waveFrame.midY, interior.minY), interior.maxY))
            // Stay inside the circular horn even at the smallest pulse size.
            guard hypot(point.x - waveFrame.midX, point.y - waveFrame.midY) < waveFrame.width * 0.4 else { return nil }
            return (choice, point)
        }
        let (choice, point) = try XCTUnwrap(overlapping.first, "Expected a build choice overlapping the call-wave horn")
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "tower-menu-above-call-wave"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let tap = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: point.x - app.frame.minX, dy: point.y - app.frame.minY))
        tap.tap()
        XCTAssertTrue(choice.exists)
        XCTAssertFalse(app.buttons["Confirm call wave 1"].exists)
        tap.tap()
        XCTAssertTrue(choice.waitForNonExistence(timeout: 3))
        XCTAssertEqual(slot.label, "Select tower")
        XCTAssertTrue(wave.exists)
        XCTAssertFalse(app.buttons["Confirm call wave 1"].exists)
    }
}
