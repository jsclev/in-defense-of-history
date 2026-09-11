import SwiftUI
import UIKit

@main struct ExitMarkerProbe: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private let store = Store()
    var body: some Scene { WindowGroup { ExitMarkerProbeScreen(store: store) } }
}

private struct ExitMarkerProbeScreen: View {
    let store: Store
    @State private var mapName = "level_15_charleston"
    @State private var minimum = false

    var body: some View {
        ScreenGeometryGate(virtualCanvas: store.virtualCanvas) { deviceCanvas in
            let rect = CGRect(x: 0, y: 0, width: 340 * 16 / 9, height: 340)
            let canvas = minimum ? RuntimeCanvas(virtualCanvas: store.virtualCanvas,
                physicalRect: rect, safeInsetsRect: rect) : deviceCanvas
            let node = CampaignNode.load(db: store.db).first { $0.mapImageName == mapName }!
            LevelMapView(db: store.db, virtualCanvas: store.virtualCanvas, runtimeCanvas: canvas,
                towerMenuLayout: store.towerMenuLayout, node: node,
                difficulty: try! store.db.difficultyDao.getAll()[0],
                hudLayoutConfig: .standard, onExit: {})
                .id("\(mapName)-\(minimum)")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .task {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            do {
                UserDefaults.standard.set(false, forKey: Constants.debugModeKey)
                let rows = try checkAllExits(store: store, directory: directory)
                for small in [false, true] {
                    minimum = small
                    for name in ["level_01_battle_road", "level_008_trenton", "level_15_charleston"] {
                        mapName = name
                        try await Task.sleep(for: .milliseconds(1000))
                        let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                            .flatMap(\.windows).first { $0.isKeyWindow }!
                        for density in [CGFloat(1), 3] {
                            let format = UIGraphicsImageRendererFormat()
                            format.scale = density
                            let bounds = small ? CGRect(x: 0, y: 0, width: 340 * 16 / 9, height: 340) : window.bounds
                            let image = UIGraphicsImageRenderer(bounds: bounds, format: format).pngData { _ in
                                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                            }
                            try image.write(to: directory.appendingPathComponent("\(name)-\(small ? "minimum" : "device")@\(Int(density))x.png"))
                        }
                    }
                }
                let result: [String: Any] = ["passed": true, "runID": "PROBE_RUN_ID", "levels": rows,
                    "device": UIDevice.current.model, "systemVersion": UIDevice.current.systemVersion]
                try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("exit-markers.json"), options: .atomic)
            } catch {
                try? JSONSerialization.data(withJSONObject: ["passed": false, "runID": "PROBE_RUN_ID", "error": String(describing: error)])
                    .write(to: directory.appendingPathComponent("exit-markers.json"), options: .atomic)
            }
        }
    }
}

@MainActor private func checkAllExits(store: Store, directory: URL) throws -> [[String: Any]] {
    func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "ExitMarkerProbe", code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    try require(UIImage(named: "path_exit_rounded_x") != nil, "Rounded X missing from compiled catalog")
    let rect = CGRect(x: 0, y: 0, width: 340 * 16 / 9, height: 340)
    let canvas = RuntimeCanvas(virtualCanvas: store.virtualCanvas, physicalRect: rect, safeInsetsRect: rect)
    let projection = LevelMapArt.projection(virtualCanvas: store.virtualCanvas, fitting: canvas.playAreaRect)
    let spriteSize = MapSpriteScale(runtimeCanvas: canvas).points(MapSpriteSizing.exitMarker)
    try require(abs(spriteSize - 32) < 0.000001, "Incorrect minimum marker size")
    let levels = try store.db.levelInfoDao.getCampaignLevels(campaignName: "Main")
    try require(levels.count == 15, "Expected all 15 campaign levels")
    return try levels.map { level in
        let url = Bundle.main.url(forResource: level.mapImageName, withExtension: "geojson")!
        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        let features = (root["features"] as! [[String: Any]]).filter {
            ($0["properties"] as? [String: Any])?["kind"] as? String == "goal_point"
        }
        let expected = features.map { feature -> CGPoint in
            let geometry = feature["geometry"] as! [String: Any]
            let xy = geometry["coordinates"] as! [Double]
            return CGPoint(x: xy[0], y: xy[1])
        }
        let runner = LevelRunner(db: store.db, virtualCanvas: store.virtualCanvas,
            runtimeCanvas: canvas, levelInfoID: level.id, mapImageName: level.mapImageName)
        try require(runner.isReady, "\(level.name): \(runner.status)")
        try require(runner.exitPositions == expected, "\(level.name): exits differ from authored GeoJSON")
        let rendered = ZStack(alignment: .topLeading) {
            Color.clear
            LevelExitMarkersView(positions: runner.exitPositions, projection: projection, spriteSize: spriteSize)
        }.frame(width: rect.width, height: rect.height).clipped()
        for density in [CGFloat(1), 3] {
            let renderer = ImageRenderer(content: rendered)
            renderer.scale = density
            guard let bytes = renderer.uiImage?.pngData() else {
                throw NSError(domain: "ExitMarkerProbe", code: 2)
            }
            try bytes.write(to: directory.appendingPathComponent("\(level.mapImageName)-markers@\(Int(density))x.png"))
        }
        let positions: [[String: Any]] = try expected.map { p in
            let actual = projection.viewPoint(p)
            let authored = store.virtualCanvas.playAreaRect
            let px = canvas.playAreaRect.minX + (p.x - authored.minX) * projection.scale
            let py = canvas.playAreaRect.minY + (authored.maxY - p.y) * projection.scale
            try require(abs(actual.x - px) < 0.000001 && abs(actual.y - py) < 0.000001,
                "\(level.name): projection changed the authored center")
            return ["canonical": [p.x, p.y], "view": [actual.x, actual.y]]
        }
        return ["map": level.mapImageName, "count": expected.count,
                "minimumBoxPoints": spriteSize, "verticalFraction": TowerRangeOverlay.verticalFraction, "positions": positions]
    }
}
