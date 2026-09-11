import SwiftUI

struct HudHeroesBarView: View {
    let layout: HeroBarLayout
    @ObservedObject var runner: LevelRunner

    var body: some View {
        let heroes = runner.hudHeroes
        HStack(spacing: layout.buttonSpacing) {
            ForEach(0..<2, id: \.self) { index in
                let hero = heroes.indices.contains(index) ? heroes[index] : nil
                let unitIndex = hero.flatMap { runner.hudHeroIndex(for: $0.id) }
                let role: HeroSelection.Role = index == 0 ? .primary : .secondary
                HeroHUDButton(iconName: hero?.iconImageName ?? "tower_locked_icon",
                              name: hero.map { "\(role.title), \($0.shortName), ranking \($0.ranking)" }
                                ?? "No \(role.title.lowercased()) chosen",
                              buttonSize: layout.buttonSize,
                              isAvailable: unitIndex != nil,
                              isSelected: unitIndex != nil && unitIndex == runner.selectedHeroIndex) {
                    if let hero { runner.selectHero(heroID: hero.id) }
                }
            }
            ReinforcementButton(buttonSize: CGSize(width: layout.buttonSize, height: layout.buttonSize),
                                cooldown: runner.reinforcementCooldown,
                                isAvailable: runner.canCallReinforcements,
                                action: { runner.toggleReinforcementPlacement() },
                                isSelected: runner.isPlacingReinforcements)
        }
        .frame(width: layout.frame.width, height: layout.frame.height)
    }
}
