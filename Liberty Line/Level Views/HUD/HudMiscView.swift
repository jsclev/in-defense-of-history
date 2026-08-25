import SwiftUI

struct HudMiscView: View {
    private let iconName = "hero_ability_icon_daniel_morgan"
    private let buttonSize: CGFloat
    
    public init(runtimeCanvas: RuntimeCanvas) {
        let width = runtimeCanvas.bottomRightHudRect.width
        let height = runtimeCanvas.bottomRightHudRect.height
        self.buttonSize = min(width, height)
    }

    var body: some View {
        HudButtonView(iconName: iconName, buttonSize: buttonSize) {}
    }
}
