import SwiftUI
import UIKit

@main struct MasterControlsProbe: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private let store = Store()
    var body: some Scene { WindowGroup { MasterControlsProbeScreen(store: store) } }
}

private struct MasterControlsProbeScreen: View {
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
                    try await Task.sleep(for: .milliseconds(1600))
                    let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                        .flatMap(\.windows).first { $0.isKeyWindow }!
                    let rect = CGRect(x: 0, y: 0, width: 340.0 * 16.0 / 9.0, height: 340)
                    let canvas = RuntimeCanvas(virtualCanvas: store.virtualCanvas,
                        physicalRect: small ? rect : window.bounds,
                        safeInsetsRect: small ? rect : window.bounds.inset(by: window.safeAreaInsets))
                    let bounds = small ? rect : window.bounds
                    let mode = small ? "minimum" : "device"
                    let layout = MasterControlsLayout(runtimeCanvas: canvas)
                    let side = layout.buttonSize
                    let heroSide = HeroBarLayout(runtimeCanvas: canvas).buttonSize
                    let views: [(String, AnyView)] = [
                        ("speed", AnyView(PaintedMasterControlButton(iconName: "hud_speed_up_framed", label: "Speed up", buttonSize: side, action: {}))),
                        ("home", AnyView(PaintedMasterControlButton(iconName: "hud_back_to_main_framed", label: "Back to main", buttonSize: side, action: {}))),
                        ("speed-before", AnyView(HudButtonView(iconName: "speed_up_icon_glyph", buttonSize: side, iconScale: HudSizing.masterControlIconFraction, action: {}))),
                        ("home-before", AnyView(HudButtonView(iconName: "pause_icon_glyph", buttonSize: side, iconScale: HudSizing.masterControlIconFraction, action: {})))
                    ]
                    for density in [CGFloat(1), 2, 3] {
                        for (name, view) in views {
                            try save(view.frame(width: side, height: side), name: "\(name)-\(mode)", density: density, directory: directory)
                        }
                        let row = HudMasterControlsView(runtimeCanvas: canvas, onSpeedUp: {}, onExit: {})
                        try save(row, name: "controls-\(mode)", density: density, directory: directory)
                        let neighbors = HStack(spacing: 8) {
                            row
                            HeroHUDButton(iconName: "hero_icon_george_washington", name: "Washington", buttonSize: heroSide, isAvailable: true, isSelected: false, action: {})
                            HeroHUDButton(iconName: "hero_icon_henry_knox", name: "Knox", buttonSize: heroSide, isAvailable: true, isSelected: false, action: {})
                            ReinforcementButton(buttonSize: CGSize(width: heroSide, height: heroSide), cooldown: .ready, isAvailable: true, action: {})
                        }.padding(10).background(Color(red: 0.15, green: 0.23, blue: 0.19))
                        try save(neighbors, name: "neighbors-\(mode)", density: density, directory: directory)
                        let format = UIGraphicsImageRendererFormat(); format.scale = density
                        let bytes = UIGraphicsImageRenderer(size: bounds.size, format: format).pngData { context in
                            context.cgContext.translateBy(x: -bounds.minX, y: -bounds.minY)
                            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                        }
                        try bytes.write(to: directory.appendingPathComponent("hud-\(mode)@\(Int(density))x.png"))
                    }
                    captures.append(["mode": mode, "playableHeight": canvas.playAreaRect.height,
                        "buttonSide": side, "buttonSpacing": layout.buttonSpacing,
                        "controlsFrame": [layout.frame.minX, layout.frame.minY, layout.frame.width, layout.frame.height],
                        "heroButtonSide": heroSide])
                }
                let result: [String: Any] = ["passed": true, "runID": "PROBE_RUN_ID",
                    "captures": captures, "device": UIDevice.current.model,
                    "systemVersion": UIDevice.current.systemVersion]
                try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("hud-check.json"), options: .atomic)
            } catch {
                try? JSONSerialization.data(withJSONObject: ["passed": false, "runID": "PROBE_RUN_ID", "error": String(describing: error)])
                    .write(to: directory.appendingPathComponent("hud-check.json"), options: .atomic)
            }
        }
    }

    @MainActor private func save<V: View>(_ view: V, name: String, density: CGFloat, directory: URL) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = density
        guard let bytes = renderer.uiImage?.pngData() else { throw NSError(domain: "render", code: 1) }
        try bytes.write(to: directory.appendingPathComponent("\(name)@\(Int(density))x.png"))
    }
}
