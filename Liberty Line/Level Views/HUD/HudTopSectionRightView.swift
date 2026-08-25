import SwiftUI

@available(iOS 26.0, *)
struct HudTopSectionRightView: View {
    private let buttonSize: CGFloat
    private let buttonSpacing: CGFloat
    private let onSpeedUp: () -> Void
    private let onExit: () -> Void

    public init(runtimeCanvas: RuntimeCanvas,
                onSpeedUp: @escaping () -> Void,
                onExit: @escaping () -> Void) {
        self.onSpeedUp = onSpeedUp
        self.onExit = onExit
        let width = runtimeCanvas.topRightHudRect.width
        let height = runtimeCanvas.topRightHudRect.height
        let minDimension = max(width, height)
        
        self.buttonSize = (minDimension / 2.0) * 0.90
        self.buttonSpacing = (minDimension / 2.0) * 0.10
    }

    var body: some View {
        HStack(spacing: buttonSpacing) {
            HudButtonView(iconName: "speed_up_icon_glyph", buttonSize: buttonSize,
                          action: onSpeedUp)
            HudButtonView(iconName: "pause_icon_glyph", buttonSize: buttonSize,
                          action: onExit)
        }
    }
}
