import SwiftUI

struct HudMiscView: View {
    let buttonSize: CGSize

    private let iconName = "hero_ability_icon_daniel_morgan"

    var body: some View {
        HudButtonView(iconName: iconName, buttonSize: buttonSize) {}
    }
}
