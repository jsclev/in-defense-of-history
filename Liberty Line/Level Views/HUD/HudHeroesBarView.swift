import SwiftUI

struct HudHeroesBarView: View {
    private let numHeroes = 3
    private let heroes: [Hero]
    private let buttonSize: CGFloat
    private let buttonSpacing: CGFloat
    
    public init(runtimeCanvas: RuntimeCanvas, db: Db) {
        let buttonSections = CGFloat(numHeroes) + ((CGFloat(numHeroes) - 1.0) * 0.1)
        buttonSize = runtimeCanvas.bottomLeftHudRect.size.width / buttonSections
        buttonSpacing = buttonSize * 0.1

        do {
            let allHeroes = try db.heroDao.getAll()
            self.heroes = Array(allHeroes.prefix(upTo: numHeroes))
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
