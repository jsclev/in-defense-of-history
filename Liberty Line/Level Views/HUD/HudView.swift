import SwiftUI

@available(iOS 26.0, *)
struct HudView: View {
    private let db: Db
    private let screen: ScreenGeometry
    private let runner: LevelRunner
    private let onSpeedUp: () -> Void
    private let onExit: () -> Void
    private let buttonSize = 50.0
    private let iconSize: CGFloat
    
    public init(db: Db, screen: ScreenGeometry, runner: LevelRunner,
                towerMenuLayout: TowerMenuLayout,
                onSpeedUp: @escaping () -> Void,
                onExit: @escaping () -> Void) {
        self.db = db
        self.screen = screen
        self.runner = runner
        self.onSpeedUp = onSpeedUp
        self.onExit = onExit
        iconSize = towerMenuLayout.getTowerIconSize(towerButtonSize: buttonSize)
    }

    var body: some View {
        VStack {
            HudTopSectionView(screen: screen,
                              runner: runner,
                              buttonSize: buttonSize,
                              onSpeedUp: onSpeedUp,
                              onExit: onExit)
            Spacer()
            HudBottomSectionView(db: db, screen: screen, buttonSize: buttonSize)
        }
    }
}
