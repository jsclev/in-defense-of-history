import SwiftUI

@available(iOS 26.0, *)
struct HudMasterControlsView: View {
    private let layout: MasterControlsLayout
    private let onSpeedUp: () -> Void
    private let onExit: () -> Void

    public init(runtimeCanvas: RuntimeCanvas,
                onSpeedUp: @escaping () -> Void,
                onExit: @escaping () -> Void) {
        self.onSpeedUp = onSpeedUp
        self.onExit = onExit
        self.layout = MasterControlsLayout(runtimeCanvas: runtimeCanvas)
    }

    var body: some View {
        HStack(spacing: layout.buttonSpacing) {
            HudButtonView(iconName: "speed_up_icon_glyph", buttonSize: layout.buttonSize,
                          iconScale: HudSizing.masterControlIconFraction,
                          action: onSpeedUp)
            HudButtonView(iconName: "pause_icon_glyph", buttonSize: layout.buttonSize,
                          iconScale: HudSizing.masterControlIconFraction,
                          action: onExit)
        }
        .frame(width: layout.frame.width, height: layout.frame.height)
    }
}
