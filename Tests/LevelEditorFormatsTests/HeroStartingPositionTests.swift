import XCTest
import CoreGraphics
@testable import LevelEditorFormats

final class HeroStartingPositionTests: XCTestCase {
    private var canvas: VirtualCanvas {
        VirtualCanvas(size: CGSize(width: 1000, height: 800),
            playAreaRect: CGRect(x: 0, y: 0, width: 1000, height: 800), pathWidth: 20,
            towerSlotSize: CGSize(width: 10, height: 10), towerMenuTotalSize: CGSize(width: 50, height: 50),
            statsViewSizeFraction: .zero, masterControlsSizeFraction: .zero,
            heroBarSizeFraction: .zero, miscViewSizeFraction: .zero)
    }

    private func draft() -> MapDraft {
        var draft = MapDraft.starter
        draft.roads = [.init(name: "Main", points: [Point(100, 100), Point(800, 100)])]
        draft.entrances = [Point(100, 100)]
        draft.exits = [Point(800, 100)]
        draft.callWaveButtons = [.init(position: Point(100, 150))]
        return draft
    }

    func testNativeAndGeoJSONPreserveIndependentStartsAndRepositioning() throws {
        var draft = draft()
        draft.placeHero(.primary, at: Point(315.25, 466.5))
        draft.placeHero(.secondary, at: Point(732.75, 259.25))
        draft.placeHero(.primary, at: Point(427.75, 502.25))
        let native = try NativeMapFile.read(NativeMapFile(draft: draft, canvas: canvas).data())
        XCTAssertEqual(native.draft, draft)
        let data = try GeoJSONExport(virtualCanvas: canvas).data(for: native.draft)
        let imported = try GeoJSONImport.draft(from: data)
        XCTAssertEqual(imported.heroCount, 2)
        XCTAssertEqual(imported.primaryHeroPosition, draft.primaryHeroPosition)
        XCTAssertEqual(imported.secondaryHeroPosition, draft.secondaryHeroPosition)
        let configuration = try LevelGeoJSONDAO.heroConfiguration(from: data)
        XCTAssertEqual(configuration.spawns.map(\.position), [draft.primaryHeroPosition!, draft.secondaryHeroPosition!])
        let exit = try XCTUnwrap(try LevelGeoJSON(data: data).collection.features.first { $0.properties.kind == .exit })
        XCTAssertNil(exit.properties.heroRoles)
        draft.removeExit(at: 0)
        XCTAssertEqual(draft.heroMarkerPosition(.primary), imported.primaryHeroPosition)
        XCTAssertEqual(draft.heroMarkerPosition(.secondary), imported.secondaryHeroPosition)
    }

    func testBothEnabledRolesRequireExplicitStartsAndDisabledRolesAreNotExported() throws {
        var draft = draft()
        draft.placeHero(.secondary, at: Point(200, 400))
        XCTAssertEqual(draft.heroCount, 2)
        XCTAssertNil(draft.primaryHeroPosition)
        XCTAssertThrowsError(try GeoJSONExport(virtualCanvas: canvas).data(for: draft))
        draft.placeHero(.primary, at: Point(321.25, 567.75))
        let bytes = try GeoJSONExport(virtualCanvas: canvas).data(for: draft)
        let configuration = try LevelGeoJSONDAO.heroConfiguration(from: bytes)
        XCTAssertEqual(configuration.spawns.map(\.position), [Point(321.25, 567.75), Point(200, 400)])
        draft.heroCount = 1
        XCTAssertEqual(try LevelGeoJSONDAO.heroConfiguration(from: GeoJSONExport(virtualCanvas: canvas).data(for: draft)).spawns.count, 1)
        XCTAssertNil(draft.heroMarkerPosition(.secondary))
        draft.heroCount = 2
        XCTAssertEqual(draft.heroMarkerPosition(.secondary), Point(200, 400))
        draft.removeHeroStart(.secondary)
        XCTAssertNil(draft.secondaryHeroPosition)
        XCTAssertThrowsError(try GeoJSONExport(virtualCanvas: canvas).data(for: draft), "An exit cannot supply a missing start")
    }

    func testLoaderRejectsMissingMultipleAndDuplicateRoles() throws {
        func feature(_ id: String, kind: String = "hero_spawn", roles: [String]?) -> [String: Any] {
            var properties: [String: Any] = ["kind": kind]
            if let roles { properties["heroRoles"] = roles }
            return ["id": id, "geometry": ["type": "Point", "coordinates": [100, 200]], "properties": properties]
        }
        for features in [
            [feature("a", roles: nil)],
            [feature("a", roles: [])],
            [feature("a", roles: ["primary", "secondary"])],
            [feature("a", roles: ["primary"]), feature("b", kind: "goal_point", roles: ["primary"])],
            [feature("a", roles: ["primary"]), feature("a", roles: ["secondary"])]
        ] {
            let bytes = try JSONSerialization.data(withJSONObject: ["heroCount": 2, "features": features])
            XCTAssertThrowsError(try LevelGeoJSONDAO.heroConfiguration(from: bytes))
        }
    }

    @MainActor
    func testPlacementMoveAndResetUndoRedo() {
        let document = MapDocument(canvas: canvas)
        document.draft = draft()
        let undo = UndoManager()
        undo.groupsByEvent = false
        func edit(_ change: (inout MapDraft) -> Void) {
            undo.beginUndoGrouping()
            document.edit(undo, change)
            undo.endUndoGrouping()
        }
        edit { $0.placeHero(.primary, at: Point(200, 300)) }
        edit { $0.placeHero(.primary, at: Point(450, 500)) }
        undo.undo()
        XCTAssertEqual(document.draft.primaryHeroPosition, Point(200, 300))
        undo.redo()
        XCTAssertEqual(document.draft.primaryHeroPosition, Point(450, 500))
        edit { $0.removeHeroStart(.primary) }
        XCTAssertNil(document.draft.primaryHeroPosition)
        undo.undo()
        XCTAssertEqual(document.draft.primaryHeroPosition, Point(450, 500))
    }
}
