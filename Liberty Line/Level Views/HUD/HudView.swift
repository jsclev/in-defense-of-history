import SwiftUI

@available(iOS 26.0, *)
struct HudView: View {
    private let db: Db
    private let screen: ScreenGeometry
    private let runner: LevelRunner
    private let onSpeedUp: () -> Void
    private let onExit: () -> Void
    
    public init(db: Db, screen: ScreenGeometry, runner: LevelRunner,
                onSpeedUp: @escaping () -> Void,
                onExit: @escaping () -> Void) {
        self.db = db
        self.screen = screen
        self.runner = runner
        self.onSpeedUp = onSpeedUp
        self.onExit = onExit
    }

    var body: some View {
        VStack {
            HudTopSectionView(screen: screen, runner: runner,
                              onSpeedUp: onSpeedUp, onExit: onExit)
            Spacer()
            HudBottomSectionView(db: db, screen: screen)
        }
    }
}
