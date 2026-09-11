import XCTest
import CoreGraphics
@testable import LevelEditorFormats

final class HeroExitConfigurationTests: XCTestCase {
    private func hero(_ id: Int, ranking: Int) -> Hero {
        Hero(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!,
             shortName: "Hero \(id)", longName: "Hero \(id)", ranking: ranking, nickname: nil,
             unlockedAtLevelId: nil, unlockedAtLevelName: nil, unlockedAtCampaignName: nil,
             unlockedAtWave: 1, unlocked: true, fromMiniCampaign: false,
             generalDescription: "", historicalDescription: "", historicalText: "",
             primaryImageName: "", detailsImageName: "", iconImageName: "",
             abilityIconImageName: "", unitImageName: "hero_unit")
    }

    private func spawn(_ id: String, roles: [String], at coordinates: [Double]) -> [String: Any] {
        ["id": id, "geometry": ["type": "Point", "coordinates": coordinates],
         "properties": ["kind": "hero_spawn", "heroRoles": roles]]
    }

    private func read(_ object: [String: Any]) throws -> LevelHeroConfiguration {
        try LevelGeoJSONDAO.heroConfiguration(from: JSONSerialization.data(withJSONObject: object))
    }

    private var pair: [String: Any] {
        ["heroCount": 2, "features": [
            spawn("west", roles: ["secondary"], at: [17.25, 28.75]),
            spawn("east", roles: ["primary"], at: [91.5, 83.125])]]
    }

    func testRankingResolvesRolesAndExactStartingCoordinatesAtLoadTime() throws {
        let weak = hero(1, ranking: 60), strong = hero(2, ranking: 95)
        let configuration = try read(pair)
        for choices in [[weak, strong], [strong, weak]] {
            let deployments = configuration.deployments(for: try HeroSelection(heroes: choices))
            XCTAssertEqual(deployments.map(\.hero.id), [strong.id, weak.id])
            XCTAssertEqual(deployments.map(\.spawn.role), [.primary, .secondary])
            XCTAssertEqual(deployments.map(\.spawn.featureID), ["east", "west"])
            XCTAssertEqual(deployments.map(\.spawn.position), [Point(91.5, 83.125), Point(17.25, 28.75)])
        }
        let reranked = try HeroSelection(heroes: [hero(1, ranking: 100), strong])
        XCTAssertEqual(configuration.deployments(for: reranked).first?.hero.id, weak.id)
        var changed = pair
        changed["features"] = [spawn("west", roles: ["primary"], at: [21.5, 31.25]),
                               spawn("east", roles: ["secondary"], at: [99.5, 81.5])]
        XCTAssertEqual(try read(changed).deployments(for: reranked).first?.spawn.position, Point(21.5, 31.25))
    }

    func testCapacityLimitsAndOptionalSecondChoice() throws {
        let chosen = try HeroSelection(heroes: [hero(1, ranking: 60), hero(2, ranking: 95)])
        let single = try read(["heroCount": 1, "features": [spawn("only", roles: ["primary"], at: [1, 2])]])
        XCTAssertEqual(single.deployments(for: chosen).map(\.hero.id), [chosen.primary.id])
        let onlyOneChosen = try HeroSelection(heroes: [chosen.primary])
        XCTAssertEqual(try read(pair).deployments(for: onlyOneChosen).count, 1)
        XCTAssertEqual(try read(pair).deployments(for: onlyOneChosen).first?.spawn.role, .primary)
        XCTAssertTrue(try read(["heroCount": 0, "features": []]).deployments(for: chosen).isEmpty)
    }

    func testRolesCanHaveIdenticalExplicitCoordinates() throws {
        let configuration = try read(["heroCount": 2, "features": [
            spawn("primary", roles: ["primary"], at: [15.25, 25.5]),
            spawn("secondary", roles: ["secondary"], at: [15.25, 25.5])]])
        XCTAssertEqual(configuration.spawns.map(\.role), [.primary, .secondary])
        XCTAssertEqual(configuration.spawns.map(\.position), [Point(15.25, 25.5), Point(15.25, 25.5)])
    }

    func testRejectsMissingDuplicateUnknownAndMisplacedAssignments() throws {
        for invalid in [
            ["features": []], ["heroCount": true, "features": []],
            ["heroCount": 1.5, "features": []], ["heroCount": 3, "features": []],
            ["heroCount": 1, "features": []],
            ["heroCount": 1, "features": [spawn("a", roles: ["secondary"], at: [0, 0])]],
            ["heroCount": 2, "features": [spawn("a", roles: ["primary"], at: [0, 0])]],
            ["heroCount": 1, "features": [spawn("a", roles: ["primary", "primary"], at: [0, 0])]],
            ["heroCount": 1, "features": [spawn("a", roles: ["general"], at: [0, 0])]],
            ["heroCount": 0, "features": [spawn("a", roles: ["primary"], at: [0, 0])]],
            ["heroCount": 2, "features": [spawn("same", roles: ["primary"], at: [0, 0]), spawn("same", roles: ["secondary"], at: [1, 1])]],
            ["heroCount": 2, "features": [spawn("a", roles: ["primary"], at: [0, 0]), spawn("b", roles: ["primary"], at: [1, 1])]],
            ["heroCount": 1, "features": [spawn("a", roles: ["primary"], at: [0, 0, 0])]]
        ] as [[String: Any]] {
            XCTAssertThrowsError(try read(invalid), "Invalid configuration: \(invalid)")
        }
        var wrongKind = spawn("a", roles: ["primary"], at: [1, 2])
        wrongKind["properties"] = ["kind": "spawn_point", "heroRoles": ["primary"]]
        XCTAssertThrowsError(try read(["heroCount": 1, "features": [wrongKind]]))
        wrongKind["properties"] = ["kind": "goal_point", "heroRoles": "primary"]
        XCTAssertThrowsError(try read(["heroCount": 1, "features": [wrongKind]]))
    }

