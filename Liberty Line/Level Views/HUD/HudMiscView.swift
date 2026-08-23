import SwiftUI

struct HudMiscView: View {
    private let iconName = "hero_ability_icon_daniel_morgan"
    private let buttonSize: CGFloat
    
    public init(screenGeometry: ScreenGeometry) {
        let width = screenGeometry.bottomRightHudRect.width
        let height = screenGeometry.bottomRightHudRect.height
        self.buttonSize = min(width, height)
    }

    var body: some View {
        HudButtonView(iconName: iconName, buttonSize: buttonSize)
    }
}
