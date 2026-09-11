import SwiftUI
import UIKit

@main struct ReinforcementsProbe: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private let store = Store()
    var body: some Scene { WindowGroup { ReinforcementsProbeScreen(store: store) } }
}

private struct ReinforcementsProbeScreen: View {
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
                    let side = HeroBarLayout(runtimeCanvas: canvas).buttonSize
                    let size = CGSize(width: side, height: side)
                    let views: [(String, AnyView)] = [
                        ("knox-before", AnyView(PreviousHeroHUDButton(iconName: "hero_icon_henry_knox", name: "Knox", buttonSize: side, isAvailable: true, isSelected: false, action: {}))),
                        ("knox-ready", AnyView(HeroHUDButton(iconName: "hero_icon_henry_knox", name: "Knox", buttonSize: side, isAvailable: true, isSelected: false, action: {}))),
                        ("knox-selected", AnyView(HeroHUDButton(iconName: "hero_icon_henry_knox", name: "Knox", buttonSize: side, isAvailable: true, isSelected: true, action: {}))),
                        ("knox-unavailable", AnyView(HeroHUDButton(iconName: "hero_icon_henry_knox", name: "Knox", buttonSize: side, isAvailable: false, isSelected: false, action: {}))),
                        ("before", AnyView(HudButtonView(iconName: "action_icon_call_reinforcements",
                            buttonSize: side, iconScale: HudSizing.paintedButtonIconFraction, frameName: "hud_misc_sack_blue_frame") {})),
                        ("hero", AnyView(HeroHUDButton(iconName: "hero_icon_george_washington", name: "Reference hero", buttonSize: side, isAvailable: true, isSelected: false, action: {}))),
                        ("ready", AnyView(ReinforcementButton(buttonSize: size, cooldown: .ready, isAvailable: true, action: {}))),
                        ("selected", AnyView(ReinforcementButton(buttonSize: size, cooldown: .ready, isAvailable: true, action: {}, isSelected: true))),
                        ("cooldown", AnyView(ReinforcementButton(buttonSize: size,
                            cooldown: ReinforcementCooldown(remainingSeconds: 10, remainingFraction: 0.5), isAvailable: true, action: {})))
                    ]
                    for density in [CGFloat(1), 2, 3] {
                        for (name, view) in views {
                            let renderer = ImageRenderer(content: view.frame(width: side, height: side))
                            renderer.scale = density
                            guard let bytes = renderer.uiImage?.pngData() else { throw NSError(domain: "render", code: 1) }
                            try bytes.write(to: directory.appendingPathComponent("\(name)-\(mode)@\(Int(density))x.png"))
                        }
                        let row = HStack(spacing: HeroBarLayout(runtimeCanvas: canvas).buttonSpacing) {
                            HeroHUDButton(iconName: "hero_icon_george_washington", name: "Washington", buttonSize: side, isAvailable: true, isSelected: false, action: {})
                            HeroHUDButton(iconName: "hero_icon_henry_knox", name: "Knox", buttonSize: side, isAvailable: true, isSelected: false, action: {})
                            ReinforcementButton(buttonSize: size, cooldown: .ready, isAvailable: true, action: {})
                        }.padding(8).background(Color(red: 0.2, green: 0.3, blue: 0.2))
                        let rowRenderer = ImageRenderer(content: row); rowRenderer.scale = density
                        try rowRenderer.uiImage!.pngData()!.write(to: directory.appendingPathComponent("matched-row-\(mode)@\(Int(density))x.png"))
                        let format = UIGraphicsImageRendererFormat(); format.scale = density
                        let bytes = UIGraphicsImageRenderer(size: bounds.size, format: format).pngData { context in
                            context.cgContext.translateBy(x: -bounds.minX, y: -bounds.minY)
                            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                        }
                        try bytes.write(to: directory.appendingPathComponent("hud-\(mode)@\(Int(density))x.png"))
                    }
                    captures.append(["mode": mode, "playableHeight": canvas.playAreaRect.height,
                        "buttonSide": side, "iconSide": side * HudSizing.paintedButtonIconFraction])
                }
                let result: [String: Any] = ["passed": true, "runID": "PROBE_RUN_ID",
                    "captures": captures, "device": UIDevice.current.model,
                    "systemVersion": UIDevice.current.systemVersion]
                try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("reinforcements-check.json"), options: .atomic)
            } catch {
                try? JSONSerialization.data(withJSONObject: ["passed": false, "runID": "PROBE_RUN_ID", "error": String(describing: error)])
                    .write(to: directory.appendingPathComponent("reinforcements-check.json"), options: .atomic)
            }
        }
    }
}

import SwiftUI

struct PreviousHeroHUDButton: View {
    let iconName: String
    let name: String
    let buttonSize: CGFloat
    let isAvailable: Bool
    let isSelected: Bool
    let action: () -> Void

    private var usesPaintedFrame: Bool { iconName == "hero_icon_henry_knox" }
    private var iconFraction: CGFloat { usesPaintedFrame ? 0.64 : 0.75 }

    var body: some View {
        Button(action: action) {
            ZStack {
                if usesPaintedFrame {
                    PaintedHUDButtonFrame(buttonSize: CGSize(width: buttonSize, height: buttonSize))
                } else {
                    Image("tower_menu_square_frame")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                }
                Image(iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize * iconFraction, height: buttonSize * iconFraction)
                    // Hold Knox's lower edge in place as the portrait shrinks,
                    // putting the added space above his hair.
                    .offset(y: usesPaintedFrame ? buttonSize * 0.02 : 0)
                    .grayscale(isAvailable ? 0 : 1)
            }
            .frame(width: buttonSize, height: buttonSize)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: buttonSize * 0.08)
                        .strokeBorder(.white, lineWidth: buttonSize * 0.04)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PreviousHeroHUDButtonStyle())
        .disabled(!isAvailable)
        .accessibilityLabel(name)
        .accessibilityValue(isSelected ? "Selected" : "")
    }
}

private struct PreviousHeroHUDButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label }
}
