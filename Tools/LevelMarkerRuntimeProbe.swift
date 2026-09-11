// Separate physical-device app: checks production loaders, layouts, and views.
import SwiftUI
import CryptoKit

@main struct LevelMarkerRuntimeProbe: App {
    var body: some Scene { WindowGroup { MarkerProbeScreen() } }
}

private struct MarkerProbeScreen: View {
    @State private var store: Store?
    @State private var minimum = false
    @State private var captured = false

    var body: some View {
        GeometryReader { _ in
            if let store,
               let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap(\.windows).first,
               let node = CampaignNode.load(db: store.db).first(where: { $0.mapImageName == "level_15_charleston" }),
               let difficulty = try? store.db.difficultyDao.getAll().first {
                let smallRect = CGRect(x: 0, y: 0, width: 340 * 16 / 9, height: 340)
                let canvas = RuntimeCanvas(virtualCanvas: store.virtualCanvas,
                    physicalRect: minimum ? smallRect : window.bounds,
                    safeInsetsRect: minimum ? smallRect : window.bounds.inset(by: window.safeAreaInsets))
                LevelMapView(db: store.db, virtualCanvas: store.virtualCanvas, runtimeCanvas: canvas,
                    towerMenuLayout: store.towerMenuLayout, node: node, difficulty: difficulty,
                    hudLayoutConfig: .standard, onExit: {})
                    .frame(width: canvas.physicalRect.width, height: canvas.physicalRect.height)
                    .task {
                        guard !captured else { return }
                        captured = true
                        for small in [false, true] {
                            minimum = small
                            try? await Task.sleep(for: .seconds(2))
                            let format = UIGraphicsImageRendererFormat()
                            format.scale = 1
                            let image = UIGraphicsImageRenderer(bounds: small ? smallRect : window.bounds,
                                format: format).image { _ in
                                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                            }
                            try? image.pngData()?.write(to: markerDocuments.appendingPathComponent(
                                small ? "level-15-minimum.png" : "level-15-device.png"))
                        }
                        try? Data(markerRunID.utf8).write(to: markerDocuments.appendingPathComponent("captures-ready.txt"))
                    }
            } else {
                Text("Checking level 15 marker alignment").task {
                    let loaded = Store()
                    checkMarkers(store: loaded)
                    store = loaded
                }
            }
        }.ignoresSafeArea()
    }
}

private var markerDocuments: URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
}
private var markerRunID: String {
    let args = CommandLine.arguments
    return args.firstIndex(of: "--probe-run-id").map { args[$0 + 1] } ?? "manual"
}

@MainActor private func checkMarkers(store: Store) {
    var result: [String: Any] = ["runID": markerRunID, "passed": false]
    func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "LevelMarkerProbe", code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    do {
        let name = "level_15_charleston"
        let geoData = try Data(contentsOf: Bundle.main.url(forResource: name, withExtension: "geojson")!)
        let root = try JSONSerialization.jsonObject(with: geoData) as! [String: Any]
        let features = root["features"] as! [[String: Any]]
        func authored(_ kind: String) -> [CGPoint] {
            features.compactMap { feature in
                guard (feature["properties"] as? [String: Any])?["kind"] as? String == kind else { return nil }
                let xy = (feature["geometry"] as! [String: Any])["coordinates"] as! [Double]
                return CGPoint(x: xy[0], y: xy[1])
            }
        }
        let exits = authored("goal_point"), buttons = authored("call_wave_button")
        let loadedButtons = try store.db.levelGeoJSONDao.getCallWaveButtonPositions(mapImageName: name)
        try require(loadedButtons.map { CGPoint(x: $0.x, y: $0.y) } == buttons, "Loader changed call-wave coordinates")
        let level = try store.db.levelInfoDao.getCampaignLevels(campaignName: "Main").first { $0.mapImageName == name }!
        let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first!
        let small = CGRect(x: 0, y: 0, width: 340 * 16 / 9, height: 340)
        let viewports = [("minimum", small, small),
                         ("device", window.bounds, window.bounds.inset(by: window.safeAreaInsets))]
        var rows: [[String: Any]] = []
        for (viewport, physical, safe) in viewports {
            let runtime = RuntimeCanvas(virtualCanvas: store.virtualCanvas, physicalRect: physical, safeInsetsRect: safe)
            let projection = LevelMapProjection(playArea: store.virtualCanvas.playAreaRect,
                fitRect: runtime.playAreaRect, virtualCanvas: store.virtualCanvas)
            let runner = LevelRunner(db: store.db, virtualCanvas: store.virtualCanvas, runtimeCanvas: runtime,
                levelInfoID: level.id, mapImageName: name)
            try require(runner.isReady, runner.status)
            try require(runner.exitPositions == exits, "Runner changed exit coordinates")
            let spriteSize = MapSpriteScale(runtimeCanvas: runtime).points(MapSpriteSizing.exitMarker)
            for (kind, positions) in [("exit", exits), ("call-wave", buttons)] {
                for (index, point) in positions.enumerated() {
                    let center = projection.viewPoint(point)
                    let frame = kind == "exit"
                        ? ExitMarkerLayout(position: point, projection: projection, spriteSize: spriteSize).frame
                        : CallWaveButtonLayout(position: Point(point.x, point.y), runtimeCanvas: runtime).frame
                    // Overscan retains the entire marker even at the map edge.
                    let content = ZStack(alignment: .topLeading) {
                        if kind == "exit" {
                            LevelExitMarkersView(positions: [point], projection: projection, spriteSize: spriteSize)
                        } else {
                            CallWaveButtonLayer(runtimeCanvas: runtime, positions: [Point(point.x, point.y)],
                                waveNumber: 1, countdownSeconds: nil, action: {})
                        }
                    }.frame(width: physical.width, height: physical.height, alignment: .topLeading).padding(40)
                    let file = "\(viewport)-\(kind)-\(index).png"
                    let renderer = ImageRenderer(content: content)
                    renderer.scale = 3
                    guard let png = renderer.uiImage?.pngData() else {
                        throw NSError(domain: "LevelMarkerProbe", code: 2)
                    }
                    try png.write(to: markerDocuments.appendingPathComponent(file))
                    rows.append(["viewport": viewport, "kind": kind, "index": index, "image": file,
                        "density": 3, "padding": 40, "authored": [point.x, point.y],
                        "center": [center.x, center.y], "frame": [frame.minX, frame.minY, frame.width, frame.height]])
                }
            }
        }
        let pathURL = Bundle.main.url(forResource: name + "_path", withExtension: "heic", subdirectory: "Levels")
            ?? Bundle.main.url(forResource: name + "_path", withExtension: "png", subdirectory: "Levels")!
        result["geoJSONSHA256"] = hash(geoData)
        result["pathSHA256"] = hash(try Data(contentsOf: pathURL))
        result["pathFile"] = pathURL.lastPathComponent
        result["checks"] = rows
        result["passed"] = true
    } catch { result["error"] = String(describing: error) }
    let json = try! JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
    try! json.write(to: markerDocuments.appendingPathComponent("marker-placement.json"), options: .atomic)
}
