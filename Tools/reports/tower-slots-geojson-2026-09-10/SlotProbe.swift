import SwiftUI
import UIKit

@main struct SlotProbe: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private let store = Store()
    var body: some Scene { WindowGroup { SlotProbeScreen(store: store) } }
}

private struct SlotProbeScreen: View {
    let store: Store
    @State private var minimum = false
    @State private var mapName = "level_15_charleston"
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
                guard let image = UIImage(named: "tower_slot_available"),
                    image.size == CGSize(width: 176, height: 96),
                    UIImage(named: "tower_slot_field") != nil else { throw NSError(domain: "SlotProbe", code: 1) }
                try image.pngData()!.write(to: directory.appendingPathComponent("loaded-slot.png"))
                let levels = try checkAllSlots(store: store)
                let transition = try checkBuildTransition(store: store, directory: directory)
                var captures: [[String: Any]] = []
                for small in [false, true] {
                    minimum = small
                    for name in ["level_15_charleston", "level_01_battle_road"] {
                        mapName = name
                        try await Task.sleep(for: .milliseconds(1300))
                        let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                            .flatMap(\.windows).first { $0.isKeyWindow }!
                        for density in [CGFloat(1), 3] {
                            let format = UIGraphicsImageRendererFormat(); format.scale = density
                            let bounds = small ? CGRect(x: 0, y: 0, width: 340 * 16 / 9, height: 340) : window.bounds
                            let data = UIGraphicsImageRenderer(bounds: bounds, format: format).pngData { _ in
                                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                            }
                            let file = "\(name)-\(small ? "minimum" : "device")@\(Int(density))x.png"
                            try data.write(to: directory.appendingPathComponent(file))
                            captures.append(["file": file, "widthPoints": bounds.width, "heightPoints": bounds.height, "density": density])
                        }
                    }
                }
                let result: [String: Any] = ["passed": true, "runID": "PROBE_RUN_ID",
                    "device": UIDevice.current.model, "systemVersion": UIDevice.current.systemVersion,
                    "levels": levels, "assetLogicalSize": [image.size.width, image.size.height], "buildTransition": transition, "captures": captures]
                try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("slot-check.json"), options: .atomic)
            } catch {
                try? JSONSerialization.data(withJSONObject: ["passed": false, "runID": "PROBE_RUN_ID", "error": String(describing: error)])
                    .write(to: directory.appendingPathComponent("slot-check.json"), options: .atomic)
            }
        }
    }
}

@MainActor private func checkBuildTransition(store: Store, directory: URL) throws -> [String: Any] {
    func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "SlotProbe", code: 2, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    let rect = CGRect(x: 0, y: 0, width: 340 * 16 / 9, height: 340)
    let canvas = RuntimeCanvas(virtualCanvas: store.virtualCanvas, physicalRect: rect, safeInsetsRect: rect)
    let node = CampaignNode.load(db: store.db).first { $0.mapImageName == "level_15_charleston" }!
    let runner = LevelRunner(db: store.db, virtualCanvas: store.virtualCanvas, runtimeCanvas: canvas,
        levelInfoID: node.levelInfoID, mapImageName: node.mapImageName)
    try require(runner.isReady && !runner.slotPositions.isEmpty, "Level runner did not load")
    let projection = LevelMapArt.projection(virtualCanvas: store.virtualCanvas, fitting: canvas.playAreaRect)
    func render(_ stage: String) throws -> Data {
        let content = ZStack(alignment: .topLeading) {
            runner.mapArt.underlay(in: projection)
            LevelTowerSlotsView(debugMode: false, slotPositions: runner.slotPositions,
                occupiedSlotIndices: Set(runner.placedTowers.map(\.slotIndex)), size: runner.slotSize, projection: projection)
            runner.mapArt.occlusion(in: projection)
        }.frame(width: rect.width, height: rect.height).clipped()
        let renderer = ImageRenderer(content: content); renderer.scale = 3
        guard let bytes = renderer.uiImage?.pngData() else { throw NSError(domain: "SlotProbe", code: 3) }
        try bytes.write(to: directory.appendingPathComponent("slot-layer-\(stage)@3x.png"))
        return bytes
    }
    try require(!runner.isSlotOccupied(0), "Fixture site is already occupied")
    let before = try render("available")
    runner.selectSlot(runner.slotPositions.count - 1)
    runner.tapBuildButton(.ranged)
    runner.tapBuildButton(.ranged)
    try require(runner.isSlotOccupied(runner.slotPositions.count - 1) && runner.placedTowers.count == 1, "Real build confirmation failed")
    try require(runner.placedTowers[0].position == runner.slotPositions.last!, "Built tower ignored authored slot")
    let after = try render("occupied")
    try require(before != after, "Slot layer did not change when site became occupied")
    return ["passed": true, "slotIndex": runner.slotPositions.count - 1, "towerCount": runner.placedTowers.count,
        "slotBoxPoints": [projection.viewLength(runner.slotSize.width), projection.viewLength(runner.slotSize.height)],
        "transition": "Available hammer marker changes to existing ground after real select/arm/confirm build"]
}

@MainActor private func checkAllSlots(store: Store) throws -> [[String: Any]] {
    let rect = CGRect(x: 0, y: 0, width: 340 * 16 / 9, height: 340)
    let canvas = RuntimeCanvas(virtualCanvas: store.virtualCanvas, physicalRect: rect, safeInsetsRect: rect)
    var rows: [[String: Any]] = []
    for node in CampaignNode.load(db: store.db) where Bundle.main.url(forResource: node.mapImageName, withExtension: "geojson") != nil {
        let bytes = try Data(contentsOf: Bundle.main.url(forResource: node.mapImageName, withExtension: "geojson")!)
        let root = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
        let features = (root["features"] as! [[String: Any]]).filter { ($0["properties"] as! [String: Any])["kind"] as? String == "tower_slot" }
            .sorted { (($0["properties"] as! [String: Any])["slotIndex"] as! Int) < (($1["properties"] as! [String: Any])["slotIndex"] as! Int) }
        let expected = features.map { feature -> CGPoint in
            let xy = (feature["geometry"] as! [String: Any])["coordinates"] as! [Double]
            return CGPoint(x: xy[0], y: xy[1])
        }
        let runner = LevelRunner(db: store.db, virtualCanvas: store.virtualCanvas, runtimeCanvas: canvas,
            levelInfoID: node.levelInfoID, mapImageName: node.mapImageName)
        guard runner.isReady && runner.slotPositions == expected else {
            throw NSError(domain: "SlotProbe", code: 4, userInfo: [NSLocalizedDescriptionKey: "GeoJSON mismatch: \(node.mapImageName) \(runner.status)"])
        }
        rows.append(["map": node.mapImageName, "count": expected.count, "positions": expected.map { [$0.x, $0.y] }])
    }
    guard rows.count == 15 else { throw NSError(domain: "SlotProbe", code: 5) }
    return rows
}
