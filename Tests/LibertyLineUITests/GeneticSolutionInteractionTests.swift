import XCTest

@MainActor final class GeneticSolutionInteractionTests: XCTestCase {
    func testEachPreviewMovieOpensOnFirstTapAfterColdLaunch() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeRight
        let app = XCUIApplication()
        app.launchArguments = ["--preview-level", "15"]
        defer { app.terminate() }
        var candidates: Set<String> = []
        for index in 1...3 {
            app.launch()
            let watch = app.buttons["preview-ga-solution-\(index)"]
            XCTAssertTrue(watch.waitForExistence(timeout: 20))
            watch.tap()
            let field = app.otherElements["ga-battlefield"]
            XCTAssertTrue(field.waitForExistence(timeout: 20), app.debugDescription)
            let value = try XCTUnwrap(field.value as? String)
            XCTAssertTrue(candidates.insert(candidateName(in: value)).inserted,
                          "Each movie must present its own selected candidate: \(value)")
            XCTAssertTrue(app.buttons["ga-exit"].isHittable)
            let advances = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", value), object: field)
            XCTAssertEqual(XCTWaiter.wait(for: [advances], timeout: 5), .completed)
            capture("solution-\(index)-first-tap")
            app.buttons["ga-exit"].tap()
            XCTAssertTrue(watch.waitForExistence(timeout: 5))
            watch.tap()
            XCTAssertTrue(field.waitForExistence(timeout: 20), app.debugDescription)
            XCTAssertEqual(candidateName(in: try XCTUnwrap(field.value as? String)),
                           candidateName(in: value))
            app.terminate()
        }
    }

    func testPreviewPlaysBestWinnerWithPauseAndSpeedControls() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeRight
        let app = XCUIApplication()
        app.launchArguments = ["--preview-level", "15"]
        app.launch()
        defer { app.terminate() }
        let watch = app.buttons["preview-ga-solution-1"]
        XCTAssertTrue(watch.waitForExistence(timeout: 20))
        let choices = (1...3).map { app.buttons["preview-ga-solution-\($0)"] }
        for (index, choice) in choices.enumerated() {
            XCTAssertTrue(choice.isHittable)
            XCTAssertGreaterThanOrEqual(choice.frame.width, 48 - 1e-6)
            for other in choices.dropFirst(index + 1) {
                XCTAssertFalse(choice.frame.intersects(other.frame))
            }
            XCTAssertFalse(choice.frame.intersects(app.buttons["Done"].frame))
        }
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
            XCTAssertGreaterThanOrEqual(control.frame.width, 48 - 1e-6)
            for id in ["hero-hud-0", "hero-hud-1", "call-reinforcements"] {
                XCTAssertFalse(control.frame.intersects(app.buttons[id].frame), "Playback control covers \(id)")
            }
        }
        pause.tap()
        XCTAssertEqual(pause.value as? String, "Paused")
        let tick = try XCTUnwrap(field.value as? String)
        var candidateNames: Set<String> = [candidateName(in: tick)]
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
        for index in 2...3 {
            app.buttons["preview-ga-solution-\(index)"].tap()
            XCTAssertTrue(field.waitForExistence(timeout: 20), app.debugDescription)
            let value = try XCTUnwrap(field.value as? String)
            XCTAssertTrue(candidateNames.insert(candidateName(in: value)).inserted,
                          "Each preview button must play a different candidate: \(value)")
            for _ in 0..<3 { faster.tap() }
            XCTAssertTrue(app.images["ga-victory"].waitForExistence(timeout: 240), app.debugDescription)
            capture("solution-\(index)-verified-victory")
            exit.tap()
            XCTAssertTrue(watch.waitForExistence(timeout: 5))
        }
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
        for index in 1...3 { XCTAssertFalse(app.buttons["preview-ga-solution-\(index)"].exists) }
        app.terminate()
        app.launchArguments = ["--preview-level", "15"]
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["preview-ga-solution-1"].waitForExistence(timeout: 20))
    }

    private func candidateName(in value: String) -> String {
        // SwiftUI localizes numbers, so a candidate ID can contain a comma.
        let fields = value.components(separatedBy: ", tick ")
        XCTAssertEqual(fields.count, 2, value)
        return fields[0]
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
