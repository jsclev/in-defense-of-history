import SwiftUI

@available(iOS 26.0, *)
struct HudView: View {
    private let db: Db
    private let runtimeCanvas: RuntimeCanvas
    private let runner: LevelRunner
    private let hudLayoutConfig: HudLayoutConfig
    private let onSpeedUp: () -> Void
    private let onPause: () -> Void


    public init(runtimeCanvas: RuntimeCanvas, db: Db, runner: LevelRunner,
                hudLayoutConfig: HudLayoutConfig,
                onSpeedUp: @escaping () -> Void,
                onPause: @escaping () -> Void) {
        self.db = db
        self.runtimeCanvas = runtimeCanvas
        self.runner = runner
        self.hudLayoutConfig = hudLayoutConfig
        self.onSpeedUp = onSpeedUp
        self.onPause = onPause
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            let heroes = HeroBarLayout(runtimeCanvas: runtimeCanvas, location: hudLayoutConfig.heroBar)
            HudHeroesBarView(layout: heroes, runner: runner)
                .position(x: heroes.frame.midX, y: heroes.frame.midY)

            let stats = HudStatsView.occupiedFrame(runtimeCanvas: runtimeCanvas, config: hudLayoutConfig)
            HudStatsView(runtimeCanvas: runtimeCanvas, runner: runner, location: hudLayoutConfig.statsView)
                .position(x: stats.midX, y: stats.midY)

            let misc = HudButtonRowLayout(area: runtimeCanvas.hudPlayArea,
                                           location: hudLayoutConfig.miscView, count: 1)
            HudMiscView(runtimeCanvas: runtimeCanvas, location: hudLayoutConfig.miscView)
                .position(x: misc.frame.midX, y: misc.frame.midY)

            let controls = MasterControlsLayout(runtimeCanvas: runtimeCanvas,
                                                 location: hudLayoutConfig.masterControls)
            HudMasterControlsView(runtimeCanvas: runtimeCanvas, location: hudLayoutConfig.masterControls,
                                  onSpeedUp: onSpeedUp, onPause: onPause)
                .position(x: controls.frame.midX, y: controls.frame.midY)
        }
    }
}
