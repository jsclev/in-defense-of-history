
import Foundation
import CoreHaptics
import LevelEditorFormats

final class SpyPlayer {
    let duration: TimeInterval
    var starts = 0, stops = 0
    init(_ pattern: CHHapticPattern) { duration = pattern.duration }
    func start(atTime: TimeInterval) throws { starts += 1 }
    func stop(atTime: TimeInterval) throws { stops += 1 }
}
final class SpyEngine {
    enum Failure: Error { case unavailable }
    var players: [SpyPlayer] = []
    var stops = 0
    var shouldFail = false
    func start() throws { if shouldFail { throw Failure.unavailable } }
    func makePlayer(with pattern: CHHapticPattern) throws -> SpyPlayer {
        let player = SpyPlayer(pattern); players.append(player); return player
    }
    func stop() { stops += 1 }
}
final class SpyFeedback {
    enum Kind { case success, error }
    var calls: [Kind] = []
    func notificationOccurred(_ kind: Kind) { calls.append(kind) }
}
final class SpyDisplayLink {
    var stopped = false
    func invalidate() { stopped = true }
}
final class Probe {
    var hapticEngine: SpyEngine? = SpyEngine()
    var activeHapticPlayer: SpyPlayer?
    var hapticsActive = true
    var lossHapticProtectedUntil: TimeInterval = 0
    var buildFeedback = SpyFeedback()
    var displayLink: SpyDisplayLink? = SpyDisplayLink()
    var lives = 1, escapedEnemyCount = 0
    var isDefeated = false
    var pendingSpawns = [1]
    func startHapticEngine() {} // Hardware availability/startup is a fixture.
    func refreshWaveStartState() {}
    private func playHaptic(_ cue: GameplayHapticPattern) {
        guard hapticsActive else { return }
        let now = ProcessInfo.processInfo.systemUptime
        // Damage feedback takes priority; a build must not mix into its rhythm.
        guard cue != .build || now >= lossHapticProtectedUntil else { return }
        if cue != .build {
            lossHapticProtectedUntil = now + max(EnemyEscapeHapticPolicy.minimumInterval,
                                                 cue.duration + 0.05)
        }
        try? activeHapticPlayer?.stop(atTime: CHHapticTimeImmediate)
        activeHapticPlayer = nil
        startHapticEngine()
        do {
            guard let engine = hapticEngine else {
                buildFeedback.notificationOccurred(cue == .build ? .success : .error)
                return
            }
            try engine.start()
            let player = try engine.makePlayer(with: cue.makePattern())
            try player.start(atTime: CHHapticTimeImmediate)
            activeHapticPlayer = player
        } catch {
            // Four-pulse failure fallback, never the similar two-pulse warning.
            buildFeedback.notificationOccurred(cue == .build ? .success : .error)
        }
    }
private func playBuildHaptic() {
        playHaptic(.build)
    }
func playEnemyEscapeHaptic(_ cue: EnemyEscapeHapticPolicy.Cue) {
        playHaptic(cue == .defeat ? .defeat : .lifeLoss)
    }
func stop() {
        stopSimulation()
        hapticsActive = false
        try? activeHapticPlayer?.stop(atTime: CHHapticTimeImmediate)
        activeHapticPlayer = nil
        lossHapticProtectedUntil = 0
        hapticEngine?.stop()
        hapticEngine = nil
    }
private func stopSimulation() {
        displayLink?.invalidate()
        displayLink = nil
    }
private func loseLife() {
        guard !isDefeated else { return }
        lives = max(0, lives - 1)
        escapedEnemyCount += 1
        guard lives == 0 else { return }
        isDefeated = true
        pendingSpawns.removeAll()
        refreshWaveStartState()
        // Defeat still needs its complete haptic while the game-over view is
        // visible. Leaving/backgrounding the level calls stop() to end both.
        stopSimulation()
    }
    static func run() {
        let mixed = Probe(), engine = mixed.hapticEngine!
        mixed.playBuildHaptic()
        let build = engine.players[0]
        precondition(build.duration == GameplayHapticPattern.build.duration && build.starts == 1)
        mixed.playEnemyEscapeHaptic(.lifeLoss)
        let loss = engine.players[1]
        precondition(build.stops == 1 && loss.duration == GameplayHapticPattern.lifeLoss.duration)
        mixed.playBuildHaptic()
        precondition(engine.players.count == 2 && loss.stops == 0 && mixed.buildFeedback.calls.isEmpty)
        mixed.playEnemyEscapeHaptic(.defeat)
        let defeat = engine.players[2]
        precondition(loss.stops == 1 && defeat.duration == GameplayHapticPattern.defeat.duration)
        mixed.stop()
        precondition(defeat.stops == 1 && engine.stops == 1 && !mixed.hapticsActive)
        mixed.playBuildHaptic(); mixed.playEnemyEscapeHaptic(.lifeLoss)
        precondition(engine.players.count == 3 && mixed.buildFeedback.calls.isEmpty)

        let finalLife = Probe(), finalEngine = finalLife.hapticEngine!, link = finalLife.displayLink!
        finalLife.loseLife()
        precondition(finalLife.isDefeated && finalLife.escapedEnemyCount == 1 && link.stopped)
        precondition(finalLife.hapticsActive && finalEngine.stops == 0)
        finalLife.playEnemyEscapeHaptic(.defeat)
        precondition(finalEngine.players.count == 1 && finalEngine.players[0].stops == 0)
        finalLife.stop()
        precondition(finalEngine.players[0].stops == 1 && finalEngine.stops == 1)

        let fallback = Probe()
        fallback.hapticEngine = nil
        fallback.playBuildHaptic(); fallback.playEnemyEscapeHaptic(.lifeLoss)
        precondition(fallback.buildFeedback.calls == [.success, .error])
        fallback.playBuildHaptic()
        precondition(fallback.buildFeedback.calls.count == 2)

        let failure = Probe(), failedEngine = failure.hapticEngine!
        failedEngine.shouldFail = true
        failure.playEnemyEscapeHaptic(.lifeLoss)
        precondition(failure.buildFeedback.calls == [.error] && failedEngine.players.isEmpty)
        failedEngine.shouldFail = false
        failure.playEnemyEscapeHaptic(.defeat)
        precondition(failedEngine.players.count == 1 && failedEngine.players[0].starts == 1)
        print("PASS: build/loss/defeat dispatch, preemption without mixed patterns, inactive suppression, final-life completion, stop cancellation, failure fallback, fresh player after recovery")
    }
}
@main struct Main { static func main() { Probe.run() } }
