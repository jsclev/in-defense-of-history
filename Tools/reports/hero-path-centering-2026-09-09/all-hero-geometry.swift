import Foundation
import CoreGraphics
import ImageIO
@testable import LevelEditorFormats
@main struct Probe {
 static func main() throws {
 let root = URL(fileURLWithPath: "/Users/john/projects/td/in-defense-of-history")
 let art = root.deletingLastPathComponent().appendingPathComponent("in-defense-of-history-data")
 let db = Db(dbPath: root.appendingPathComponent("Db/in_defense_of_history.sqlite").path, fullRefresh: false)
 let virtual = try db.virtualCanvasDao.get()
 let level = try db.levelInfoDao.getCampaignLevels(campaignName: "Main").first { $0.mapImageName == "level_15_charleston" }!
 let paths = try db.pathDao.getPathsFor(levelInfoId: level.id)
 let data = try Data(contentsOf: root.appendingPathComponent("Db/level_15_charleston.geojson"))
 let config = try LevelGeoJSONDAO.heroConfiguration(from: data)
 let area = try LevelGeoJSONDAO.pathArea(from: data)!
 let maskImages = ["_forest_occlusion", "_occlusion"].compactMap { suffix -> CGImage? in
   let url = art.appendingPathComponent("LevelMaps/level_15_charleston\(suffix).png")
   guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
   return CGImageSourceCreateImageAtIndex(source, 0, nil)
 }
 let mask = HeroPlacementOcclusion(images: maskImages, canvasSize: virtual.size)
 for height in [340.0, 402.0, 900.0] {
  let rect = CGRect(x: 0, y: 0, width: height * 16 / 9, height: height)
  let canvas = RuntimeCanvas(virtualCanvas: virtual, physicalRect: rect, safeInsetsRect: rect)
  let manager = HeroStartingPositionManager(runtimeCanvas: canvas, paths: paths, exits: [Point(1395.1,338.71),Point(2340,1233),Point(399.34,1223.83),Point(1587,561),Point(1635.4,841.77)], pathArea: area, occlusion: mask)
  for hero in try db.heroDao.getAll() {
   let folder = art.appendingPathComponent("LibertyLineAssets.xcassets/\(hero.unitImageName!).imageset")
   let contents = try JSONSerialization.jsonObject(with: Data(contentsOf: folder.appendingPathComponent("Contents.json"))) as! [String: Any]
   let entry = (contents["images"] as! [[String: Any]]).first { $0["filename"] != nil }!
   let imageSource = CGImageSourceCreateWithURL(folder.appendingPathComponent(entry["filename"] as! String) as CFURL, nil)!
   let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)!
   for spawn in config.spawns {
    print("TRY",height,hero.shortName,spawn.role); fflush(stdout)
    let p = try manager.placement(for: HeroDeployment(hero: hero, spawn: spawn), imageAspectRatio: CGFloat(image.width) / CGFloat(image.height))
    print(height, hero.shortName, spawn.role.rawValue, p.position, p.pathCrossSection!.width); fflush(stdout)
   }
  }
 }
 }
}
