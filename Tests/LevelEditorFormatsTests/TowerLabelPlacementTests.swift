import XCTest
@testable import LevelEditorFormats

final class TowerLabelPlacementTests: XCTestCase {
    private let safe = CGRect(x: 0, y: 0, width: 800, height: 360)

    func testSidePreferenceAndEdges() throws {
        let cases: [(CGRect, TowerLabelPlacement.Side)] = [
            (CGRect(x: 375, y: 180, width: 50, height: 50), .top),
            (CGRect(x: 20, y: 20, width: 50, height: 50), .right),
            (CGRect(x: 730, y: 20, width: 50, height: 50), .left),
            (CGRect(x: 70, y: 20, width: 650, height: 50), .bottom)
        ]
        for (button, expected) in cases {
            let result = try XCTUnwrap(TowerLabelPlacement.resolve(button: button, safeBounds: safe) { _ in 100 })
            XCTAssertEqual(result.side, expected)
            XCTAssertTrue(safe.contains(result.frame))
            XCTAssertFalse(button.intersects(result.frame))
            XCTAssertFalse(result.needsScrolling)
        }
    }

    func testObstacleRulesOutOtherwiseAvailableTop() throws {
        let button = CGRect(x: 375, y: 180, width: 50, height: 50)
        let hud = CGRect(x: 0, y: 0, width: 800, height: 160)
        let result = try XCTUnwrap(TowerLabelPlacement.resolve(button: button,
            safeBounds: safe, avoiding: [hud]) { _ in 100 })
        XCTAssertEqual(result.side, .right)
        XCTAssertFalse(result.frame.intersects(hud))
    }

    func testMeasuresAgainForNarrowSideAndKeepsFullCopy() throws {
        let button = CGRect(x: 500, y: 25, width: 50, height: 50)
        var measuredWidths: [CGFloat] = []
        let result = try XCTUnwrap(TowerLabelPlacement.resolve(button: button, safeBounds: safe) { width in
            measuredWidths.append(width)
            return width < 280 ? 150 : 110
        })
        XCTAssertEqual(result.side, .right)
        XCTAssertLessThan(result.frame.width, 280)
        XCTAssertEqual(result.frame.height, 150)
        XCTAssertTrue(measuredWidths.contains(result.frame.width))
    }

    func testLabelSlidesInsideSafeAreaWithoutCoveringOtherButton() throws {
        let button = CGRect(x: 40, y: 230, width: 50, height: 50)
        let neighbor = CGRect(x: 90, y: 120, width: 50, height: 50)
        let result = try XCTUnwrap(TowerLabelPlacement.resolve(button: button,
            safeBounds: safe, avoiding: [neighbor]) { _ in 100 })
        XCTAssertEqual(result.side, .top)
        XCTAssertTrue(safe.insetBy(dx: 6, dy: 6).contains(result.frame))
        XCTAssertFalse(result.frame.intersects(neighbor.insetBy(dx: -4, dy: -4)))
    }

    func testOversizedCopyScrollsWithoutShrinkingOrCoveringButton() throws {
        let button = CGRect(x: 375, y: 150, width: 50, height: 50)
        let result = try XCTUnwrap(TowerLabelPlacement.resolve(button: button, safeBounds: safe) { _ in 900 })
        XCTAssertTrue(result.needsScrolling)
        XCTAssertEqual(result.contentHeight, 900)
        XCTAssertTrue(safe.contains(result.frame))
        XCTAssertFalse(button.intersects(result.frame))
    }

    func testAllAuthoredTowersHaveMenuCopy() throws {
        let db = Db(dbPath: Db.authoredDatabaseURL.path, fullRefresh: false)
        defer { db.close() }
        let names = try db.towerTypeDao.getNamesByLevel()
        let details = try db.towerTypeDao.getMenuDetailsByLevel()
        var count = 0
        for (category, levels) in names {
            for (level, branches) in levels {
                for (branch, name) in branches {
                    let text = try XCTUnwrap(details[category]?[level]?[branch])
                    XCTAssertEqual(text.name, name)
                    XCTAssertFalse(text.description.isEmpty)
                    count += 1
                }
            }
        }
        XCTAssertEqual(count, 30)
        XCTAssertTrue(try XCTUnwrap(details[.special]?[4]?[3]).description.contains("charge"))
    }
}
