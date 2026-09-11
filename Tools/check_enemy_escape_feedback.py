#!/usr/bin/env python3
"""Exercise the production exit-crossing loop and life-loss event with fixture paths."""
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
    start = source.index('        var marching: [Walker] = []')
    end = source.index('        walkers = marching', start) + len('        walkers = marching')
    marching = source[start:end]
    harness = r'''
import Foundation
import LevelEditorFormats

final class Probe {
    struct Clock { var tick: Int64 = 0 }
    var timer = Clock()
    var lives = 3
    var escapedEnemyCount = 0
    var isDefeated = false
    var pendingSpawns = [1, 2]
    var stopCount = 0
    var refreshCount = 0
    var walkers: [Walker] = []
    var blockedWalkerIDs: Set<Int> = []
    let paths = [Path(points: [Point(0, 0), Point(100, 0)]),
                 Path(points: [Point(0, 0), Point(200, 0)])]
    func stopSimulation() { stopCount += 1 }
    func refreshWaveStartState() { refreshCount += 1 }
    // PRODUCTION
    func march(to tick: Int64) {
        let frameDtTicks = Double(tick - timer.tick)
        timer.tick = tick
        let alpha = 0.0
        // MARCH
    }
    func add(_ id: Int, path: Int = 0) {
        walkers.append(Walker(id: id, assetName: "fixture", speed: 30, maxHP: 10, hp: 10,
            bounty: 1, damageMin: 1, damageMax: 1, cover: 0, blockImmune: false,
            spawnTick: 0, pathIndex: path))
    }
    static func run() {
        let single = Probe()
        single.add(0)
        single.march(to: 99)
        precondition(single.walkers.count == 1 && single.lives == 3 && single.escapedEnemyCount == 0)
        single.march(to: 100)
        precondition(single.walkers.isEmpty && single.lives == 2 && single.escapedEnemyCount == 1)
        single.march(to: 200)
        precondition(single.escapedEnemyCount == 1 && single.stopCount == 0)

        let blocked = Probe()
        blocked.add(0)
        blocked.blockedWalkerIDs = [0]
        blocked.march(to: 100)
        precondition(blocked.escapedEnemyCount == 0 && blocked.walkers.count == 1)
        blocked.blockedWalkerIDs = []
        blocked.march(to: 199)
        precondition(blocked.escapedEnemyCount == 0)
        blocked.march(to: 200)
        precondition(blocked.escapedEnemyCount == 1)

        let routes = Probe()
        routes.add(0); routes.add(1, path: 1)
        routes.march(to: 100)
        precondition(routes.escapedEnemyCount == 1 && routes.walkers.map(\.id) == [1])
        routes.march(to: 200)
        precondition(routes.escapedEnemyCount == 2 && routes.lives == 1)

        let burst = Probe()
        for id in 0..<5 { burst.add(id) }
        burst.march(to: 200)
        precondition(burst.isDefeated && burst.lives == 0 && burst.escapedEnemyCount == 3)
        precondition(burst.stopCount == 1 && burst.pendingSpawns.isEmpty)
        burst.loseLife()
        precondition(burst.escapedEnemyCount == 3 && burst.stopCount == 1)
        print("PASS: exit boundary, removal without duplicate events, blocked enemies, multiple routes, burst losses, final-life event, and defeat shutdown")
    }
}
@main struct Main { static func main() { Probe.run() } }
'''
    harness = harness.replace('// PRODUCTION', block(source, 'struct Walker:') + '\n' + block(source, 'private func loseLife()'))
    harness = harness.replace('// MARCH', marching)
    args.output.mkdir(parents=True, exist_ok=True)
    swift_path = args.output / 'enemy-escape-probe.swift'
    swift_path.write_text(harness)
    build = Path('/tmp/td-presentation-tests/arm64-apple-macosx/debug')
    with tempfile.TemporaryDirectory(prefix='td-enemy-escape-') as tmp:
        executable = Path(tmp) / 'probe'
        subprocess.run(['swiftc', '-parse-as-library', '-module-cache-path', '/tmp/td-tower-swift-cache',
                        '-I', str(build / 'Modules'), str(swift_path)]
                       + [str(p) for p in (build / 'LevelEditorFormats.build').glob('*.swift.o')]
                       + ['-o', str(executable)], check=True)
        result = subprocess.run([str(executable)], capture_output=True, text=True, timeout=30, check=True)
    (args.output / 'runner-results.json').write_text(json.dumps(dict(
        result=result.stdout.strip(), source_sha256=hashlib.sha256(source_path.read_bytes()).hexdigest(),
        limitation='Production exit loop and life-loss method with fixture paths/clock; no physical haptic hardware.'
    ), indent=2) + '\n')
    print(result.stdout.strip())


if __name__ == '__main__':
    main()
