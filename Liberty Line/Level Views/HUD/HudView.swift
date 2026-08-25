import SwiftUI

@available(iOS 26.0, *)
struct HudView: View {
    private let db: Db
    private let runtimeCanvas: RuntimeCanvas
    private let runner: LevelRunner
    private let onSpeedUp: () -> Void
    private let onExit: () -> Void
    private let buttonSize = 50.0
    private let iconSize: CGFloat
    
    @AppStorage(Constants.debugModeKey) private var debugMode = false
    
    public init(runtimeCanvas: RuntimeCanvas, db: Db, runner: LevelRunner,
                towerMenuLayout: TowerMenuLayout,
                onSpeedUp: @escaping () -> Void,
                onExit: @escaping () -> Void) {
        self.db = db
        self.runtimeCanvas = runtimeCanvas
        self.runner = runner
        self.onSpeedUp = onSpeedUp
        self.onExit = onExit
        print("HUD rect minX: \(runtimeCanvas.hudRect.minX)")
        iconSize = towerMenuLayout.getTowerIconSize(towerButtonSize: buttonSize)
    }

    var body: some View {
        VStack {
            HudTopSectionView(runtimeCanvas: runtimeCanvas,
                              runner: runner,
                              onSpeedUp: onSpeedUp,
                              onExit: onExit)
                .border(debugMode ? Color.black : Color.clear, width: debugMode ? 5 : 0)
            Spacer()
            HudBottomSectionView(runtimeCanvas: runtimeCanvas, db: db)
                .clipped()
        }
        .padding(.top, runtimeCanvas.hudTopMargin)
        .padding(.horizontal, runtimeCanvas.hudHorizontalMargin)
        .padding(.bottom, runtimeCanvas.hudBottomMargin)
    }
}
