import XCTest

@MainActor
final class EnemyEncyclopediaInteractionTests: XCTestCase {
    func testBossAndReserveCallerDemonstrationsOnDevice() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["Encyclopedia"].waitForExistence(timeout: 20))
        app.buttons["Encyclopedia"].tap()
        app.buttons["encyclopedia-enemies"].tap()
        let roster = app.scrollViews["enemy-encyclopedia-list"]
        for key in ["mounted_officer", "howe_assault", "hill_rearguard", "clinton_siege"] {
            let row = app.buttons["enemy-entry-\(key)"]
            for _ in 0..<10 {
                if row.isHittable { break }
                roster.swipeUp()
            }
            XCTAssertTrue(row.isHittable, key)
            row.tap()
            XCTAssertEqual(app.staticTexts["enemy-detail-name"].label, row.label)
            XCTAssertTrue(app.otherElements["enemy-demonstration-animation"].waitForExistence(timeout: 10))
            let elapsed = expectation(description: "Observe live \(key) demonstration")
            DispatchQueue.main.asyncAfter(deadline: .now() + 7) { elapsed.fulfill() }
            wait(for: [elapsed], timeout: 9)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = key + "-native-demonstration"
            attachment.lifetime = .keepAlways
            add(attachment)
            let playback = app.buttons["enemy-demonstration-playback"]
            playback.tap()
            XCTAssertEqual(playback.label, "Play demonstration")
            app.buttons["enemy-encyclopedia-page-details"].tap()
            XCTAssertFalse(app.staticTexts["enemy-detail-strategy"].label.isEmpty)
            let fullName = app.staticTexts["enemy-detail-long-name"]
            var displayedFullName: String?
            if key != "mounted_officer" {
                XCTAssertTrue(fullName.exists)
                XCTAssertFalse(fullName.label.isEmpty)
                XCTAssertNotEqual(fullName.label, row.label)
                displayedFullName = fullName.label
                XCTAssertEqual(app.staticTexts["enemy-detail-name"].label, row.label)
            }
            app.buttons["enemy-encyclopedia-page-history"].tap()
            XCTAssertFalse(app.staticTexts["enemy-history-description"].label.isEmpty)
            if let displayedFullName {
                XCTAssertEqual(app.staticTexts["enemy-history-long-name"].label, displayedFullName)
                XCTAssertEqual(app.staticTexts["enemy-detail-name"].label, row.label)
            }
            app.buttons["enemy-encyclopedia-page-demo"].tap()
        }
    }

    func testRangerCoverDemonstrationOnDevice() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["Encyclopedia"].waitForExistence(timeout: 20))
        app.buttons["Encyclopedia"].tap()
        app.buttons["encyclopedia-enemies"].tap()
        let roster = app.scrollViews["enemy-encyclopedia-list"]
        let ranger = app.buttons["enemy-entry-queens_ranger"]
        for _ in 0..<8 {
            if ranger.isHittable { break }
            roster.swipeUp()
        }
        XCTAssertTrue(ranger.isHittable)
        ranger.tap()
        XCTAssertEqual(app.staticTexts["enemy-detail-name"].label, ranger.label)
        XCTAssertTrue(app.otherElements["enemy-demonstration-animation"].waitForExistence(timeout: 5))
        let playback = app.buttons["enemy-demonstration-playback"]
        playback.tap()
        XCTAssertEqual(playback.label, "Play demonstration")
        playback.tap()
        app.buttons["enemy-encyclopedia-page-details"].tap()
        XCTAssertFalse(app.staticTexts["enemy-detail-strategy"].label.isEmpty)
    }

    func testSelectingEnemiesPreservesRosterScrollPosition() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["Encyclopedia"].waitForExistence(timeout: 20))
        app.buttons["Encyclopedia"].tap()
        app.buttons["encyclopedia-enemies"].tap()
        let roster = app.scrollViews["enemy-encyclopedia-list"]
        XCTAssertTrue(roster.waitForExistence(timeout: 5))

        for scrollToBottom in [false, true] {
            if scrollToBottom {
                let last = app.buttons["enemy-entry-foot_guards"]
                for _ in 0..<8 {
                    if roster.frame.contains(last.frame) && last.isHittable { break }
                    roster.swipeUp()
                }
                XCTAssertTrue(roster.frame.contains(last.frame))
            }
            let keys = scrollToBottom ? ["mounted_officer", "foot_guards"]
                : ["loyalist_militia", "regimental_drummer"]
            for key in keys {
                let row = app.buttons["enemy-entry-\(key)"]
                XCTAssertTrue(row.isHittable)
                let before = row.frame
                row.tap()
                XCTAssertTrue(row.isSelected)
                XCTAssertEqual(app.staticTexts["enemy-detail-name"].label, row.label)
                XCTAssertEqual(row.frame.minY, before.minY, accuracy: 1,
                               "Selecting an enemy must preserve the player's list position")
            }
        }
    }

    func testEveryEnemyHasThreePagesWithReadableHistoryAndInclusion() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["Encyclopedia"].waitForExistence(timeout: 20))
        app.buttons["Encyclopedia"].tap()
        app.buttons["encyclopedia-enemies"].tap()
        let keys = ["loyalist_militia", "regimental_drummer", "redcoat_regular", "light_infantry",
                    "hessian_jager", "hessian_fusilier", "queens_ranger", "highlander", "light_dragoon",
                    "spy", "grenadier", "royal_artillery", "mounted_officer", "foot_guards",
                    "howe_assault", "hill_rearguard", "clinton_siege"]
        func capture(_ name: String) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name; attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCTAssertFalse(app.staticTexts["Enemies"].exists)
        let roster = app.scrollViews["enemy-encyclopedia-list"]
        let first = app.buttons["enemy-entry-loyalist_militia"].frame
        let second = app.buttons["enemy-entry-regimental_drummer"].frame
        let third = app.buttons["enemy-entry-redcoat_regular"].frame
        XCTAssertEqual(first.minY, second.minY, accuracy: 1)
        XCTAssertGreaterThan(second.minX, first.minX)
        XCTAssertEqual(first.minX, third.minX, accuracy: 1)
        XCTAssertGreaterThan(third.minY, first.minY)
        XCTAssertFalse(app.buttons["enemy-entry-foot_guards"].isHittable)
        for key in keys {
            let list = app.scrollViews["enemy-encyclopedia-list"]
            let row = app.buttons["enemy-entry-\(key)"]
            for _ in 0..<10 {
                if row.isHittable { break }
                list.swipeUp()
            }
            XCTAssertTrue(row.isHittable, key)
            XCTAssertGreaterThanOrEqual(row.frame.height, 44)
            let name = row.label
            row.tap()
            XCTAssertTrue(row.isSelected)
            XCTAssertTrue(roster.exists)
            let pages = app.descendants(matching: .any)["enemy-encyclopedia-pages"].firstMatch
            XCTAssertGreaterThan(pages.frame.minX, roster.frame.maxX)
            let heading = app.staticTexts["enemy-detail-name"]
            XCTAssertEqual(heading.label, name)
            XCTAssertLessThan(heading.frame.maxY, pages.frame.minY)
            XCTAssertEqual(roster.staticTexts.count, 0, "Enemy roster tiles contain artwork only")
            let animation = app.otherElements["enemy-demonstration-animation"]
            XCTAssertTrue(animation.waitForExistence(timeout: 5), key)
            capture(key + "-demonstration")
            let playback = app.buttons["enemy-demonstration-playback"]
            XCTAssertTrue(playback.isHittable)
            playback.tap()
            XCTAssertEqual(playback.label, "Play demonstration")
            playback.tap()
            app.descendants(matching: .any)["enemy-encyclopedia-pages"].firstMatch.swipeLeft()
            let title = app.staticTexts["enemy-detail-name"]
            XCTAssertTrue(title.waitForExistence(timeout: 3))
            XCTAssertEqual(title.label, name)
            XCTAssertFalse(app.staticTexts["enemy-detail-strategy"].label.isEmpty)
            capture(key + "-strategy")
            let detail = app.scrollViews["enemy-encyclopedia-detail"]
            let exitCost = app.descendants(matching: .any)["enemy-stat-Lives lost at exit"].firstMatch
            for _ in 0..<16 {
                if exitCost.isHittable { break }
                let start = detail.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                let end = detail.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
                start.press(forDuration: 0.1, thenDragTo: end)
            }
            XCTAssertTrue(exitCost.isHittable)
            capture(key + "-stats")
            app.descendants(matching: .any)["enemy-encyclopedia-pages"].firstMatch.swipeLeft()
            let history = app.staticTexts["enemy-history-description"]
            XCTAssertTrue(history.waitForExistence(timeout: 3))
            XCTAssertFalse(history.label.isEmpty)
            let historyPage = app.scrollViews["enemy-encyclopedia-history"]
            XCTAssertFalse(historyPage.staticTexts["History"].exists)
            XCTAssertEqual(historyPage.links.count, 0)
            XCTAssertFalse(app.descendants(matching: .any)["enemy-history-source"].firstMatch.exists)
            XCTAssertFalse(app.descendants(matching: .any)["enemy-history-source-title"].firstMatch.exists)
            capture(key + "-history")
            let adaptation = app.staticTexts["enemy-history-adaptation"]
            for _ in 0..<8 {
                if adaptation.isHittable { break }
                historyPage.swipeUp()
            }
            XCTAssertTrue(adaptation.isHittable)
            XCTAssertFalse(app.staticTexts["enemy-history-inclusion"].label.isEmpty)
            XCTAssertFalse(adaptation.label.isEmpty)
            capture(key + "-inclusion-and-adaptation")
            XCTAssertTrue(app.buttons["enemy-encyclopedia-page-history"].isSelected)
            app.buttons["enemy-encyclopedia-page-details"].tap()
            XCTAssertTrue(title.waitForExistence(timeout: 3))
            app.buttons["enemy-encyclopedia-page-demo"].tap()
            XCTAssertTrue(animation.waitForExistence(timeout: 3))
        }
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Encyclopedia"].waitForExistence(timeout: 3))
    }
}
