import SwiftUI

struct LevelMiscView: View {
    let buttonSize: CGSize

    static let iconName = "hero_ability_icon_daniel_morgan"

    var body: some View {
        HudButtonView(iconName: Self.iconName, buttonSize: buttonSize) {}
    }
}
