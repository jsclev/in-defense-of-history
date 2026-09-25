import XCTest

@MainActor
final class TowerEncyclopediaInteractionTests: XCTestCase {
    func testStatsLeadWithValuesAndHistoryHasNoRepeatedHeading() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeRight
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["Encyclopedia"].waitForExistence(timeout: 20))
        app.buttons["Encyclopedia"].tap()
        app.buttons["encyclopedia-towers"].tap()
        app.buttons["tower-entry-special-4-1"].tap()
        let stats = app.buttons["tower-encyclopedia-page-details"]
        XCTAssertEqual(stats.label, "Stats")
        stats.tap()
        XCTAssertFalse(app.staticTexts["tower-detail-name"].exists)
        XCTAssertFalse(app.staticTexts["Base stats"].exists)
        let cost = app.staticTexts["tower-stat-cost"]
        let damage = app.descendants(matching: .any)["tower-stat-Damage"].firstMatch
        XCTAssertTrue(cost.isHittable)
        XCTAssertTrue(damage.isHittable)
        let description = app.staticTexts["tower-detail-description"]
        XCTAssertGreaterThan(description.frame.minY, damage.frame.maxY)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "grenadier-stats-values-first"
        attachment.lifetime = .keepAlways
        add(attachment)
        let detail = app.scrollViews["tower-encyclopedia-detail"]
        for _ in 0..<20 {
            if description.isHittable { break }
            detail.swipeUp()
        }
        XCTAssertTrue(description.isHittable, "The description remains available below the stats and upgrades")
        XCTAssertFalse(description.label.isEmpty)
        app.buttons["tower-encyclopedia-page-history"].tap()
        let history = app.scrollViews["tower-encyclopedia-history"]
        let prose = app.staticTexts["tower-history-description"]
        XCTAssertTrue(prose.waitForExistence(timeout: 3))
        XCTAssertFalse(history.staticTexts["History"].exists)
        XCTAssertLessThan(prose.frame.minY - history.frame.minY, 18,
                          "History starts with the prose rather than reserving a heading row")
        let source = app.descendants(matching: .any)["tower-history-source"].firstMatch
        for _ in 0..<12 {
            if source.isHittable { break }
            history.swipeUp()
        }
        XCTAssertTrue(source.isHittable, "Keep the historical source accessible at the end")
    }

    func testLayoutGuidesFollowSettingsAcrossAllEncyclopediaScreens() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeRight
        let app = XCUIApplication()
        app.launchArguments = ["--encyclopedia-guides-review"]
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 20))

        for enabled in [true, false] {
            app.buttons["Settings"].tap()
            let toggle = app.switches.matching(NSPredicate(format: "label BEGINSWITH %@", "Layout guides")).firstMatch
            for _ in 0..<8 {
                if toggle.isHittable { break }
                app.scrollViews.firstMatch.swipeUp()
            }
            XCTAssertTrue(toggle.isHittable)
            if (toggle.value as? String) != (enabled ? "1" : "0") { toggle.tap() }
            XCTAssertEqual(toggle.value as? String, enabled ? "1" : "0")
            app.buttons["Done"].tap()

            for category in ["towers", "enemies"] {
                app.buttons["Encyclopedia"].tap()
                XCTAssertTrue(app.buttons["encyclopedia-\(category)"].waitForExistence(timeout: 5))
                XCTAssertEqual(app.otherElements["encyclopedia-screen"].value as? String,
                               enabled ? "Layout guides on" : "Layout guides off")
                Thread.sleep(forTimeInterval: 1) // Allow the native review capture to finish.
                app.buttons["encyclopedia-\(category)"].tap()
                let button = category == "towers" ? app.buttons["tower-entry-special-4-1"] :
                    app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "enemy-entry-")).firstMatch
                XCTAssertTrue(button.waitForExistence(timeout: 5))
                XCTAssertEqual(app.otherElements["encyclopedia-screen"].value as? String,
                               enabled ? "Layout guides on" : "Layout guides off")
                XCTAssertTrue(button.isHittable, "Guides must not intercept taps")
                button.tap()
                let prefix = category == "towers" ? "tower" : "enemy"
                let history = app.buttons["\(prefix)-encyclopedia-page-history"]
                XCTAssertTrue(history.isHittable)
                history.tap()
                XCTAssertTrue(history.isSelected)
                app.buttons["\(prefix)-encyclopedia-page-demo"].tap()
                Thread.sleep(forTimeInterval: 1)
                app.buttons["Done"].tap()
            }
        }
    }

    func testCampaignOffersAllThreeEngineerSpecializationsWithoutOverlappingPlacement() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeRight
        let app = XCUIApplication()
        app.launchArguments = ["--play-level", "15"]
        app.launch()
        defer { app.terminate() }
        let slot = app.buttons["tower-slot-0"]
        XCTAssertTrue(slot.waitForExistence(timeout: 20))
        slot.tap()
        let build = app.buttons["tower-build-special"]
        XCTAssertTrue(build.waitForExistence(timeout: 3))
        build.tap(); build.tap()
        // These ordinary purchases use Charleston's unchanged 500-coin seed.
        for _ in 0..<2 {
            slot.tap()
            let upgrade = app.buttons["tower-upgrade-special-1"]
            XCTAssertTrue(upgrade.waitForExistence(timeout: 3))
            upgrade.tap(); upgrade.tap()
        }
        slot.tap()
        let names = ["Grenadier Redoubt", "Fieldworks Corps", "Demolition Sappers"]
        let placement = app.buttons["engineer-obstacle-placement"]
        XCTAssertTrue(placement.isHittable)
        var frames = [placement.frame]
        for branch in 1...3 {
            let option = app.buttons["tower-upgrade-special-\(branch)"]
            XCTAssertEqual(option.label, names[branch - 1])
            XCTAssertTrue(option.isHittable)
            XCTAssertTrue(frames.allSatisfy { !$0.intersects(option.frame) })
            frames.append(option.frame)
        }
        app.buttons["tower-upgrade-special-1"].tap()
        let description = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Automatically throws grenades")).firstMatch
        XCTAssertTrue(description.waitForExistence(timeout: 3))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "campaign-grenadier-specialization"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testWholeRosterIsVisibleInFiveColumnsAndSixRowsAndSelectsDirectly() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeRight
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["Encyclopedia"].waitForExistence(timeout: 20))
        app.buttons["Encyclopedia"].tap()
        app.buttons["encyclopedia-towers"].tap()
        let grid = app.otherElements["tower-encyclopedia-grid"]
        XCTAssertTrue(grid.waitForExistence(timeout: 5))
        let buttons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tower-entry-"))
        // Every authored tower is visible in the complete five-by-six grid.
        XCTAssertEqual(buttons.count, 30)
        XCTAssertFalse(app.staticTexts["TOWERS"].exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tower-family-")).count, 0)
        let frames = buttons.allElementsBoundByIndex.map(\.frame)
        XCTAssertEqual(Set(frames.map { Int($0.midX.rounded()) }).count, 5)
        XCTAssertEqual(Set(frames.map { Int($0.midY.rounded()) }).count, 6)
        for row in Dictionary(grouping: frames, by: { Int($0.midY.rounded()) }).values {
            let ordered = row.sorted { $0.minX < $1.minX }
            for (left, right) in zip(ordered, ordered.dropFirst()) {
                XCTAssertEqual(left.maxX, right.minX, accuracy: 0.5,
                               "Adjacent tower buttons must share a boundary")
            }
        }
        for column in Dictionary(grouping: frames, by: { Int($0.midX.rounded()) }).values {
            let ordered = column.sorted { $0.minY < $1.minY }
            for (upper, lower) in zip(ordered, ordered.dropFirst()) {
                XCTAssertEqual(upper.maxY, lower.minY, accuracy: 0.5,
                               "Tower rows must meet without a gap")
            }
        }
        for button in buttons.allElementsBoundByIndex {
            XCTAssertTrue(button.isHittable, button.identifier)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            XCTAssertTrue(grid.frame.insetBy(dx: -0.5, dy: -0.5).contains(button.frame))
        }
        let initial = XCTAttachment(screenshot: app.screenshot())
        initial.name = "complete-tower-grid-on-colonial-scroll"
        initial.lifetime = .keepAlways
        add(initial)
        // Cross family and tier boundaries without opening any intermediate menu.
        for id in ["tower-entry-special-4-1", "tower-entry-supply-4-3", "tower-entry-special-4-3",
                   "tower-entry-areaOfEffect-4-4", "tower-entry-ranged-1-1"] {
            let button = app.buttons[id]
            let expected = String(button.label.dropFirst("Level 1, ".count))
            button.tap()
            XCTAssertTrue(button.isSelected)
            XCTAssertEqual(app.staticTexts["tower-selection-name"].label, expected)
            XCTAssertTrue(app.otherElements["tower-demonstration-animation"].exists)
            XCTAssertTrue(buttons.allElementsBoundByIndex.allSatisfy(\.isHittable))
        }
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Encyclopedia"].waitForExistence(timeout: 3))
    }

    func testMortarDemonstrationStrategyAndHistoricalPurposeAreReachable() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeRight
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["Encyclopedia"].waitForExistence(timeout: 20))
        app.buttons["Encyclopedia"].tap()
        app.buttons["encyclopedia-towers"].tap()
        app.buttons["tower-entry-areaOfEffect-4-1"].tap()
        let animation = app.otherElements["tower-demonstration-animation"]
        XCTAssertTrue(animation.waitForExistence(timeout: 5))

        func capture(_ name: String) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        capture("mortar-live-demonstration")
        app.descendants(matching: .any)["tower-encyclopedia-pages"].firstMatch.swipeLeft()
        XCTAssertEqual(app.staticTexts["tower-selection-name"].label, "Mortar Battery")
        XCTAssertTrue(app.staticTexts["tower-stat-cost"].isHittable)
        XCTAssertTrue(app.descendants(matching: .any)["tower-stat-Damage"].firstMatch.isHittable)
        XCTAssertFalse(app.staticTexts["tower-detail-name"].exists)
        XCTAssertFalse(app.staticTexts["Base stats"].exists)
        XCTAssertEqual(app.buttons["tower-encyclopedia-page-details"].label, "Stats")
        capture("mortar-strategic-stats")
        let detail = app.scrollViews["tower-encyclopedia-detail"]
        let strategy = app.staticTexts["tower-detail-strategy"]
        let usageHeading = app.staticTexts["Using the battery"]
        for _ in 0..<30 {
            if usageHeading.isHittable { break }
            let start = detail.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            let end = detail.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        XCTAssertTrue(usageHeading.isHittable)
        XCTAssertTrue(strategy.label.contains("pause between shells"))
        capture("mortar-strategic-usage")

        app.descendants(matching: .any)["tower-encyclopedia-pages"].firstMatch.swipeLeft()
        let history = app.staticTexts["tower-history-description"]
        XCTAssertTrue(history.waitForExistence(timeout: 3))
        XCTAssertTrue(history.label.contains("Yorktown"))
        capture("mortar-historical-context")
        let historyScroll = app.scrollViews["tower-encyclopedia-history"]
        let source = app.descendants(matching: .any)["tower-history-source"].firstMatch
        for _ in 0..<7 {
            if source.isHittable { break }
            historyScroll.swipeUp()
        }
        let inclusion = app.staticTexts["tower-history-inclusion"]
        XCTAssertTrue(inclusion.exists)
        XCTAssertTrue(inclusion.label.contains("We included the Mortar Battery"))
        XCTAssertTrue(inclusion.label.contains("gameplay abstractions"))
        XCTAssertTrue(source.isHittable)
        capture("mortar-historical-inclusion")
        XCTAssertTrue(app.buttons["tower-encyclopedia-page-history"].isSelected)
        app.buttons["tower-encyclopedia-page-details"].tap()
        XCTAssertTrue(detail.waitForExistence(timeout: 3))
        app.buttons["tower-encyclopedia-page-demo"].tap()
        XCTAssertTrue(animation.waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Encyclopedia"].waitForExistence(timeout: 3))
    }

    func testEveryTowerAndSpecializationCanBeReadAndNavigationReturnsToCampaign() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }
        let encyclopedia = app.buttons["Encyclopedia"]
        XCTAssertTrue(encyclopedia.waitForExistence(timeout: 20))
        encyclopedia.tap()
        let towers = app.buttons["encyclopedia-towers"]
        XCTAssertTrue(towers.waitForExistence(timeout: 5))
        towers.tap()

        func capture(_ name: String) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        let families: [(String, [Int])] = [
            ("areaOfEffect", [1, 2, 4]), ("melee", [1, 2, 3]),
            ("ranged", [1, 2, 3]), ("special", [1, 2, 3]), ("supply", [1, 2, 3])
        ]
        var visited = 0
        for (family, branches) in families {
            let entries = [(1, 1), (2, 1), (3, 1)] + branches.map { (4, $0) }
            for (level, branch) in entries {
                let list = app.otherElements["tower-encyclopedia-grid"]
                let row = app.buttons["tower-entry-\(family)-\(level)-\(branch)"]
                XCTAssertTrue(row.isHittable)
                XCTAssertTrue(list.frame.contains(row.frame), "Every tower must fit without scrolling")
                let name = String(row.label.dropFirst("Level \(level), ".count))
                row.tap()
                XCTAssertTrue(app.otherElements["tower-demonstration-animation"].waitForExistence(timeout: 3))
                app.descendants(matching: .any)["tower-encyclopedia-pages"].firstMatch.swipeLeft()
                let title = app.staticTexts["tower-selection-name"]
                XCTAssertTrue(title.waitForExistence(timeout: 3))
                XCTAssertEqual(title.label, name)
                let description = app.staticTexts["tower-detail-description"]
                XCTAssertFalse(description.label.isEmpty)
                XCTAssertTrue(app.staticTexts["tower-stat-cost"].isHittable)
                if level == 1 || level == 4 { capture("\(family)-\(level)-\(branch)") }
                app.descendants(matching: .any)["tower-encyclopedia-pages"].firstMatch.swipeLeft()
                let history = app.staticTexts["tower-history-description"]
                XCTAssertTrue(history.waitForExistence(timeout: 3))
                XCTAssertFalse(history.label.isEmpty)
                XCTAssertTrue(history.isHittable)
                let source = app.descendants(matching: .any)["tower-history-source"].firstMatch
                for _ in 0..<12 {
                    if source.isHittable { break }
                    app.scrollViews["tower-encyclopedia-history"].swipeUp()
                }
                XCTAssertTrue(source.isHittable)
                XCTAssertTrue(app.buttons["tower-encyclopedia-page-history"].isSelected)
                capture("\(family)-\(level)-\(branch)-history")
                // Each labeled indicator jumps straight to its destination.
                app.buttons["tower-encyclopedia-page-details"].tap()
                XCTAssertTrue(title.waitForExistence(timeout: 3))
                app.buttons["tower-encyclopedia-page-demo"].tap()
                XCTAssertTrue(app.otherElements["tower-demonstration-animation"].waitForExistence(timeout: 3))
                app.descendants(matching: .any)["tower-encyclopedia-pages"].firstMatch.swipeLeft()
                visited += 1
            }
        }
        XCTAssertEqual(visited, 30)

        // The final hospital entry has long copy and two upgrade paths below
        // the fold. Exercise the actual detail scroll, not a renderer snapshot.
        let detail = app.scrollViews["tower-encyclopedia-detail"]
        let upgrade = app.staticTexts["Hospital Stations"]
        for _ in 0..<7 {
            if upgrade.isHittable { break }
            detail.swipeUp()
        }
        XCTAssertTrue(upgrade.isHittable)
        capture("hospital-upgrades")
        app.buttons["Done"].tap()
        XCTAssertTrue(encyclopedia.waitForExistence(timeout: 3))
    }
}
