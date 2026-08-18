import SwiftUI

struct LevelHeroBarView: View {
    let towerMenuLayout: TowerMenuLayout
    let heroes: [Hero]
    let buttonSize: CGSize
    let spacing: CGFloat

    static let slotCount = 5
    static let centerIconName = "hero_ability_icon_old_put"

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<Self.slotCount, id: \.self) { slot in
                button(iconName: iconName(slot: slot))
            }
        }
    }

    private func iconName(slot: Int) -> String? {
        switch slot {
        case 0, 1: heroes.indices.contains(slot) ? heroes[slot].iconImageName : nil
        case 2: Self.centerIconName
        default: heroes.indices.contains(slot - 3) ? heroes[slot - 3].abilityIconImageName : nil
        }
    }

    private func button(iconName: String?) -> some View {
        HudFrameButton(towerMenuLayout: towerMenuLayout, iconName: iconName, buttonSize: buttonSize) {}
    }
}

struct HudFrameButton: View {
    let towerMenuLayout: TowerMenuLayout
    let iconName: String?
    let buttonSize: CGSize
    let action: () -> Void

    var body: some View {
        let side = buttonSize.width
        let iconSide = towerMenuLayout.getTowerIconSize(towerButtonSize: side)
        Button(action: action) {
            ZStack {
                Image("tower_menu_square_frame")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: side, height: side)
                if let iconName {
                    Image(iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconSide, height: iconSide)
                }
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(iconName == nil)
    }
}

struct LevelMiscView: View {
    let towerMenuLayout: TowerMenuLayout
    let buttonSize: CGSize

    static let iconName = "hero_ability_icon_daniel_morgan"

    var body: some View {
        HudFrameButton(towerMenuLayout: towerMenuLayout, iconName: Self.iconName, buttonSize: buttonSize) {}
    }
}
