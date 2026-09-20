import XCTest
import CoreGraphics
import SQLite3
@testable import LevelEditorFormats

final class HudPlayAreaTests: XCTestCase {
    func testDatabaseCornerAssignmentsPropagateAndUnreservedEdgesFail() throws {
        var connection: OpaquePointer?
        XCTAssertEqual(sqlite3_open(":memory:", &connection), SQLITE_OK)
        defer { sqlite3_close(connection) }
        XCTAssertEqual(sqlite3_exec(connection, "CREATE TABLE player_hud_layout (id TEXT, hud_section_name TEXT, hud_location_name TEXT);", nil, nil, nil), SQLITE_OK)
        let dao = HudLayoutDAO(conn: connection)
        try dao.set(hudLayoutConfig: .standard)
        let swapped = HudLayoutConfig.standard.moving(.heroBar, to: .northEast)
        try dao.set(hudLayoutConfig: swapped)
        XCTAssertEqual(try dao.get(), swapped)
        XCTAssertEqual(sqlite3_exec(connection, "UPDATE player_hud_layout SET hud_location_name = 'north' WHERE hud_section_name = 'hero_bar';", nil, nil, nil), SQLITE_OK)
        XCTAssertThrowsError(try dao.get()) { error in
            XCTAssertTrue(String(describing: error).contains("hero_bar"))
            XCTAssertTrue(String(describing: error).contains("hud_location_name"))
        }
        try dao.set(hudLayoutConfig: swapped)
        XCTAssertThrowsError(try dao.set(hudLayoutConfig: swapped.moving(.heroBar, to: .north)))
        XCTAssertEqual(try dao.get(), swapped, "Reject invalid placement before altering authored rows")
    }
    private var canvas: VirtualCanvas {
        VirtualCanvas(size: CGSize(width: 2868, height: 2064),
            playAreaRect: CGRect(x: 474, y: 492, width: 1920, height: 1080),
            pathWidth: 140, towerSlotSize: CGSize(width: 176.6, height: 96.55),
            towerMenuTotalSize: CGSize(width: 435.9, height: 390.9),
            statsViewSizeFraction: CGSize(width: 0.30, height: 0.19),
            masterControlsSizeFraction: CGSize(width: 0.15, height: 0.17),
            heroBarSizeFraction: CGSize(width: 0.258, height: 0.17),
            miscViewSizeFraction: CGSize(width: 0.09, height: 0.17))
    }

    func testHUDUsesOriginalCornerSizesIndependentlyOfRoadClearance() {
        let hud = canvas.hudPlayArea
        XCTAssertEqual(hud.lowerLeftOcclusionArea.width, 495.36, accuracy: 1e-8)
        XCTAssertEqual(hud.lowerLeftOcclusionArea.height, 165.24, accuracy: 1e-8)
        XCTAssertEqual(hud.upperLeftOcclusionArea.width, 576, accuracy: 1e-8)
        XCTAssertEqual(hud.upperLeftOcclusionArea.height, 184.68, accuracy: 1e-8)
        XCTAssertEqual(hud.upperRightOcclusionArea.width, 288, accuracy: 1e-8)
        XCTAssertEqual(hud.lowerRightOcclusionArea.width, 172.8, accuracy: 1e-8)
        XCTAssertEqual(canvas.lowerLeftOcclusionArea.height, 214.812, accuracy: 1e-8)
        let betweenHUDAndRoad = CGPoint(x: 774, y: 680)
        XCTAssertTrue(hud.shape.contains(betweenHUDAndRoad))
        XCTAssertFalse(canvas.playAreaShape.contains(betweenHUDAndRoad))
        XCTAssertEqual(hud.occlusionAreas.count, 4)
    }

    func testBothCanvasesHaveFourCutoutsAndAConnectedInterior() {
        let physical = CGRect(x: 30, y: 20, width: 874, height: 402)
        let runtime = RuntimeCanvas(virtualCanvas: canvas, physicalRect: physical,
                                    safeInsetsRect: CGRect(x: 92, y: 20, width: 750, height: 382))
        for hud in [canvas.hudPlayArea, runtime.hudPlayArea] {
            XCTAssertTrue(hud.shape.contains(CGPoint(x: hud.bounds.midX, y: hud.bounds.midY)))
            for region in hud.occlusionAreas {
                XCTAssertTrue(hud.bounds.insetBy(dx: -1e-8, dy: -1e-8).contains(region))
                XCTAssertFalse(hud.shape.contains(CGPoint(x: region.midX, y: region.midY)))
            }
            for (index, a) in hud.occlusionAreas.enumerated() {
                for b in hud.occlusionAreas.dropFirst(index + 1) {
                    XCTAssertFalse(a.intersects(b))
                }
            }
        }
        for (original, projected) in zip(canvas.hudPlayArea.occlusionAreas, runtime.hudPlayArea.occlusionAreas) {
            XCTAssertEqual(projected.width, original.width * runtime.scaleFactor, accuracy: 1e-8)
            XCTAssertEqual(projected.height, original.height * runtime.scaleFactor, accuracy: 1e-8)
        }
    }

