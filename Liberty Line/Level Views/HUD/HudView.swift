import SwiftUI

@available(iOS 26.0, *)
struct HudView: View {
    private let db: Db
    private let runtimeCanvas: RuntimeCanvas
    private let runner: LevelRunner
    private let hudLayoutConfig: HudLayoutConfig
    private let onSpeedUp: () -> Void
    private let onExit: () -> Void

    @AppStorage(Constants.debugModeKey) private var debugMode = false

    public init(runtimeCanvas: RuntimeCanvas, db: Db, runner: LevelRunner,
                hudLayoutConfig: HudLayoutConfig,
                onSpeedUp: @escaping () -> Void,
                onExit: @escaping () -> Void) {
        self.db = db
        self.runtimeCanvas = runtimeCanvas
        self.runner = runner
        self.hudLayoutConfig = hudLayoutConfig
        self.onSpeedUp = onSpeedUp
        self.onExit = onExit
    }

    var body: some View {
        VStack {
            HStack(alignment: .top) {
                section(at: .northWest)
                Spacer()
                section(at: .north)
                Spacer()
                section(at: .northEast)
            }
            Spacer()
            HStack {
                section(at: .west)
                Spacer()
                section(at: .east)
            }
            Spacer()
            HStack(alignment: .bottom) {
                section(at: .southWest)
                Spacer()
                section(at: .south)
                Spacer()
                section(at: .southEast)
            }
            .clipped()
        }
        .border(debugMode ? Color.black : Color.clear, width: debugMode ? 5 : 0)
        .padding(.top, runtimeCanvas.hudTopMargin)
        .padding(.horizontal, runtimeCanvas.hudHorizontalMargin)
        .padding(.bottom, runtimeCanvas.hudBottomMargin)
    }

    @ViewBuilder
    private func section(at hudLocation: HudLocation) -> some View {
        switch hudLayoutConfig.section(at: hudLocation) {
        case .heroBar:
            HudHeroesBarView(runtimeCanvas: runtimeCanvas, db: db)
        case .statsView:
            HudStatsView(runtimeCanvas: runtimeCanvas, runner: runner)
        case .miscView:
            HudMiscView(runtimeCanvas: runtimeCanvas)
        case .masterControls:
            HudMasterControlsView(runtimeCanvas: runtimeCanvas,
                                  onSpeedUp: onSpeedUp,
                                  onExit: onExit)
        case nil:
            EmptyView()
        }
    }
}
