import SwiftUI

struct HudHeroesBarView: View {
    private let heroes: [Hero]
    private let buttonSize: CGFloat
    private let buttonSpacing: CGFloat
    
    public init(screenGeometry: ScreenGeometry, db: Db) {
        buttonSize = screenGeometry.bottomLeftHudRect.size.width / (5.0 + 4.0 * 0.1)
        buttonSpacing = buttonSize * 0.1
//        self.buttonSize = (screenGeometry.bottomLeftHudRect.width / 5.0) * 0.90
//        self.buttonSpacing = (screenGeometry.bottomLeftHudRect.width  / 5.0) * 0.10

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
        HStack(spacing: buttonSpacing) {
            ForEach(0..<heroes.count, id: \.self) { index in
                ZStack {
                    Image("tower_menu_square_frame")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: buttonSize, height: buttonSize)
                    Image(heroes[index].iconImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: buttonSize * 0.75, height: buttonSize * 0.75)
                }
            }
        }
        .clipped()
    }
}
