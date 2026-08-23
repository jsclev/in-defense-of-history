import SwiftUI

@available(iOS 26.0, *)
struct SettingsView: View {
    @AppStorage("debugMode") private var debugMode = true
    @AppStorage("showDebugInfo") private var showDebugInfo = false
    @AppStorage(Constants.showDebugLayoutGuidesKey) private var showDebugLayoutGuides = false

    private let screen: ScreenGeometry
    private let onExit: () -> Void
    private let metrics: HudMetrics
    private let contentInsets: EdgeInsets
    private let doneButtonHeight: CGFloat

    init(screen: ScreenGeometry, onExit: @escaping () -> Void) {
        self.screen = screen
        self.onExit = onExit
        let metrics = HudMetrics(screen: screen)
        self.metrics = metrics
        let padding = 28 * metrics.scale
        let safe = screen.safeInsetsRect
        let physical = screen.physicalRect
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

            toggle("Debug mode",
                   detail: "Firing range ring under each tower you place, "
                         + "coloured and labelled by range.",
                   isOn: $debugMode)

            toggle("Layout guides",
                   detail: "Physical screen edge in green, safe area in red, play area in orange.",
                   isOn: $showDebugLayoutGuides)

            toggle("Simulation readout",
                   detail: "Wave and spawn state, top-left of the level map.",
                   isOn: $showDebugInfo)

            Spacer()

            Text("Version \(GameIdentity.version)")
                .font(.system(size: Typography.size(12 * metrics.scale)))
                .foregroundStyle(.white.opacity(0.5))

            HStack {
                Spacer()
                DoneButton(action: onExit)
                    .frame(height: doneButtonHeight)
            }
        }
        .padding(contentInsets)
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
        .persistentSystemOverlays(.hidden)
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
