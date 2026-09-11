import SwiftUI
import UIKit

@main struct GrassProbe: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private let store = Store()
    var body: some Scene { WindowGroup { GrassProbeScreen(store: store) } }
}

private struct GrassProbeScreen: View {
    let store: Store
    @State private var minimum = false

    var body: some View {
        ScreenGeometryGate(virtualCanvas: store.virtualCanvas) { deviceCanvas in
            let rect = CGRect(x: 0, y: 0, width: 340 * 16 / 9, height: 340)
            let canvas = minimum ? RuntimeCanvas(virtualCanvas: store.virtualCanvas,
                physicalRect: rect, safeInsetsRect: rect) : deviceCanvas
            let node = CampaignNode.load(db: store.db).first { $0.mapImageName == "level_01_battle_road" }!
            LevelMapView(db: store.db, virtualCanvas: store.virtualCanvas, runtimeCanvas: canvas,
                towerMenuLayout: store.towerMenuLayout, node: node,
                difficulty: try! store.db.difficultyDao.getAll()[0],
                hudLayoutConfig: .standard, onExit: {})
                .id(minimum)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .task {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            do {
                UserDefaults.standard.set(false, forKey: Constants.debugModeKey)
                let art = LevelMapArt(mapImageName: "level_01_battle_road")
                let grassURL = Bundle.main.url(forResource: "grass_bastion", withExtension: "png", subdirectory: "Levels")!
                let grass = UIImage(contentsOfFile: grassURL.path)!
                guard let map = art.mapImage, map.size == CGSize(width: 2868, height: 2064),
                    grass.size == map.size else { throw NSError(domain: "GrassProbe", code: 1) }
                var captures: [[String: Any]] = []
                for small in [false, true] {
                    minimum = small
                    try await Task.sleep(for: .milliseconds(1500))
                    let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                        .flatMap(\.windows).first { $0.isKeyWindow }!
                    for density in [CGFloat(1), 3] {
                        let format = UIGraphicsImageRendererFormat()
                        format.scale = density
                        let bounds = small ? CGRect(x: 0, y: 0, width: 340 * 16 / 9, height: 340) : window.bounds
                        let data = UIGraphicsImageRenderer(bounds: bounds, format: format).pngData { _ in
                            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                        }
                        let name = "battle-road-\(small ? "minimum" : "device")@\(Int(density))x.png"
                        try data.write(to: directory.appendingPathComponent(name))
                        captures.append(["file": name, "widthPoints": bounds.width, "heightPoints": bounds.height,
                            "density": density, "windowWidthPoints": window.bounds.width, "windowHeightPoints": window.bounds.height])
                    }
                }
                let result: [String: Any] = ["passed": true, "runID": "PROBE_RUN_ID",
                    "device": UIDevice.current.model, "systemVersion": UIDevice.current.systemVersion,
                    "mapWidth": grass.size.width, "mapHeight": grass.size.height, "captures": captures]
                try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("grass-check.json"), options: .atomic)
            } catch {
                try? JSONSerialization.data(withJSONObject: ["passed": false, "runID": "PROBE_RUN_ID", "error": String(describing: error)])
                    .write(to: directory.appendingPathComponent("grass-check.json"), options: .atomic)
            }
        }
    }
}
