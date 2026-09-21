import XCTest

/// Actual iPhone taps against the production level and HUD. Calling an engine
/// handler directly cannot detect an overlay that intercepts the player's tap.
@MainActor
final class ReinforcementInteractionTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--play-level", "15"]
        app.launch()
        XCTAssertTrue(app.buttons["call-reinforcements"].waitForExistence(timeout: 20))
    }

    override func tearDownWithError() throws {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
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

    func testReadyButtonSelectsAndCancelsOnConsecutiveTaps() {
        let button = app.buttons["call-reinforcements"]
        expectValue("Ready", on: button)
        tapReinforcements()
        expectValue("Selected", on: button)
        tapReinforcements()
        expectValue("Ready", on: button)
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
