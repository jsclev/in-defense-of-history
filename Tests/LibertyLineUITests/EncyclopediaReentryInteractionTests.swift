import XCTest

@MainActor
final class EncyclopediaReentryInteractionTests: XCTestCase {
    func testCampaignButtonOpensPickerAfterReviewLaunch() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        defer { app.terminate() }

        for category in [Category.tower, .enemy] {
            app.launchArguments = ["--\(category.rawValue)-encyclopedia-review", "--enemy-review-key=loyalist_militia"]
            app.launch()
            // A launch shortcut applies only to that first visit. It must not be
            // reapplied by appearance callbacks after an ordinary campaign tap.
            XCTAssertTrue(app.buttons[category.firstEntryID].waitForExistence(timeout: 20))
            closeEncyclopedia(in: app)
            for _ in 0..<2 {
                openPicker(in: app)
                app.buttons[category.buttonID].tap()
                assertFreshRoster(category, in: app)
                closeEncyclopedia(in: app)
            }
            openPicker(in: app)
            app.terminate()
        }
    }

    func testCampaignButtonStartsFreshAfterLeavingPickerAndDirtyRosters() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }

        // Keep the same process alive: relaunching would hide retained view state.
        for _ in 0..<2 {
            openPicker(in: app)
            closeEncyclopedia(in: app)
        }

        for category in [Category.tower, .enemy] {
            openPicker(in: app)
            app.buttons[category.buttonID].tap()
            assertFreshRoster(category, in: app)
            let first = app.buttons[category.firstEntryID]
            let initialRowY = first.frame.minY
            let initialTitle = app.staticTexts[category.titleID].label
            let playback = app.buttons["enemy-demonstration-playback"]
            let initialPlaybackLabel = category == .enemy ? playback.label : nil
            let prose = app.staticTexts["\(category.rawValue)-history-description"]

            for cycle in 0..<2 {
                let laterEntry = revealEntry(category.laterEntryID, category: category, in: app)
                // First leave the default entry with its roster scrolled; then
                // leave a different entry. Neither visit's state should persist.
                if cycle == 1 {
                    laterEntry.tap()
                    XCTAssertTrue(laterEntry.isSelected)
                    XCTAssertTrue(app.buttons["\(category.rawValue)-encyclopedia-page-demo"].isSelected)
                }
                app.buttons["\(category.rawValue)-encyclopedia-page-history"].tap()
                XCTAssertTrue(prose.waitForExistence(timeout: 3))
                XCTAssertTrue(app.buttons["\(category.rawValue)-encyclopedia-page-history"].isSelected)

                if category == .enemy && cycle == 1 {
                    app.buttons["enemy-encyclopedia-page-demo"].tap()
                    XCTAssertTrue(playback.isHittable)
                    XCTAssertEqual(playback.label, initialPlaybackLabel)
                    playback.tap()
                    XCTAssertNotEqual(playback.label, initialPlaybackLabel,
                                      "Leave playback changed, normally paused, before exiting")
                }
                closeEncyclopedia(in: app)

                openPicker(in: app)
                app.buttons[category.buttonID].tap()
                assertFreshRoster(category, in: app)
                XCTAssertEqual(first.frame.minY, initialRowY, accuracy: 1,
                               "Reentry must reset the roster's scroll position")
                XCTAssertEqual(app.staticTexts[category.titleID].label, initialTitle)
                if let initialPlaybackLabel {
                    XCTAssertEqual(playback.label, initialPlaybackLabel,
                                   "Reentry must initialize playback again")
                    playback.tap()
                    XCTAssertNotEqual(playback.label, initialPlaybackLabel)
                    playback.tap()
                    XCTAssertEqual(playback.label, initialPlaybackLabel)
                }

                // Page controls must remain usable after each reentry.
                let stats = app.buttons["\(category.rawValue)-encyclopedia-page-details"]
                stats.tap()
                XCTAssertTrue(stats.isSelected)
                XCTAssertTrue(app.scrollViews["\(category.rawValue)-encyclopedia-detail"].isHittable)
                let historyButton = app.buttons["\(category.rawValue)-encyclopedia-page-history"]
                historyButton.tap()
                XCTAssertTrue(historyButton.isSelected)
                XCTAssertTrue(prose.isHittable)
                app.buttons["\(category.rawValue)-encyclopedia-page-demo"].tap()
                XCTAssertTrue(app.otherElements["\(category.rawValue)-demonstration-animation"].isHittable)
            }
            closeEncyclopedia(in: app)
        }
    }

    private enum Category: String {
        case tower, enemy

        var buttonID: String { self == .tower ? "encyclopedia-towers" : "encyclopedia-enemies" }
        var firstEntryID: String { self == .tower ? "tower-entry-ranged-1-1" : "enemy-entry-loyalist_militia" }
        var laterEntryID: String { self == .tower ? "tower-entry-special-4-1" : "enemy-entry-foot_guards" }
        var rosterID: String { self == .tower ? "tower-encyclopedia-grid" : "enemy-encyclopedia-list" }
        var titleID: String { self == .tower ? "tower-selection-name" : "enemy-detail-name" }
    }

    private func openPicker(in app: XCUIApplication) {
        let encyclopedia = app.buttons["Encyclopedia"]
        XCTAssertTrue(encyclopedia.waitForExistence(timeout: 20))
        XCTAssertTrue(encyclopedia.isHittable)
        encyclopedia.tap()
        XCTAssertTrue(app.buttons["encyclopedia-towers"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["encyclopedia-towers"].isHittable)
        XCTAssertTrue(app.buttons["encyclopedia-enemies"].isHittable)
        XCTAssertFalse(app.scrollViews["tower-encyclopedia-grid"].exists)
        XCTAssertFalse(app.scrollViews["enemy-encyclopedia-list"].exists)
    }

    private func closeEncyclopedia(in app: XCUIApplication) {
        let done = app.buttons["Done"]
        XCTAssertTrue(done.isHittable)
        done.tap()
        XCTAssertTrue(app.buttons["Encyclopedia"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Encyclopedia"].isHittable)
    }

    private func assertFreshRoster(_ category: Category, in app: XCUIApplication) {
        let roster = app.scrollViews[category.rosterID]
        XCTAssertTrue(roster.waitForExistence(timeout: 5))
        let first = app.buttons[category.firstEntryID]
        XCTAssertTrue(first.isSelected, "Reentry must select the first authored entry")
        XCTAssertTrue(first.isHittable)
        XCTAssertTrue(roster.frame.insetBy(dx: -1, dy: -1).contains(first.frame))
        XCTAssertTrue(app.buttons["\(category.rawValue)-encyclopedia-page-demo"].isSelected)
        XCTAssertFalse(app.buttons["\(category.rawValue)-encyclopedia-page-details"].isSelected)
        XCTAssertFalse(app.buttons["\(category.rawValue)-encyclopedia-page-history"].isSelected)
        XCTAssertTrue(app.otherElements["\(category.rawValue)-demonstration-animation"].waitForExistence(timeout: 5))
    }

    private func revealEntry(_ id: String, category: Category, in app: XCUIApplication) -> XCUIElement {
        let roster = app.scrollViews[category.rosterID]
        let entry = app.buttons[id]
        for _ in 0..<24 {
            if entry.isHittable && roster.frame.insetBy(dx: -1, dy: -1).contains(entry.frame) {
                return entry
            }
            if entry.exists && entry.frame.minY < roster.frame.minY { roster.swipeDown() }
            else { roster.swipeUp() }
        }
        XCTFail("Unable to scroll to \(id)")
        return entry
    }
}
