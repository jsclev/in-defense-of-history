import SwiftUI

struct HudMiscView: View {
    private let iconName = "hero_ability_icon_daniel_morgan"

    let buttonSize: CGFloat

    var body: some View {
        HudButtonView(iconName: iconName, buttonSize: buttonSize) {}
    }
}
