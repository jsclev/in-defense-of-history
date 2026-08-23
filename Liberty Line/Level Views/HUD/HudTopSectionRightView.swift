import SwiftUI

@available(iOS 26.0, *)
struct HudTopSectionRightView: View {
    private let buttonSize: CGFloat
    private let buttonSpacing: CGFloat

    public init(screenGeometry: ScreenGeometry) {
        let width = screenGeometry.topRightHudRect.width
        let height = screenGeometry.topRightHudRect.height
        let minDimension = max(width, height)
        
        self.buttonSize = (minDimension / 2.0) * 0.90
        self.buttonSpacing = (minDimension / 2.0) * 0.10
    }

    var body: some View {
        HStack(spacing: buttonSpacing) {
            HudButtonView(iconName: "speed_up_icon_glyph", buttonSize: buttonSize)
            HudButtonView(iconName: "pause_icon_glyph", buttonSize: buttonSize)
        }
    }
}
