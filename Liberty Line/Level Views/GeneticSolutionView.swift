import SwiftUI

struct GeneticSolutionView: View {
    let db: Db
    let solution: GeneticSolution
    let canvas: RuntimeCanvas
    let onExit: () -> Void
    @State private var playback: GeneticSolutionPlayback?
    @State private var setup: LevelSceneSetup?
    @State private var error: String?

    var body: some View {
        Group {
            if let playback, let setup {
                GeneticSolutionPlayer(playback: playback, engine: playback.engine,
                    setup: setup, canvas: canvas, onExit: onExit)
            } else {
                ZStack {
                    Color.black
                    if let error { Text(error).foregroundStyle(CouncilPalette.cream).padding(32) }
                    else { ProgressView().tint(CouncilPalette.cream) }
                    LevelReplayControls(canvas: canvas, paused: false, enabled: false,
                        onPause: {}, onExit: onExit)
                }
            }
        }
        .frame(width: canvas.physicalRect.width, height: canvas.physicalRect.height)
        .background(.black)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .interactiveDismissDisabled()
        .accessibilityAction(.escape, onExit)
        .task {
            guard playback == nil, error == nil else { return }
            do {
                let player = try GeneticSolutionPlayback(solution: solution, db: db)
                let scene = try LevelSceneSetup(content: player.engine.content)
                player.engine.heroImageAspectRatios = Dictionary(uniqueKeysWithValues:
                    player.engine.content.deployments.map { ($0.hero.id, scene.heroAspectRatio(for: $0.hero.unitImageName)) })
                player.engine.validateHeroAsset = LevelSceneSetup.validateHeroAsset
                player.engine.publishesPresentation = true
                player.engine.advance(ticks: 0, interpolation: 0)
                setup = scene
                playback = player
            } catch { self.error = String(describing: error) }
        }
    }
}

private struct GeneticSolutionPlayer: View {
    @ObservedObject var playback: GeneticSolutionPlayback
    @ObservedObject var engine: BattleEngine
    let setup: LevelSceneSetup
    let canvas: RuntimeCanvas
    let onExit: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var error: String?
    private let speeds: [Double] = [0.5, 1, 2, 4, 8]

    private var isPlaying: Bool {
        scenePhase == .active && !playback.isPaused && !playback.isFinished && error == nil
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            LevelScene(setup: setup, state: LevelSceneState(engine: engine), canvas: canvas,
                       groundOverlay: { EmptyView() }, mapOverlay: { EmptyView() })
                .allowsHitTesting(false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Live winning strategy")
                .accessibilityValue("Tick \(engine.timer.tick)")
                .accessibilityIdentifier("ga-battlefield")
            HudView(runtimeCanvas: canvas, state: LevelHUDState(engine: engine),
                    hudLayoutConfig: engine.content.hudLayout, showsAuxiliaryControls: false)
            if let error {
                Text(error).foregroundStyle(CouncilPalette.cream).padding(20).background(CouncilPanel())
                    .frame(width: min(480, canvas.safeInsetsRect.width - 32))
                    .position(x: canvas.safeInsetsRect.midX, y: canvas.safeInsetsRect.midY)
            } else if playback.isFinished {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(CouncilPalette.ink, CouncilPalette.gold)
                    .accessibilityLabel("Winning solution verified")
                    .accessibilityIdentifier("ga-victory")
                    .position(x: canvas.safeInsetsRect.midX, y: canvas.safeInsetsRect.midY)
            }
            controls
        }
        .task(id: isPlaying) {
            guard isPlaying else { return }
            let clock = ContinuousClock()
            var previous = clock.now
            do {
                while !Task.isCancelled {
                    try await clock.sleep(until: previous.advanced(by: .seconds(1.0 / 60)))
                    try Task.checkCancellation()
                    guard isPlaying else { return }
                    let now = clock.now
                    try playback.advance(wallSeconds: previous.duration(to: now) / .seconds(1))
                    previous = now
                }
            } catch is CancellationError { }
            catch { self.error = String(describing: error) }
        }
    }

    private var controls: some View {
        let side = min(64, max(48, canvas.safeInsetsRect.height * 0.15))
        let enabled = !playback.isFinished && error == nil
        return HStack(spacing: 10) {
            ReplaySymbolButton(symbol: playback.isPaused ? "play.fill" : "pause.fill",
                label: playback.isPaused ? "Resume solution" : "Pause solution", side: side,
                action: playback.togglePause)
                .disabled(!enabled)
                .accessibilityValue(playback.isPaused ? "Paused" : "Playing")
                .accessibilityIdentifier("ga-pause")
            ReplaySymbolButton(symbol: "backward.fill", label: "Slower playback", side: side) { changeSpeed(-1) }
                .disabled(!enabled || playback.speed.factor == speeds.first)
                .accessibilityIdentifier("ga-slower")
            Text(playback.speed.factor.formatted(.number.precision(.fractionLength(0...1))) + "×")
                .font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit()
                .foregroundStyle(CouncilPalette.cream).frame(width: 54)
                .accessibilityLabel("Playback speed")
                .accessibilityValue(String(playback.speed.factor))
                .accessibilityIdentifier("ga-speed")
            ReplaySymbolButton(symbol: "forward.fill", label: "Faster playback", side: side) { changeSpeed(1) }
                .disabled(!enabled || playback.speed.factor == speeds.last)
                .accessibilityIdentifier("ga-faster")
            ReplaySymbolButton(symbol: "xmark", label: "Exit solution", side: side, action: onExit)
                .accessibilityIdentifier("ga-exit")
        }
        .padding(8).background(CouncilPalette.ink.opacity(0.9), in: CouncilCutCorner())
        .position(x: canvas.safeInsetsRect.midX, y: canvas.safeInsetsRect.maxY - side / 2 - 8)
    }

    private func changeSpeed(_ direction: Int) {
        guard let index = speeds.firstIndex(of: playback.speed.factor), speeds.indices.contains(index + direction) else { return }
        do { playback.setSpeed(try PlaySpeed(speeds[index + direction])) }
        catch { self.error = String(describing: error) }
    }
}
