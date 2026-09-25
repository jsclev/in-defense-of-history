import XCTest

@MainActor
final class EncyclopediaCarouselInteractionTests: XCTestCase {
    func testIndicatorsSelectPagesDirectlyAndFollowSwipesAndRosterChanges() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeRight
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["Encyclopedia"].waitForExistence(timeout: 20))

        for category in ["tower", "enemy"] {
            app.buttons["Encyclopedia"].tap()
            app.buttons["encyclopedia-\(category == "tower" ? "towers" : "enemies")"].tap()
            if category == "tower" { app.buttons["tower-entry-ranged-1-1"].tap() }
            let prefix = "\(category)-encyclopedia"
            let demo = app.buttons["\(prefix)-page-demo"]
            let details = app.buttons["\(prefix)-page-details"]
            let history = app.buttons["\(prefix)-page-history"]
            let indicators = [demo, details, history]
            XCTAssertTrue(demo.waitForExistence(timeout: 5))
            XCTAssertEqual(demo.label, "Demonstration")
            XCTAssertEqual(details.label, category == "tower" ? "Stats" : "Tactics")
            XCTAssertEqual(history.label, "History")
            XCTAssertFalse(app.buttons["\(prefix)-swipe"].exists)
            let carousel = app.otherElements["\(prefix)-carousel"]
            for (index, indicator) in indicators.enumerated() {
                XCTAssertTrue(indicator.isHittable)
                XCTAssertGreaterThanOrEqual(indicator.frame.width, 44)
                XCTAssertGreaterThanOrEqual(indicator.frame.height, 44)
                XCTAssertTrue(carousel.frame.insetBy(dx: -0.5, dy: -0.5).contains(indicator.frame))
                XCTAssertEqual(indicator.value as? String, "Page \(index + 1) of 3")
                for other in indicators.dropFirst(index + 1) {
                    XCTAssertFalse(indicator.frame.intersects(other.frame))
                }
            }
            let geometry = try JSONSerialization.data(withJSONObject: indicators.map { indicator in
                ["id": indicator.identifier, "frame": [indicator.frame.minX, indicator.frame.minY,
                                                        indicator.frame.width, indicator.frame.height]]
            }, options: [.prettyPrinted, .sortedKeys])
            let geometryAttachment = XCTAttachment(data: geometry, uniformTypeIdentifier: "public.json")
            geometryAttachment.name = "\(category)-carousel-geometry"
            geometryAttachment.lifetime = .keepAlways
            add(geometryAttachment)

            func assertPage(_ index: Int, capture name: String? = nil) {
                for (position, indicator) in indicators.enumerated() {
                    XCTAssertEqual(indicator.isSelected, position == index)
                    XCTAssertTrue(indicator.isHittable)
                }
                let content = index == 0 ? app.otherElements["\(category)-demonstration-animation"] :
                    app.staticTexts[index == 1 && category == "tower" ? "tower-stat-cost" :
                        "\(category)-\(index == 1 ? "detail-name" : "history-description")"]
                XCTAssertTrue(content.waitForExistence(timeout: 3))
                if let name {
                    let attachment = XCTAttachment(screenshot: app.screenshot())
                    attachment.name = "\(category)-carousel-\(name)"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }

            assertPage(0, capture: "demo")
            // Jump over the middle page in either direction using the indicators.
            history.tap()
            assertPage(2, capture: "history")
            demo.tap()
            assertPage(0)
            details.tap()
            assertPage(1, capture: "details")
            details.tap() // Selecting the active indicator must not advance.
            assertPage(1)

            let pages = app.descendants(matching: .any)["\(prefix)-pages"].firstMatch
            pages.swipeLeft()
            assertPage(2)
            pages.swipeRight()
            assertPage(1)
            pages.swipeRight()
            assertPage(0)
            pages.swipeRight() // The first page stays selected at the boundary.
            assertPage(0)

            history.tap()
            if category == "tower" { app.buttons["tower-encyclopedia-back"].tap() }
            app.buttons[category == "tower" ? "tower-entry-special-4-1" : "enemy-entry-regimental_drummer"].tap()
            assertPage(0, capture: "new-selection")
            if category == "tower" { app.buttons["tower-encyclopedia-back"].tap() }
            app.buttons["Done"].tap()
            XCTAssertTrue(app.buttons["Encyclopedia"].waitForExistence(timeout: 3))
        }
    }
}
