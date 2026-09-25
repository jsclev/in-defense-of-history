import SwiftUI

struct HudHeroesBarView: View {
    let layout: HeroBarLayout
    let state: LevelHUDState
    let onAction: (LevelHUDControl) -> Void

    var body: some View {
        let heroes = state.heroes
        HStack(spacing: layout.buttonSpacing) {
            ForEach(0..<2, id: \.self) { index in
                let hero = heroes.indices.contains(index) ? heroes[index] : nil
                let role: HeroSelection.Role = index == 0 ? .primary : .secondary
                let control: LevelHUDControl = index == 0 ? .primaryHero : .secondaryHero
                HeroHUDButton(iconName: hero?.portrait,
                              name: hero?.label ?? "No \(role.title.lowercased()) chosen",
                              buttonSize: layout.buttonSize,
                              isAvailable: hero?.isAvailable == true,
                              isSelected: hero?.isSelected == true,
                              isActivated: state.isActivated(control)) {
                    onAction(control)
                }
                .accessibilityIdentifier("hero-hud-\(index)")
            }
            ReinforcementButton(buttonSize: CGSize(width: layout.buttonSize, height: layout.buttonSize),
                                cooldown: state.reinforcementCooldown,
                                isAvailable: state.canCallReinforcements,
                                action: { onAction(.reinforcements) },
                                isSelected: state.isPlacingReinforcements,
                                isActivated: state.isActivated(.reinforcements))
        }
        .frame(width: layout.frame.width, height: layout.frame.height)
    }
}
