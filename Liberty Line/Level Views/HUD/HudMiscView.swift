import SwiftUI

struct HudMiscView: View {
    private let iconName = "hero_ability_icon_daniel_morgan"
    private let screenGeometry: ScreenGeometry
    
    public init(screenGeometry: ScreenGeometry) {
        self.screenGeometry = screenGeometry
    }

    var body: some View {
        HudButtonView(iconName: iconName, buttonSize: 50.0)
    }
}
