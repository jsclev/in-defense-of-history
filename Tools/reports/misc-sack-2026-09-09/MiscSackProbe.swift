import SwiftUI
import UIKit

@main struct MiscSackProbe: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private let store = Store()
    var body: some Scene { WindowGroup { MiscSackProbeScreen(store: store) } }
}

private struct MiscSackProbeScreen: View {
    let store: Store
    @State private var minimum = false
    var body: some View {
        ScreenGeometryGate(virtualCanvas: store.virtualCanvas) { deviceCanvas in
            let rect = CGRect(x: 0, y: 0, width: 340.0 * 16.0 / 9.0, height: 340)
            let canvas = minimum ? RuntimeCanvas(virtualCanvas: store.virtualCanvas,
                physicalRect: rect, safeInsetsRect: rect) : deviceCanvas
            let node = CampaignNode.load(db: store.db).first { $0.mapImageName == "level_15_charleston" }!
            LevelMapView(db: store.db, virtualCanvas: store.virtualCanvas, runtimeCanvas: canvas,
                towerMenuLayout: store.towerMenuLayout, node: node,
                difficulty: try! store.db.difficultyDao.getAll()[0],
                hudLayoutConfig: try! store.db.hudLayoutDao.get(), onExit: {})
                .id(minimum)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .task {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            do {
                UserDefaults.standard.set(false, forKey: Constants.debugModeKey)
                guard let image = UIImage(named: "hud_misc_sack"),
                    image.size == CGSize(width: 128, height: 128),
                    UIImage(named: "hero_ability_icon_daniel_morgan") != nil,
                    try store.db.hudLayoutDao.get().miscView == .southEast else {
                    throw NSError(domain: "MiscSackProbe", code: 1)
                }
                var captures: [[String: Any]] = []
                for small in [false, true] {
                    minimum = small
                    try await Task.sleep(for: .milliseconds(1600))
                    let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                        .flatMap(\.windows).first { $0.isKeyWindow }!
                    let fixture = CGRect(x: 0, y: 0, width: 340.0 * 16.0 / 9.0, height: 340)
                    let canvas = RuntimeCanvas(virtualCanvas: store.virtualCanvas,
                        physicalRect: small ? fixture : window.bounds,
                        safeInsetsRect: small ? fixture : window.bounds.inset(by: window.safeAreaInsets))
                    let buttonSize = min(canvas.miscViewSize.width, canvas.miscViewSize.height)
                    if small && abs(buttonSize - 54.4) > 0.01 { throw NSError(domain: "MiscSackProbe", code: 3) }
                    for density in [CGFloat(1), 2, 3] {
                        let format = UIGraphicsImageRendererFormat(); format.scale = density
                        let bounds = small ? CGRect(x: 0, y: 0, width: 340.0 * 16.0 / 9.0, height: 340) : window.bounds
                        let data = UIGraphicsImageRenderer(bounds: bounds, format: format).pngData { _ in
                            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                        }
                        let state = small ? "minimum" : "device"
                        let file = "charleston-\(state)@\(Int(density))x.png"
                        try data.write(to: directory.appendingPathComponent(file))
                        let renderer = ImageRenderer(content: HudMiscView(runtimeCanvas: canvas)
                            .frame(width: buttonSize, height: buttonSize))
                        renderer.scale = density
                        guard let iconBytes = renderer.uiImage?.pngData() else { throw NSError(domain: "MiscSackProbe", code: 4) }
                        try iconBytes.write(to: directory.appendingPathComponent("misc-button-\(state)@\(Int(density))x.png"))
                        captures.append(["file": file, "widthPoints": bounds.width, "heightPoints": bounds.height,
                            "density": density, "playableHeight": canvas.playAreaRect.height,
                            "buttonSizePoints": buttonSize, "artworkBoxPoints": buttonSize * 0.8,
                            "buttonFrame": [canvas.hudRect.maxX-buttonSize, canvas.hudRect.maxY-buttonSize, buttonSize, buttonSize]])
                    }
                }
                let result: [String: Any] = ["passed": true, "runID": "PROBE_RUN_ID",
                    "device": UIDevice.current.model, "systemVersion": UIDevice.current.systemVersion,
                    "miscLocation": "south_east", "assetLogicalSize": [image.size.width, image.size.height], "captures": captures]
                try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("misc-check.json"), options: .atomic)
            } catch {
                try? JSONSerialization.data(withJSONObject: ["passed": false, "runID": "PROBE_RUN_ID", "error": String(describing: error)])
                    .write(to: directory.appendingPathComponent("misc-check.json"), options: .atomic)
            }
        }
    }
}
