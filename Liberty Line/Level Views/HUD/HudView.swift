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
        self.hudLayoutConfig = hudLayoutConfig.moving(.heroBar, to: .southWest)
        self.onSpeedUp = onSpeedUp
        self.onExit = onExit
    }

    var body: some View {
        let hud = runtimeCanvas.hudRect
        ZStack(alignment: .topLeading) {
            ForEach(HudLocation.allCases, id: \.self) { location in
                // Independent anchors: text changes in one section cannot
                // push the center or opposite edge's controls around.
                Color.clear
                    .frame(width: hud.width, height: hud.height)
                    .overlay(alignment: location.alignment) {
                        section(at: location)
                    }
                    .position(x: hud.midX, y: hud.midY)
            }
        }
        .overlay(alignment: .topLeading) {
            let layout = HeroBarLayout(runtimeCanvas: runtimeCanvas)
            HudHeroesBarView(layout: layout, runner: runner)
                .position(x: layout.frame.midX, y: layout.frame.midY)
        }
    }

    @ViewBuilder
    private func section(at hudLocation: HudLocation) -> some View {
        switch hudLayoutConfig.section(at: hudLocation) {
        case .heroBar:
            EmptyView()
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

private extension HudLocation {
    var alignment: Alignment {
        switch self {
        case .northWest: return .topLeading
        case .north: return .top
        case .northEast: return .topTrailing
        case .west: return .leading
        case .east: return .trailing
        case .southWest: return .bottomLeading
        case .south: return .bottom
        case .southEast: return .bottomTrailing
        }
    }
}