    func testEveryMainLevelHasExplicitCapacityAndStartingPoints() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Db")
        let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "geojson" }
        XCTAssertEqual(files.count, 15)
        var levels = Set<Int>()
        for file in files {
            let number = try XCTUnwrap(Int(file.lastPathComponent.split(separator: "_")[1]))
            levels.insert(number)
            let data = try Data(contentsOf: file)
            let configuration = try LevelGeoJSONDAO.heroConfiguration(from: data)
            XCTAssertEqual(configuration.heroCount, number <= 5 ? 1 : 2, file.lastPathComponent)
            XCTAssertEqual(configuration.spawns.count, configuration.heroCount)
            XCTAssertFalse(try LevelGeoJSONDAO.callWaveButtons(from: data).isEmpty)
            let imported = try GeoJSONImport.draft(from: data)
            XCTAssertEqual(imported.heroCount, configuration.heroCount)
            for spawn in configuration.spawns {
                XCTAssertEqual(imported.heroPosition(spawn.role), spawn.position, file.lastPathComponent)
            }
        }
        XCTAssertEqual(levels, Set(1...15))
    }

    func testLegacyImportCopiesCoordinatesOnceAndExportUsesIndependentPoints() throws {
        let canvas = VirtualCanvas(size: CGSize(width: 1000, height: 800),
            playAreaRect: CGRect(x: 0, y: 0, width: 1000, height: 800), pathWidth: 20,
            towerSlotSize: CGSize(width: 10, height: 10), towerMenuTotalSize: CGSize(width: 50, height: 50),
            statsViewSizeFraction: .zero, masterControlsSizeFraction: .zero,
            heroBarSizeFraction: .zero, miscViewSizeFraction: .zero)
        var draft = MapDraft.starter
        draft.roads = [.init(name: "Main", points: [Point(100, 100), Point(400, 100)])]
        draft.entrances = [Point(100, 100)]
        draft.exits = [Point(400.25, 100.75)]
        draft.callWaveButtons = [.init(position: Point(100, 150))]
        draft.heroCount = 2
        var native = try JSONSerialization.jsonObject(with: JSONEncoder().encode(draft)) as! [String: Any]
        native["primaryHeroExitIndex"] = 0
        native["secondaryHeroExitIndex"] = 0
        var migrated = try JSONDecoder().decode(MapDraft.self, from: JSONSerialization.data(withJSONObject: native))
        XCTAssertEqual(migrated.primaryHeroPosition, draft.exits[0])
        XCTAssertEqual(migrated.secondaryHeroPosition, draft.exits[0])
        var collection = try JSONSerialization.jsonObject(with: GeoJSONExport(virtualCanvas: canvas).data(for: migrated)) as! [String: Any]
        var features = (collection["features"] as! [[String: Any]]).filter {
            ($0["properties"] as! [String: Any])["kind"] as? String != "hero_spawn"
        }
        let exitIndex = features.firstIndex { ($0["properties"] as! [String: Any])["kind"] as? String == "goal_point" }!
        var properties = features[exitIndex]["properties"] as! [String: Any]
        properties["heroRoles"] = ["primary", "secondary"]
        features[exitIndex]["properties"] = properties
        collection["features"] = features
        let legacy = try JSONSerialization.data(withJSONObject: collection)
        XCTAssertThrowsError(try LevelGeoJSONDAO.heroConfiguration(from: legacy), "The game never falls back to exits")
        let imported = try GeoJSONImport.draft(from: legacy)
        XCTAssertEqual(imported.primaryHeroPosition, migrated.primaryHeroPosition)
        XCTAssertEqual(imported.secondaryHeroPosition, migrated.secondaryHeroPosition)
        let config = try LevelGeoJSONDAO.heroConfiguration(from: GeoJSONExport(virtualCanvas: canvas).data(for: imported))
        XCTAssertEqual(config.spawns.map(\.position), [draft.exits[0], draft.exits[0]])
        migrated.removeExit(at: 0)
        XCTAssertEqual(migrated.primaryHeroPosition, draft.exits[0], "Deleting an exit cannot move a hero start")
        XCTAssertEqual(migrated.secondaryHeroPosition, draft.exits[0])
        native.removeValue(forKey: "primaryHeroExitIndex")
        let missing = try JSONDecoder().decode(MapDraft.self, from: JSONSerialization.data(withJSONObject: native))
        XCTAssertNil(missing.primaryHeroPosition, "Missing assignments must never invent a start")
        XCTAssertThrowsError(try GeoJSONExport(virtualCanvas: canvas).data(for: missing))
    }
}
