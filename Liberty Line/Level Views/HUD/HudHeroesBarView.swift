import SwiftUI

struct HudHeroesBarView: View {
    private let db: Db
    let heroes: [Hero]
    let buttonSize: CGFloat
    let spacing: CGFloat

    static let slotCount = 5
    static let centerIconName = "hero_ability_icon_old_put"
    
    public init(db: Db, buttonSize: CGFloat) {
        self.db = db
        self.buttonSize = buttonSize
        
        do {
            let allHeroes = try db.heroDao.getAll()
            self.heroes = [
                allHeroes[0],
                allHeroes[1],
                allHeroes[2],
                allHeroes[3]
            ]
            
            spacing = buttonSize / 4.5
        }
        catch {
            fatalError()
        }
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
