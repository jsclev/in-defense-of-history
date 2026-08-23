import SwiftUI

@available(iOS 26.0, *)
struct HudTopSectionRightView: View {
    private let screenGeometry: ScreenGeometry
    private let spacingScaleFactor = 0.0045

    public init(screenGeometry: ScreenGeometry) {
        self.screenGeometry = screenGeometry
    }

    var body: some View {
        HStack(spacing: screenGeometry.playAreaRect.width * spacingScaleFactor) {
            HudButtonView(screenGeometry: screenGeometry,
                          iconName: "speed_up_icon_glyph")
            HudButtonView(screenGeometry: screenGeometry,
                          iconName: "pause_icon_glyph")
        }
    }
}
