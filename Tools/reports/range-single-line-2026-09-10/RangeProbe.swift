import SwiftUI
import UIKit

@main struct RangeProbe: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private let store = Store()
    var body: some Scene { WindowGroup { RangeProbeScreen(store: store) } }
}

private struct RangeProbeScreen: View {
    let store: Store
    @State private var mode = "current"
    @State private var minimum = false

    var body: some View {
        ScreenGeometryGate(virtualCanvas: store.virtualCanvas) { deviceCanvas in
            let rect = CGRect(x: 0, y: 0, width: 340 * 16 / 9, height: 340)
            let canvas = minimum ? RuntimeCanvas(virtualCanvas: store.virtualCanvas,
                physicalRect: rect, safeInsetsRect: rect) : deviceCanvas
            let node = CampaignNode.load(db: store.db).first { $0.mapImageName == "level_01_battle_road" }!
            ZStack(alignment: .topLeading) {
                LevelMapView(db: store.db, virtualCanvas: store.virtualCanvas, runtimeCanvas: canvas,
                    towerMenuLayout: store.towerMenuLayout, node: node,
                    difficulty: try! store.db.difficultyDao.getAll()[0],
                    hudLayoutConfig: .standard, onExit: {})
                    .id(minimum)
                let center = CGPoint(x: canvas.playAreaRect.minX + canvas.playAreaRect.width * 0.26,
                                     y: canvas.playAreaRect.minY + canvas.playAreaRect.height * 0.45)
                if mode == "before" {
                    BeforeTowerRangeOverlayView(center: center, range: 319.08, runtimeCanvas: canvas)
                } else if mode != "clear" {
                    TowerRangeOverlayView(center: center, range: 319.08,
                        upgradeRange: mode == "upgrade" ? 364.67 : nil, runtimeCanvas: canvas)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .task {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            do {
                UserDefaults.standard.set(false, forKey: Constants.debugModeKey)
                var captures: [[String: Any]] = []
                for small in [false, true] {
                    minimum = small
                    for variant in ["clear", "before", "current", "upgrade"] {
                        mode = variant
                        try await Task.sleep(for: .milliseconds(1200))
                        let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                            .flatMap(\.windows).first { $0.isKeyWindow }!
                        for density in [CGFloat(1), 2, 3] {
                            let format = UIGraphicsImageRendererFormat()
                            format.scale = density
                            let bounds = small ? CGRect(x: 0, y: 0, width: 340 * 16 / 9, height: 340) : window.bounds
                            let data = UIGraphicsImageRenderer(bounds: bounds, format: format).pngData { _ in
                                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                            }
                            let name = "range-\(variant)-\(small ? "minimum" : "device")@\(Int(density))x.png"
                            try data.write(to: directory.appendingPathComponent(name))
                            captures.append(["file": name, "widthPoints": bounds.width, "heightPoints": bounds.height,
                                "density": density, "windowWidthPoints": window.bounds.width, "windowHeightPoints": window.bounds.height])
                        }
                    }
                }
                let result: [String: Any] = ["passed": true, "runID": "PROBE_RUN_ID",
                    "device": UIDevice.current.model, "systemVersion": UIDevice.current.systemVersion,
                    "captures": captures]
                try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("range-check.json"), options: .atomic)
            } catch {
                try? JSONSerialization.data(withJSONObject: ["passed": false, "runID": "PROBE_RUN_ID", "error": String(describing: error)])
                    .write(to: directory.appendingPathComponent("range-check.json"), options: .atomic)
            }
        }
    }
}
