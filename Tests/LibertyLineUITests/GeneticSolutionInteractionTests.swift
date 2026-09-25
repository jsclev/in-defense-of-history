import XCTest

@MainActor final class GeneticSolutionInteractionTests: XCTestCase {
    func testPreviewPlaysBestWinnerWithPauseAndSpeedControls() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeRight
        let app = XCUIApplication()
        app.launchArguments = ["--preview-level", "15"]
        app.launch()
        defer { app.terminate() }
        let watch = app.buttons["preview-ga-solution"]
        XCTAssertTrue(watch.waitForExistence(timeout: 20))
        capture("level15-preview")
        watch.tap()
        let field = app.otherElements["ga-battlefield"]
        XCTAssertTrue(field.waitForExistence(timeout: 20), app.debugDescription)
        let pause = app.buttons["ga-pause"]
        let faster = app.buttons["ga-faster"]
        let slower = app.buttons["ga-slower"]
        let exit = app.buttons["ga-exit"]
        for id in ["pause-level", "speed-level", "inventory-level"] {
            XCTAssertFalse(app.buttons[id].exists, "Solution playback must not display duplicate inactive controls")
        }
        for control in [pause, faster, slower, exit] {
            XCTAssertTrue(control.isHittable)
            XCTAssertGreaterThanOrEqual(control.frame.width, 48)
            for id in ["hero-hud-0", "hero-hud-1", "call-reinforcements"] {
                XCTAssertFalse(control.frame.intersects(app.buttons[id].frame), "Playback control covers \(id)")
            }
        }
        pause.tap()
        XCTAssertEqual(pause.value as? String, "Paused")
        let tick = try XCTUnwrap(field.value as? String)
        slower.tap()
        XCTAssertEqual(app.staticTexts["ga-speed"].value as? String, "0.5")
        Thread.sleep(forTimeInterval: 1)
        XCTAssertEqual(field.value as? String, tick)
        for _ in 0..<4 { faster.tap() }
        XCTAssertEqual(app.staticTexts["ga-speed"].value as? String, "8.0")
        XCTAssertFalse(faster.isEnabled)
        capture("solution-paused-speed-controls")
        pause.tap()
        let advanced = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", tick), object: field)
        XCTAssertEqual(XCTWaiter.wait(for: [advanced], timeout: 5), .completed)
        capture("solution-live-run")
        XCTAssertTrue(app.images["ga-victory"].waitForExistence(timeout: 240), app.debugDescription)
        capture("solution-verified-victory")
        exit.tap()
        XCTAssertTrue(watch.waitForExistence(timeout: 5))
    }

    func testSettingsCanHidePreviewButtonAndRelaunchRestoresAuthoredDefault() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeRight
        let app = XCUIApplication()
        app.launch()
        app.buttons["Settings"].tap()
        let toggle = app.switches["settings-ga-solutions"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "1")
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "0")
        capture("settings-solution-button-off")
        app.buttons["Done"].tap()
        app.buttons["Level 15, Charleston"].tap()
        XCTAssertTrue(app.staticTexts["Charleston"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["preview-ga-solution"].exists)
        app.terminate()
        app.launchArguments = ["--preview-level", "15"]
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["preview-ga-solution"].waitForExistence(timeout: 20))
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
