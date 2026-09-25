import XCTest

@MainActor
final class DefeatReplayInteractionTests: XCTestCase {
    func testDefeatReviewPlaysPausesResumesAndReturnsToDialog() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeRight
        let app = XCUIApplication()
        app.launchArguments = ["--play-level", "15"]
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["pause-level"].waitForExistence(timeout: 20))
        // Hold each selected state long enough to inspect it in the ordinary
        // 1x recording. Both highlights must come from saved player gestures.
        app.buttons["Select wave 1"].firstMatch.tap()
        app.buttons["hero-hud-0"].tap()
        Thread.sleep(forTimeInterval: 12)
        app.buttons["call-reinforcements"].tap()
        Thread.sleep(forTimeInterval: 12)
        // Leave destination-placement mode before confirming the wave.
        app.buttons["call-reinforcements"].tap()
        app.buttons["Confirm call wave 1"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Confirm call wave 1"].firstMatch.waitForNonExistence(timeout: 3))
        // Lose through ordinary gameplay with no defenses. Speed changes use
        // the same HUD the player uses; the saved run still reviews at 1x.
        for _ in 0..<5 { app.buttons["Speed up"].tap() }
        let review = app.buttons["defeat-review"]
        XCTAssertTrue(app.staticTexts["DEFEAT"].waitForExistence(timeout: 120))
        XCTAssertTrue(review.exists, app.debugDescription)
        let home = app.buttons["defeat-home"]
        let restart = app.buttons["defeat-restart"]
        XCTAssertTrue(home.isHittable)
        XCTAssertTrue(restart.isHittable)
        XCTAssertFalse(home.frame.intersects(restart.frame))
        XCTAssertFalse(restart.frame.intersects(review.frame))
        for button in [home, restart, review] {
            let icon = XCTAttachment(screenshot: button.screenshot())
            icon.name = button.identifier
            icon.lifetime = .keepAlways
            add(icon)
        }
        capture(app, name: "defeat-dialog")
        review.tap()
        let pause = app.buttons["replay-pause"]
        let exit = app.buttons["replay-exit"]
        let battlefield = app.otherElements["replay-battlefield"]
        let recordedLevel = app.otherElements["Recorded level"]
        XCTAssertTrue(battlefield.waitForExistence(timeout: 10))
        XCTAssertTrue(recordedLevel.exists)
        XCTAssertTrue(pause.isHittable)
        XCTAssertTrue(exit.isHittable)
        XCTAssertGreaterThan(pause.frame.minY, app.frame.height * 0.65)
        XCTAssertFalse(pause.frame.intersects(exit.frame))
        pause.tap()
        XCTAssertEqual(pause.value as? String, "Paused")
        let pausedTick = try XCTUnwrap(battlefield.value as? String)
        let hudIDs = ["hero-hud-0", "hero-hud-1", "call-reinforcements", "speed-level", "pause-level", "inventory-level"]
        for id in hudIDs {
            let control = recordedLevel.buttons[id]
            XCTAssertEqual(recordedLevel.buttons.matching(identifier: id).count, 1)
            XCTAssertTrue(control.exists, "Missing recorded HUD control \(id)")
            XCTAssertFalse(control.isEnabled, "Recorded HUD must be read-only: \(id)")
            XCTAssertFalse(control.frame.intersects(pause.frame))
            XCTAssertFalse(control.frame.intersects(exit.frame))
            let value = control.value as? String
            control.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertEqual(control.value as? String, value)
            XCTAssertEqual(battlefield.value as? String, pausedTick)
        }
        let wave = recordedLevel.buttons.matching(NSPredicate(format: "label CONTAINS 'wave 1'")).firstMatch
        XCTAssertTrue(wave.exists)
        XCTAssertFalse(wave.isEnabled)
        let waveLabel = wave.label
        wave.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertEqual(wave.label, waveLabel)
        XCTAssertEqual(battlefield.value as? String, pausedTick)
        XCTAssertFalse(app.buttons["pause-resume"].exists)
        Thread.sleep(forTimeInterval: 1)
        XCTAssertEqual(battlefield.value as? String, pausedTick)
        capture(app, name: "replay-paused-bottom-controls")
        pause.tap()
        let advanced = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", pausedTick), object: battlefield)
        XCTAssertEqual(XCTWaiter.wait(for: [advanced], timeout: 5), .completed)
        let hero = recordedLevel.buttons["hero-hud-0"]
        let heroSelected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'Selected'"), object: hero)
        XCTAssertEqual(XCTWaiter.wait(for: [heroSelected], timeout: 8), .completed)
        pause.tap()
        XCTAssertEqual(hero.value as? String, "Selected")
        XCTAssertTrue(recordedLevel.buttons["Confirm call wave 1"].firstMatch.exists)
        capture(app, name: "replay-recorded-hero-and-call-wave-highlights")
        pause.tap()
        let reinforcements = recordedLevel.buttons["call-reinforcements"]
        let reinforcementSelected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'Selected'"), object: reinforcements)
        XCTAssertEqual(XCTWaiter.wait(for: [reinforcementSelected], timeout: 20), .completed)
        pause.tap()
        XCTAssertEqual(reinforcements.value as? String, "Selected")
        XCTAssertFalse(reinforcements.isEnabled)
        capture(app, name: "replay-recorded-reinforcement-highlight")
        exit.tap()
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        XCTAssertTrue(review.isHittable)
        // Returning from the full-screen cover restores the modal and can open
        // a fresh playback of the same database run.
        review.tap()
        XCTAssertTrue(battlefield.waitForExistence(timeout: 5))
        exit.tap()
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        home.tap()
        XCTAssertTrue(app.buttons["Encyclopedia"].waitForExistence(timeout: 5))
    }

    func testDefeatRestartCreatesFreshPlayableAttempt() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeRight
        let app = XCUIApplication()
        app.launchArguments = ["--play-level", "15"]
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["pause-level"].waitForExistence(timeout: 20))
        for _ in 0..<5 { app.buttons["Speed up"].tap() }
        app.buttons["Select wave 1"].firstMatch.tap()
        app.buttons["Confirm call wave 1"].firstMatch.tap()
        let restart = app.buttons["defeat-restart"]
        XCTAssertTrue(app.staticTexts["DEFEAT"].waitForExistence(timeout: 120))
        XCTAssertTrue(restart.exists, app.debugDescription)
        restart.tap()
        XCTAssertTrue(restart.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["pause-level"].isHittable)
        XCTAssertTrue(app.buttons["Select wave 1"].firstMatch.isHittable)
        XCTAssertEqual(app.buttons["call-reinforcements"].value as? String, "Ready")
        XCTAssertFalse(app.otherElements["replay-battlefield"].exists)
        // A fresh attempt accepts real player input rather than retaining the
        // defeated runner or opening the recording.
        app.buttons["call-reinforcements"].tap()
        XCTAssertEqual(app.buttons["call-reinforcements"].value as? String, "Selected")
        capture(app, name: "restarted-playable-level")
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
}
