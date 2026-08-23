import SwiftUI

struct HudMiscView: View {
    private let screenGeometry: ScreenGeometry
    private let iconName = "hero_ability_icon_daniel_morgan"
    
    public init(screenGeometry: ScreenGeometry) {
        self.screenGeometry = screenGeometry
    }

    var body: some View {
        HudButtonView(screenGeometry: screenGeometry, iconName: iconName)
    }
}
