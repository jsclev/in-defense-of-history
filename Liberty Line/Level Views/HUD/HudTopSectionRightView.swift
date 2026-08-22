import SwiftUI

@available(iOS 26.0, *)
struct HudTopSectionRightView: View {
    private let screen: ScreenGeometry
    private let buttonSize: CGFloat
    private let onSpeedUp: () -> Void
    private let onExit: () -> Void

    public init(screen: ScreenGeometry,
                buttonSize: CGFloat,
                onSpeedUp: @escaping () -> Void,
                onExit: @escaping () -> Void) {
        self.screen = screen
        self.buttonSize = buttonSize
        self.onSpeedUp = onSpeedUp
        self.onExit = onExit
    }

    var body: some View {
        HStack(spacing: buttonSize / 4.0) {
            HudButtonView(iconName: "speed_up_icon_glyph",
                          buttonSize: buttonSize,
                          action: onSpeedUp)
            HudButtonView(iconName: "pause_icon_glyph",
                          buttonSize: buttonSize,
                          action: onExit)
        }
    }
}