    func testAuthoredValidationMatchesTheEditorGuideProjection() {
        let vc = canvas
        let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: vc.size.height)
        let runtime = RuntimeCanvas(virtualCanvas: vc, physicalRect: CGRect(origin: .zero, size: vc.size),
                                    safeInsetsRect: vc.playAreaRect.applying(flip))
        let restored = runtime.hudPlayArea.applying(flip)
        XCTAssertEqual(restored.bounds, vc.hudPlayArea.bounds)
        for (actual, expected) in zip(restored.occlusionAreas, vc.hudPlayArea.occlusionAreas) {
            XCTAssertEqual(actual.minX, expected.minX, accuracy: 1e-8)
            XCTAssertEqual(actual.minY, expected.minY, accuracy: 1e-8)
            XCTAssertEqual(actual.width, expected.width, accuracy: 1e-8)
            XCTAssertEqual(actual.height, expected.height, accuracy: 1e-8)
        }
        var transform = flip
        let centres = runtime.towerSlotValidCentres.copy(using: &transform)!
        for x in stride(from: 500.0, to: 2350, by: 37) {
            for y in stride(from: 500.0, to: 1550, by: 37) {
                let point = CGPoint(x: x, y: y)
                XCTAssertEqual(centres.contains(point), vc.towerSlotValidCentres.contains(point))
            }
        }
    }

    func testButtonTargetsStayInSeparateReservationsAfterCornerSwaps() {
        let rect = CGRect(x: 0, y: 0, width: 874, height: 402)
        let runtime = RuntimeCanvas(virtualCanvas: canvas, physicalRect: rect, safeInsetsRect: rect)
        for hero in HudLocation.corners {
            let config = HudLayoutConfig.standard.moving(.heroBar, to: hero)
            let rows = [HeroBarLayout(runtimeCanvas: runtime, location: config.heroBar).frame,
                        MasterControlsLayout(runtimeCanvas: runtime, location: config.masterControls).frame,
                        HudButtonRowLayout(area: runtime.hudPlayArea, location: config.miscView, count: 1).frame,
                        runtime.hudPlayArea.fittedFrame(size: CGSize(width: 400, height: 150), at: config.statsView)]
            for (index, a) in rows.enumerated() {
                for b in rows.dropFirst(index + 1) { XCTAssertFalse(a.intersects(b)) }
            }
        }
    }

    func testLegacySavedCornerRectanglesDoNotControlHUDSizing() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(canvas)) as? [String: Any])
        json["upperLeftOcclusionArea"] = [[0, 0], [10, 10]]
        let restored = try JSONDecoder().decode(VirtualCanvas.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(restored.hudPlayArea.upperLeftOcclusionArea.size, canvas.hudPlayArea.upperLeftOcclusionArea.size)
    }

    func testValidSlotsKeepAllMenuButtonConfigurationsOutsideHUD() {
        let layout = TowerMenuLayout(virtualCanvas: canvas)
        for height in [340.0, 402, 744] {
            let physical = CGRect(x: 20, y: 30, width: height * 2.1, height: height)
            let runtime = RuntimeCanvas(virtualCanvas: canvas, physicalRect: physical,
                                        safeInsetsRect: physical.insetBy(dx: 30, dy: 10))
            let side = layout.getTowerButtonSize(playAreaScalingFactor: runtime.scaleFactor).width
            var validCount = 0
            for x in stride(from: runtime.playAreaRect.minX, through: runtime.playAreaRect.maxX, by: 17) {
                for y in stride(from: runtime.playAreaRect.minY, through: runtime.playAreaRect.maxY, by: 17) {
                    let anchor = CGPoint(x: x, y: y)
                    guard runtime.towerSlotValidCentres.contains(anchor) else { continue }
                    validCount += 1
                    var buttons = TowerKind.allCases.map {
                        layout.getTowerButtonCenterPoint(towerKind: $0, menuCenterPoint: anchor,
                            playAreaScalingFactor: runtime.scaleFactor, towerButtonSize: side)
                    }
                    for count in 1...5 {
                        for index in 0..<count {
                            buttons.append(layout.getButtonCenterPoint(index: index, count: count,
                                menuCenterPoint: anchor, playAreaScalingFactor: runtime.scaleFactor, towerButtonSize: side))
                            buttons.append(layout.getButtonSeatCenterPoint(index: index, count: count,
                                menuCenterPoint: anchor, playAreaScalingFactor: runtime.scaleFactor))
                        }
                    }
                    for center in buttons {
                        let target = CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
                        for hud in runtime.hudPlayArea.occlusionAreas { XCTAssertFalse(target.intersects(hud)) }
                    }
                }
            }
            XCTAssertGreaterThan(validCount, 0)
            for hud in runtime.hudPlayArea.occlusionAreas {
                let point = CGPoint(x: hud.midX, y: hud.midY)
                XCTAssertNil(MapDestinationInput(runtimeCanvas: runtime).mapPoint(at: point))
                XCTAssertFalse(runtime.runtimeTapArea.contains(point))
            }
        }
    }
}
