#!/usr/bin/env python3
"""Exercise production haptic dispatch/lifecycle with spy hardware and real patterns."""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import tempfile
from check_reinforcement_runner import block

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    source_path = ROOT / 'Liberty Line/LevelRunner.swift'
    source = source_path.read_text()
    signatures = ['private func playHaptic(', 'private func playBuildHaptic()',
                  'func playEnemyEscapeHaptic(', 'func stop()',
                  'private func stopSimulation()', 'private func loseLife()']
    harness = r'''
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
    // PRODUCTION
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
'''
    harness = harness.replace('// PRODUCTION', '\n'.join(block(source, s) for s in signatures))
    args.output.mkdir(parents=True, exist_ok=True)
    swift_path = args.output / 'haptic-playback-probe.swift'
    swift_path.write_text(harness)
    build = Path('/tmp/td-presentation-tests/arm64-apple-macosx/debug')
    with tempfile.TemporaryDirectory(prefix='td-haptic-playback-') as tmp:
        executable = Path(tmp) / 'probe'
        subprocess.run(['swiftc', '-parse-as-library', '-module-cache-path', '/tmp/td-tower-swift-cache',
                        '-I', str(build / 'Modules'), str(swift_path)]
                       + [str(p) for p in (build / 'LevelEditorFormats.build').glob('*.swift.o')]
                       + ['-o', str(executable)], check=True)
        result = subprocess.run([str(executable)], capture_output=True, text=True, timeout=30, check=True)
    (args.output / 'playback-results.json').write_text(json.dumps(dict(
        result=result.stdout.strip(), production_blocks=signatures,
        source_sha256=hashlib.sha256(source_path.read_bytes()).hexdigest(),
        limitation='Real pattern construction and production dispatch with spy engine/players; physical sensation is not measured.'
    ), indent=2) + '\n')
    print(result.stdout.strip())


if __name__ == '__main__':
    main()
