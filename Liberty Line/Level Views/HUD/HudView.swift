import SwiftUI

struct LevelHUDInput {
    let activate: (LevelHUDControl) -> Void
    let callWave: (Point) -> Void
}

/// One HUD for live play and recorded playback. A missing input adapter makes
/// every game control read-only without changing its recorded appearance.
struct HudView: View {
    let runtimeCanvas: RuntimeCanvas
    let state: LevelHUDState
    let hudLayoutConfig: HudLayoutConfig
    var input: LevelHUDInput? = nil
    var debugStatus: String? = nil
    /// Strategy demonstrations supply their own playback controls.
    var showsAuxiliaryControls = true

    var body: some View {
        ZStack(alignment: .topLeading) {
            let heroes = HeroBarLayout(runtimeCanvas: runtimeCanvas, location: hudLayoutConfig.heroBar)
            HudHeroesBarView(layout: heroes, state: state, onAction: { input?.activate($0) })
                .position(x: heroes.frame.midX, y: heroes.frame.midY)

            let stats = HudStatsView.occupiedFrame(runtimeCanvas: runtimeCanvas, config: hudLayoutConfig)
            HudStatsView(runtimeCanvas: runtimeCanvas, state: state, location: hudLayoutConfig.statsView,
                         debugStatus: debugStatus)
                .position(x: stats.midX, y: stats.midY)

            if showsAuxiliaryControls {
                let misc = HudButtonRowLayout(area: runtimeCanvas.hudPlayArea,
                                              location: hudLayoutConfig.miscView, count: 1)
                HudMiscView(runtimeCanvas: runtimeCanvas, location: hudLayoutConfig.miscView,
                    isActivated: state.isActivated(.inventory), action: { input?.activate(.inventory) })
                    .position(x: misc.frame.midX, y: misc.frame.midY)

                let controls = MasterControlsLayout(runtimeCanvas: runtimeCanvas,
                                                     location: hudLayoutConfig.masterControls)
                HudMasterControlsView(runtimeCanvas: runtimeCanvas, location: hudLayoutConfig.masterControls,
                    speedActivated: state.isActivated(.speed), pauseActivated: state.isActivated(.pause) || state.isPaused,
                    onSpeedUp: { input?.activate(.speed) }, onPause: { input?.activate(.pause) })
                    .position(x: controls.frame.midX, y: controls.frame.midY)
            }

            CallWaveButtonLayer(runtimeCanvas: runtimeCanvas, positions: state.callWavePositions,
                waveNumber: state.nextWave, countdownSeconds: state.countdownSeconds,
                selection: state.callWaveSelection, seconds: state.seconds,
                action: { input?.callWave($0) })
        }
        .disabled(input == nil)
        .allowsHitTesting(input != nil)
    }
}
