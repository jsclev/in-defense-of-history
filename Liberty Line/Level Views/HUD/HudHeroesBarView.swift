import SwiftUI

struct HudHeroesBarView: View {
    private let screenGeometry: ScreenGeometry
    private let db: Db
    private let spacingScaleFactor = 0.0045
    let heroes: [Hero]

    static let slotCount = 5
    static let centerIconName = "hero_ability_icon_old_put"
    
    public init(screenGeometry: ScreenGeometry, db: Db) {
        self.screenGeometry = screenGeometry
        self.db = db
        
        do {
            let allHeroes = try db.heroDao.getAll()
            self.heroes = [
                allHeroes[0],
                allHeroes[1],
                allHeroes[2],
                allHeroes[3],
                allHeroes[4]
            ]
        }
        catch {
            fatalError()
        }
    }

    var body: some View {
        HStack(spacing: screenGeometry.playAreaRect.width * spacingScaleFactor) {
            ForEach(0..<Self.slotCount, id: \.self) { index in
                button(iconName: iconName(index: index))
            }
        }
    }

    private func iconName(index: Int) -> String {
        return heroes[index].iconImageName
    }

    private func button(iconName: String) -> some View {
        HudButtonView(screenGeometry: screenGeometry, iconName: iconName)
    }
}
