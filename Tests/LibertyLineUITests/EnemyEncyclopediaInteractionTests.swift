import XCTest

@MainActor
final class EnemyEncyclopediaInteractionTests: XCTestCase {
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
                    "hessian_jager", "hessian_fusilier", "native_warrior", "highlander", "light_dragoon",
                    "spy", "grenadier", "royal_artillery", "mounted_officer", "foot_guards"]
        func capture(_ name: String) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name; attachment.lifetime = .keepAlways
            add(attachment)
        }
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
            XCTAssertTrue(app.descendants(matching: .any)["enemy-history-source"].firstMatch.isHittable)
            capture(key + "-history")
            let source = app.descendants(matching: .any)["enemy-history-source-title"].firstMatch
            for _ in 0..<8 {
                if source.isHittable { break }
                app.scrollViews["enemy-encyclopedia-history"].swipeUp()
            }
            XCTAssertTrue(source.isHittable)
            XCTAssertFalse(app.staticTexts["enemy-history-inclusion"].label.isEmpty)
            XCTAssertFalse(app.staticTexts["enemy-history-adaptation"].label.isEmpty)
            capture(key + "-inclusion-and-source")
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
