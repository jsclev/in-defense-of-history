import XCTest

/// Actual iPhone taps against the production level and HUD. Calling an engine
/// handler directly cannot detect an overlay that intercepts the player's tap.
@MainActor
final class ReinforcementInteractionTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeRight
        app = XCUIApplication()
        app.launchArguments = ["--play-level", "15"]
        app.launch()
        XCTAssertTrue(app.buttons["call-reinforcements"].waitForExistence(timeout: 20))
    }

    override func tearDownWithError() throws {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.terminate()
    }

    private func expectValue(_ value: String, on element: XCUIElement,
                             file: StaticString = #filePath, line: UInt = #line) {
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 3), .completed, file: file, line: line)
    }

    private func tapReinforcements() {
        // A coordinate tap goes through normal hit testing, even if an overlay
        // makes the underlying accessibility element report not hittable.
        app.buttons["call-reinforcements"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func expectCountdown(on button: XCUIElement, timeout: TimeInterval = 3,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let countdown = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value MATCHES %@", "[0-9]+ seconds remaining"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [countdown], timeout: timeout), .completed, file: file, line: line)
    }

    private func expectCountdownSeconds(_ seconds: ClosedRange<Int>, on button: XCUIElement,
                                        timeout: TimeInterval,
                                        file: StaticString = #filePath, line: UInt = #line) {
        let values = seconds.map { "\($0) seconds remaining" }
        let countdown = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value IN %@", values), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [countdown], timeout: timeout), .completed, file: file, line: line)
    }

    private func remainingSeconds(on button: XCUIElement) throws -> Int {
        let value = try XCTUnwrap(button.value as? String)
        return try XCTUnwrap(value.split(separator: " ").first.flatMap { Int($0) })
    }

    private func attachScreenshot(named name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @discardableResult private func deployReinforcements() -> XCUIElement {
        let button = app.buttons["call-reinforcements"]
        expectValue("Ready", on: button)
        tapReinforcements()
        expectValue("Selected", on: button)
        // Visible center of Charleston's lower-left road bend, clear of the
        // hero HUD and tower slots. Deploy through the actual map gesture.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.69)).tap()
        expectCountdown(on: button)
        return button
    }

    func testReadyButtonSelectsAndCancelsOnConsecutiveTaps() {
        let button = app.buttons["call-reinforcements"]
        expectValue("Ready", on: button)
        tapReinforcements()
        expectValue("Selected", on: button)
        tapReinforcements()
        expectValue("Ready", on: button)
    }

    func testFirstTapSelectsAcrossEntireVisibleButton() {
        let button = app.buttons["call-reinforcements"]
        for point in [CGVector(dx: 0.1, dy: 0.1), CGVector(dx: 0.9, dy: 0.1),
                      CGVector(dx: 0.1, dy: 0.9), CGVector(dx: 0.9, dy: 0.9)] {
            expectValue("Ready", on: button)
            button.coordinate(withNormalizedOffset: point).tap()
            expectValue("Selected", on: button)
            button.coordinate(withNormalizedOffset: point).tap()
            expectValue("Ready", on: button)
        }
    }

    func testModestFingerDriftWithinButtonSelectsAndCancelsOnce() {
        let button = app.buttons["call-reinforcements"]
        let start = button.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.45))
        let end = button.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.55))
        expectValue("Ready", on: button)
        start.press(forDuration: 0.1, thenDragTo: end)
        expectValue("Selected", on: button)
        end.press(forDuration: 0.1, thenDragTo: start)
        expectValue("Ready", on: button)
    }

    func testFirstTapSelectsAgainAfterDeploymentCooldown() {
        let button = deployReinforcements()
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Ready"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 30), .completed)
        tapReinforcements()
        expectValue("Selected", on: button)
    }

    func testCountdownProgressesAndCooldownTapsDoNotSelectOrResetIt() throws {
        let button = deployReinforcements()
        let initial = try remainingSeconds(on: button)
        XCTAssertGreaterThan(initial, 3)
        attachScreenshot(named: "Reinforcement cooldown after deployment")
        tapReinforcements()
        expectCountdown(on: button)
        tapReinforcements()
        expectCountdown(on: button)
        expectCountdownSeconds(1...(initial - 1), on: button, timeout: 3)
        let halfway = initial / 2
        expectCountdownSeconds(halfway...halfway, on: button, timeout: TimeInterval(initial))
        attachScreenshot(named: "Reinforcement cooldown at half duration")
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Ready"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: TimeInterval(initial + 2)), .completed)
        // Earlier rejected taps must not queue a deployment selection.
        expectValue("Ready", on: button)
        attachScreenshot(named: "Reinforcements ready again")
        tapReinforcements()
        expectValue("Selected", on: button)
    }

    func testPressBeginningBeforeCooldownEndsSelectsOnceWhenReleasedAfterReady() {
        let button = deployReinforcements()
        expectCountdownSeconds(3...3, on: button, timeout: 30)
        // Keep the same finger down across the ready boundary. Eligibility
        // must be checked when the player releases, not latched at touch-down.
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 4)
        expectValue("Selected", on: button)
        tapReinforcements()
        expectValue("Ready", on: button)
    }

    func testCountdownFreezesWhilePausedAndResumesAfterwards() {
        let button = deployReinforcements()
        expectCountdownSeconds(3...4, on: button, timeout: 30)
        app.buttons["pause-level"].tap()
        let resume = app.buttons["pause-resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 3))
        // This exceeds the remaining cooldown. A wall-clock timer would be
        // ready on resume; the game's paused cooldown must still be visible.
        XCTAssertFalse(resume.waitForNonExistence(timeout: 5))
        resume.tap()
        expectCountdown(on: button)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Ready"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 6), .completed)
        tapReinforcements()
        expectValue("Selected", on: button)
    }

    func testFirstTapSelectsReinforcementsWhileTowerBuildMenuIsOpen() {
        let button = app.buttons["call-reinforcements"]
        app.buttons["tower-slot-0"].tap()
        XCTAssertTrue(app.buttons["tower-build-ranged"].waitForExistence(timeout: 3))
        expectValue("Ready", on: button)
        tapReinforcements()
        expectValue("Selected", on: button)
        XCTAssertFalse(app.buttons["tower-build-ranged"].exists)
    }

    func testFirstTapSwitchesFromHeroDestinationToReinforcements() {
        let hero = app.buttons["hero-hud-1"]
        hero.tap()
        expectValue("Selected", on: hero)
        tapReinforcements()
        expectValue("Selected", on: app.buttons["call-reinforcements"])
        expectValue("", on: hero)
    }

    private func buildMeleeTowerAndOpenMenu() {
        app.buttons["tower-slot-0"].tap()
        let build = app.buttons["tower-build-melee"]
        XCTAssertTrue(build.waitForExistence(timeout: 3))
        build.tap()
        build.tap()
        XCTAssertTrue(build.waitForNonExistence(timeout: 3))
        app.buttons["tower-slot-0"].tap()
        XCTAssertTrue(app.buttons["rally-placement"].waitForExistence(timeout: 3))
    }

    func testFirstTapSelectsReinforcementsWhileTowerUpgradeMenuIsOpen() {
        buildMeleeTowerAndOpenMenu()
        tapReinforcements()
        expectValue("Selected", on: app.buttons["call-reinforcements"])
        XCTAssertFalse(app.buttons["rally-placement"].exists)
    }

    func testFirstTapSwitchesFromRallyPlacementToReinforcements() {
        buildMeleeTowerAndOpenMenu()
        app.buttons["rally-placement"].tap()
        XCTAssertTrue(app.buttons["rally-placement"].waitForNonExistence(timeout: 3))
        tapReinforcements()
        expectValue("Selected", on: app.buttons["call-reinforcements"])
        tapReinforcements()
        expectValue("Ready", on: app.buttons["call-reinforcements"])
    }

    func testFirstTapSelectsDuringActiveWaveAfterPauseAndResume() {
        app.buttons["Select wave 1"].firstMatch.tap()
        app.buttons["Confirm call wave 1"].firstMatch.tap()
        app.buttons["pause-level"].tap()
        app.buttons["pause-resume"].tap()
        tapReinforcements()
        expectValue("Selected", on: app.buttons["call-reinforcements"])
        tapReinforcements()
        expectValue("Ready", on: app.buttons["call-reinforcements"])
    }
}
