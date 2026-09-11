import SwiftUI

@available(iOS 26.0, *)
struct SettingsView: View {
    @AppStorage("debugMode") private var debugMode = true
    @AppStorage("showDebugInfo") private var showDebugInfo = false
    @AppStorage(Constants.showDebugLayoutGuidesKey) private var showDebugLayoutGuides = false
    @AppStorage(Constants.enemyEscapeHapticsEnabledKey) private var enemyEscapeHapticsEnabled = true

    private let runtimeCanvas: RuntimeCanvas
    private let onConfigureHudLayout: () -> Void
    private let onExit: () -> Void
    private let metrics: HudMetrics
    private let contentInsets: EdgeInsets
    private let doneButtonHeight: CGFloat

    init(runtimeCanvas: RuntimeCanvas,
         onConfigureHudLayout: @escaping () -> Void,
         onExit: @escaping () -> Void) {
        self.runtimeCanvas = runtimeCanvas
        self.onConfigureHudLayout = onConfigureHudLayout
        self.onExit = onExit
        let metrics = HudMetrics(runtimeCanvas: runtimeCanvas)
        self.metrics = metrics
        let padding = 28 * metrics.scale
        let safe = runtimeCanvas.safeInsetsRect
        let physical = runtimeCanvas.physicalRect
        contentInsets = EdgeInsets(top: safe.minY - physical.minY + padding,
                                   leading: safe.minX - physical.minX + padding,
                                   bottom: physical.maxY - safe.maxY + padding,
                                   trailing: physical.maxX - safe.maxX + padding)
        doneButtonHeight = HudSizing.doneButton.resolved(at: metrics.scale)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18 * metrics.scale) {
            Text("Settings")
                .font(.custom("Baskerville-Bold", size: 40 * metrics.scale))
                .foregroundStyle(.white)

            ScrollView {
                VStack(alignment: .leading, spacing: 18 * metrics.scale) {
                    toggle("Life-loss haptics",
                           detail: "Feel feedback when an enemy escapes and you lose a life.",
                           isOn: $enemyEscapeHapticsEnabled)

                    options
                }
                .frame(width: runtimeCanvas.safeInsetsRect.width - 56 * metrics.scale,
                       alignment: .leading)
            }

            Text("Version \(GameIdentity.version)")
                .font(.system(size: Typography.size(12 * metrics.scale)))
                .foregroundStyle(.white.opacity(0.5))

            Color.clear.frame(height: doneButtonHeight)
        }
        .padding(contentInsets)
        .frame(width: runtimeCanvas.physicalRect.width, height: runtimeCanvas.physicalRect.height)
        .background {
            ZStack {
                Image("hero_screen_background")
                    .resizable()
                    .scaledToFill()
                Color.black.opacity(0.45)
            }
            .clipped()
            .ignoresSafeArea()
        }
        .overlay(alignment: .topLeading) {
            DoneButton(runtimeCanvas: runtimeCanvas, action: onExit)
        }
        .persistentSystemOverlays(.hidden)
    }

    @ViewBuilder
    private var options: some View {
        toggle("Debug mode",
               detail: "Firing range ring under each tower you place, "
                     + "coloured and labelled by range.",
               isOn: $debugMode)

        toggle("Layout guides",
               detail: "Screen edge in red, safe area in green, HUD in yellow, play area in purple, tap area in cyan.",
               isOn: $showDebugLayoutGuides)

        toggle("Simulation readout",
               detail: "Wave and spawn state, top-left of the level map.",
               isOn: $showDebugInfo)

        Button(action: onConfigureHudLayout) {
            VStack(alignment: .leading, spacing: 3 * metrics.scale) {
                Text("HUD layout")
                    .font(.custom("Baskerville-SemiBold", size: 22 * metrics.scale))
                    .foregroundStyle(Color(red: 0.87, green: 0.72, blue: 0.35))
                Text("Drag the hero bar, stats, misc button, and master controls "
                     + "to any edge or corner of the screen.")
                    .font(.system(size: Typography.size(13 * metrics.scale)))
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func toggle(_ title: String, detail: String,
                        isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 3 * metrics.scale) {
                Text(title)
                    .font(.custom("Baskerville-SemiBold", size: 22 * metrics.scale))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: Typography.size(13 * metrics.scale)))
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .tint(Color(red: 0.87, green: 0.72, blue: 0.35))
    }
}
