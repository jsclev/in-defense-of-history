import SwiftUI

struct HudHeroesBarView: View {
    let heroes: [Hero]
    let buttonSize: CGSize
    let spacing: CGFloat

    static let slotCount = 5
    static let centerIconName = "hero_ability_icon_old_put"
    
    public init(heroes: [Hero], buttonSize: CGSize) {
        self.heroes = heroes
        self.buttonSize = buttonSize
        
        spacing = buttonSize.width / 4.0
    }

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
        HudButtonView(iconName: iconName, buttonSize: buttonSize) {}
    }
}
