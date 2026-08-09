import SwiftUI

@available(iOS 26.0, *)
struct SettingsView: View {
    let onExit: () -> Void

    @AppStorage("debugMode") private var debugMode = true
    @AppStorage("showDebugInfo") private var showDebugInfo = false
    @AppStorage(SafeAreaOverlay.defaultsKey) private var showSafeAreaOverlay = false

    var body: some View {
        GeometryReader { geometry in
            let metrics = HudMetrics(viewSize: geometry.size)
            ZStack(alignment: .topLeading) {
                Image("hero_screen_background")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea()

                Color.black.opacity(0.45).ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18 * metrics.scale) {
                    Text("Settings")
                        .font(.custom("Baskerville-Bold", size: 40 * metrics.scale))
                        .foregroundStyle(.white)

                    toggle("Debug mode",
                           detail: "Firing range ring under each tower you place, "
                                 + "coloured and labelled by range.",
                           isOn: $debugMode, metrics: metrics)

                    toggle("Layout guides",
                           detail: "Physical screen edge in green, safe area in red, playable rect in orange.",
                           isOn: $showSafeAreaOverlay, metrics: metrics)

                    toggle("Simulation readout",
                           detail: "Wave and spawn state, top-left of the level map.",
                           isOn: $showDebugInfo, metrics: metrics)

                    Spacer()
                }
                .padding(28 * metrics.scale)
                .frame(maxWidth: 620 * metrics.scale, alignment: .leading)

                DoneButton(action: onExit)
                    .hudFrame(DoneButtonLayout(screen: ScreenGeometry(proxy: geometry),
                                               aspect: DoneButton.aspect).frame,
                              in: ScreenGeometry(proxy: geometry))
                    .ignoresSafeArea()
            }
        }
        .persistentSystemOverlays(.hidden)
    }

    private func toggle(_ title: String, detail: String,
                        isOn: Binding<Bool>, metrics: HudMetrics) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 3 * metrics.scale) {
                Text(title)
                    .font(.custom("Baskerville-SemiBold", size: 22 * metrics.scale))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 13 * metrics.scale))
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .tint(Color(red: 0.87, green: 0.72, blue: 0.35))
    }
}
