import SwiftUI

@available(iOS 26.0, *)
struct HudView: View {
    private let db: Db
    private let screenGeometry: ScreenGeometry
    private let runner: LevelRunner
    private let buttonSize = 50.0
    private let iconSize: CGFloat
    
    public init(screenGeometry: ScreenGeometry, db: Db, runner: LevelRunner,
                towerMenuLayout: TowerMenuLayout) {
        self.db = db
        self.screenGeometry = screenGeometry
        self.runner = runner
        iconSize = towerMenuLayout.getTowerIconSize(towerButtonSize: buttonSize)
    }

    var body: some View {
        VStack {
            HudTopSectionView(screenGeometry: screenGeometry, runner: runner).border(Color.black)
            Spacer().border(Color.pink)
            HudBottomSectionView(screenGeometry: screenGeometry, db: db).border(Color.yellow)
        }
    }
}
