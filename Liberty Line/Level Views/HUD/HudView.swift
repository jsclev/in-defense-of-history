import SwiftUI

@available(iOS 26.0, *)
struct HudView: View {
    private let db: Db
    private let screenGeometry: ScreenGeometry
    private let runner: LevelRunner
    private let buttonSize = 50.0
    private let iconSize: CGFloat
    
    @AppStorage(Constants.debugModeKey) private var debugMode = false
    
    public init(screenGeometry: ScreenGeometry, db: Db, runner: LevelRunner,
                towerMenuLayout: TowerMenuLayout) {
        self.db = db
        self.screenGeometry = screenGeometry
        self.runner = runner
        print("HUD rect minX: \(screenGeometry.hudRect.minX)")
        iconSize = towerMenuLayout.getTowerIconSize(towerButtonSize: buttonSize)
    }

    var body: some View {
        VStack {
            HudTopSectionView(screenGeometry: screenGeometry, runner: runner)
                .border(debugMode ? Color.black : Color.clear, width: debugMode ? 5 : 0)
            Spacer()
//                .border(Color.pink)
            HudBottomSectionView(screenGeometry: screenGeometry, db: db)
                .clipped()
//                .border(Color.yellow)
        }
        .padding(.top, screenGeometry.hudTopMargin)
        .padding(.horizontal, screenGeometry.hudHorizontalMargin)
        .padding(.bottom, screenGeometry.hudBottomMargin)
    }
}
