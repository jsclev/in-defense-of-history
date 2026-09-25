import SwiftUI

/// Full-screen review of saved battlefield and HUD state. Only its separate
/// bottom playback controls accept input.
struct LevelRunReviewView: View {
    let dao: LevelRunDAO
    let runID: UUID
    let canvas: RuntimeCanvas
    let onExit: () -> Void
    @State private var playback: LevelReplayPlayback?
    @State private var sceneSetup: LevelSceneSetup?
    @State private var error: String?

    var body: some View {
        Group {
            if let playback, let sceneSetup {
                LevelRunReviewPlayer(playback: playback, sceneSetup: sceneSetup, canvas: canvas, onExit: onExit)
            } else {
                ZStack(alignment: .topLeading) {
                    Color.black
                    Group {
                        if let error { Text("Unable to open replay\n\(error)").foregroundStyle(CouncilPalette.cream) }
                        else { ProgressView().tint(CouncilPalette.cream) }
                    }
                    .frame(width: canvas.safeInsetsRect.width - 48)
                    .position(x: canvas.safeInsetsRect.midX, y: canvas.safeInsetsRect.midY)
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
                let player = try LevelReplayPlayback(dao: dao, runID: runID, speed: PlaySpeed(1))
                sceneSetup = try LevelSceneSetup(recording: player.setup)
                playback = player
            } catch { self.error = String(describing: error) }
        }
    }
}

private struct LevelRunReviewPlayer: View {
    @ObservedObject var playback: LevelReplayPlayback
    let sceneSetup: LevelSceneSetup
    let canvas: RuntimeCanvas
    let onExit: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var error: String?

    private var isPlaying: Bool {
        scenePhase == .active && !playback.isPaused && !playback.isFinished && error == nil
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RecordedLevelView(setup: sceneSetup, recording: playback.setup, frame: playback.frame, canvas: canvas)
            if let error {
                Text("Replay stopped\n\(error)").foregroundStyle(CouncilPalette.cream)
                    .padding(20).background(CouncilPanel())
                    .frame(width: min(480, canvas.safeInsetsRect.width - 32))
                    .position(x: canvas.safeInsetsRect.midX, y: canvas.safeInsetsRect.midY)
            }
            LevelReplayControls(canvas: canvas, paused: playback.isPaused,
                enabled: !playback.isFinished && error == nil,
                onPause: playback.togglePause, onExit: onExit)
        }
        .frame(width: canvas.physicalRect.width, height: canvas.physicalRect.height)
        .task(id: isPlaying) {
            guard isPlaying else { return }
            // Starting a new clock segment after pause/background discards the
            // suspended wall time, so resume never jumps forward.
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
}

struct LevelReplayControls: View {
    let canvas: RuntimeCanvas
    let paused: Bool
    let enabled: Bool
    let onPause: () -> Void
    let onExit: () -> Void

    var body: some View {
        let side = min(64, max(48, canvas.safeInsetsRect.height * 0.15))
        HStack(spacing: 16) {
            ReplaySymbolButton(symbol: paused ? "play.fill" : "pause.fill",
                label: paused ? "Resume replay" : "Pause replay", side: side, action: onPause)
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.5)
                .accessibilityValue(enabled ? (paused ? "Paused" : "Playing") : "Finished")
                .accessibilityIdentifier("replay-pause")
            ReplaySymbolButton(symbol: "xmark", label: "Exit replay", side: side, action: onExit)
                .accessibilityIdentifier("replay-exit")
        }
        .padding(8)
        .background(CouncilPalette.ink.opacity(0.9), in: CouncilCutCorner())
        .position(x: canvas.safeInsetsRect.midX, y: canvas.safeInsetsRect.maxY - side / 2 - 8)
    }
}
