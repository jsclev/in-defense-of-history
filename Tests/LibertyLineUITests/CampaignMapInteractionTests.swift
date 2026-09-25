import XCTest

@MainActor
final class CampaignMapInteractionTests: XCTestCase {
    func testNumberedMarkersRemainTappableOnTheNewMap() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        defer { app.terminate() }
        for number in [1, 7, 15] {
            app.launchArguments = ["--campaign-art-review"]
            app.launch()
            XCTAssertTrue(app.buttons["Encyclopedia"].waitForExistence(timeout: 20))
            let markers = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Level "))
            XCTAssertTrue(markers.firstMatch.waitForExistence(timeout: 5))
            XCTAssertEqual(markers.count, 15)
            for marker in markers.allElementsBoundByIndex {
                XCTAssertTrue(marker.isHittable, marker.label)
                XCTAssertGreaterThanOrEqual(marker.frame.width, 44, marker.label)
                XCTAssertGreaterThanOrEqual(marker.frame.height, 44, marker.label)
            }
            let map = XCTAttachment(screenshot: app.screenshot())
            map.name = "Campaign with numbered markers"
            map.lifetime = .keepAlways
            add(map)
            let marker = markers.matching(NSPredicate(format: "label BEGINSWITH %@", "Level \(number), ")).element
            let title = String(marker.label.dropFirst("Level \(number), ".count))
            marker.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5), title)
            XCTAssertTrue(app.buttons["Done"].exists)
            app.terminate()
        }
    }
}
