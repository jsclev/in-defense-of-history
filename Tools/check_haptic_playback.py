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
    parser.add_argument('--build-path', type=Path,
                        default=Path('/tmp/td-presentation-tests/arm64-apple-macosx/debug'),
                        help='SwiftPM debug products directory (native Xcode or legacy SwiftPM layout)')
    args = parser.parse_args()
    source_path = ROOT / 'Liberty Line/LevelRunner.swift'
    source = source_path.read_text()
    signatures = ['func playEnemyEscapeHaptic(', 'private func playGameplayHaptic(', 'func stop()',
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
    func makeAdvancedPlayer(with pattern: CHHapticPattern) throws -> SpyPlayer {
        try makePlayer(with: pattern)
    }
    func stop() { stops += 1 }
}
final class SpyFeedback {
    enum Kind { case error }
    var calls: [Kind] = []
    var impacts = 0
    func notificationOccurred(_ kind: Kind) { calls.append(kind) }
    func impactOccurred(intensity: CGFloat) { impacts += 1 }
}
final class SpyDisplayLink {
    var stopped = false
    func invalidate() { stopped = true }
}
final class Probe {
    var hapticEngine: SpyEngine? = SpyEngine()
    var activeHapticPlayer: SpyPlayer?
    var demolitionHapticPlayer: SpyPlayer?
    private enum HapticPlayback { case inactive, coreHaptics, fallback }
    var hapticsActive = true
    var enemyEscapeFeedback = SpyFeedback()
    var demolitionFeedback = SpyFeedback()
    var artilleryImpacts: [Int] = []
    var displayLink: SpyDisplayLink? = SpyDisplayLink()
    var lives = 1, escapedEnemyCount = 0
    var isDefeated = false
    var pendingSpawns = [1]
    func startHapticEngine() {} // Hardware availability/startup is a fixture.
    func refreshWaveStartState() {}
    // PRODUCTION
    static func run() {
        let exits = Probe(), engine = exits.hapticEngine!
        exits.playEnemyEscapeHaptic(.lifeLoss)
        let loss = engine.players[0]
        precondition(loss.duration == GameplayHapticPattern.lifeLoss.duration && loss.starts == 1)
        exits.playEnemyEscapeHaptic(.defeat)
        let defeat = engine.players[1]
        precondition(loss.stops == 1 && defeat.duration == GameplayHapticPattern.defeat.duration)
        exits.stop()
        precondition(defeat.stops == 1 && engine.stops == 1 && !exits.hapticsActive)
        exits.playEnemyEscapeHaptic(.lifeLoss)
        precondition(engine.players.count == 2 && exits.enemyEscapeFeedback.calls.isEmpty)

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
        fallback.playEnemyEscapeHaptic(.lifeLoss)
        fallback.playEnemyEscapeHaptic(.defeat)
        precondition(fallback.enemyEscapeFeedback.calls == [.error, .error])
        fallback.stop()
        fallback.playEnemyEscapeHaptic(.lifeLoss)
        precondition(fallback.enemyEscapeFeedback.calls.count == 2)

        let failure = Probe(), failedEngine = failure.hapticEngine!
        failedEngine.shouldFail = true
        failure.playEnemyEscapeHaptic(.lifeLoss)
        precondition(failure.enemyEscapeFeedback.calls == [.error] && failedEngine.players.isEmpty)
        failedEngine.shouldFail = false
        failure.playEnemyEscapeHaptic(.defeat)
        precondition(failedEngine.players.count == 1 && failedEngine.players[0].starts == 1)

        let blast = Probe(), blastEngine = blast.hapticEngine!
        precondition(blast.playGameplayHaptic(.demolitionExplosion) == .coreHaptics)
        let explosion = blast.demolitionHapticPlayer!
        blast.playEnemyEscapeHaptic(.lifeLoss)
        let escape = blast.activeHapticPlayer!
        precondition(explosion.stops == 0 && blast.demolitionHapticPlayer === explosion,
                     "Life loss cancelled the explosion")
        blast.playEnemyEscapeHaptic(.defeat)
        precondition(explosion.stops == 0 && escape.stops == 1,
                     "Defeat must replace life loss without cancelling the explosion")
        let defeatCue = blast.activeHapticPlayer!
        precondition(blast.playGameplayHaptic(.demolitionExplosion) == .coreHaptics)
        let secondBlast = blast.demolitionHapticPlayer!
        precondition(explosion.stops == 1 && defeatCue.stops == 0 && secondBlast.starts == 1)
        blast.stop()
        precondition(secondBlast.stops == 1 && defeatCue.stops == 1 && blastEngine.stops == 1)
        precondition(blast.demolitionHapticPlayer == nil && blast.activeHapticPlayer == nil)
        precondition(blast.playGameplayHaptic(.demolitionExplosion) == .inactive)

        let blastFallback = Probe()
        blastFallback.hapticEngine = nil
        precondition(blastFallback.playGameplayHaptic(.demolitionExplosion) == .fallback)
        precondition(blastFallback.demolitionFeedback.impacts == 1)
        print("PASS: escape/final-life dispatch, preemption, inactive suppression, completion, stop cancellation, failure fallback, recovery, independent explosion playback, explosion fallback")
    }
}
@main struct Main { static func main() { Probe.run() } }
'''
    harness = harness.replace('// PRODUCTION', '\n'.join(block(source, s) for s in signatures))
    args.output.mkdir(parents=True, exist_ok=True)
    swift_path = args.output / 'haptic-playback-probe.swift'
    swift_path.write_text(harness)
    build = args.build_path.resolve()
    if (build / 'LevelEditorFormats.o').exists():
        modules = build
        objects = [build / 'LevelEditorFormats.o']
    else:
        modules = build / 'Modules'
        objects = list((build / 'LevelEditorFormats.build').glob('*.swift.o'))
    if not modules.exists() or not objects:
        parser.error(f'No compiled LevelEditorFormats module/objects in {build}; run swift test first')
    with tempfile.TemporaryDirectory(prefix='td-haptic-playback-') as tmp:
        executable = Path(tmp) / 'probe'
        subprocess.run(['swiftc', '-parse-as-library',
                        '-I', str(modules), str(swift_path)]
                       + [str(p) for p in objects]
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
