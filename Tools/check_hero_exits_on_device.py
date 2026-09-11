#!/usr/bin/env python3
"""Check exact GeoJSON hero starts and respawns on a physical iPhone.

Builds a temporary copy with a separate app ID and the probe as its entry point.
The installed game, its save, and the source checkout are not modified.
"""
import argparse
import json
import shutil
import subprocess
import tempfile
import time
import uuid
from pathlib import Path

GAME = Path(__file__).resolve().parents[1]
BUNDLE_ID = 'com.zippyzen.hero-exit-probe'


def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True, help='Connected physical iPhone identifier')
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--all-levels', action='store_true')
    parser.add_argument('--custom-starts', action='store_true',
                        help='Use fractional, off-road Charleston starts in the disposable app only')
    parser.add_argument('--exit-overlap', action='store_true',
                        help='Place both Charleston heroes directly on exit icons for layer review')
    args = parser.parse_args()
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    run_id = str(uuid.uuid4())
    with tempfile.TemporaryDirectory(prefix='td-hero-device-') as tmp:
        temp = Path(tmp)
        root = temp / GAME.name
        root.mkdir()
        (temp / 'in-defense-of-history-data').symlink_to(GAME.parent / 'in-defense-of-history-data')
        for source in GAME.iterdir():
            if source.name in {'.git', '.codex', '.agents', 'build', '.build', 'Tools', 'Tests'}:
                continue
            target = root / source.name
            if source.name in {'Liberty Line', 'InDefenseOfHistory.xcodeproj', 'Versioning'} or (source.name == 'Db' and (args.custom_starts or args.exit_overlap)):
                shutil.copytree(source, target)
            else:
                target.symlink_to(source)
        if args.custom_starts or args.exit_overlap:
            level_file = root / 'Db/level_15_charleston.geojson'
            level = json.loads(level_file.read_text())
            exits = [f['geometry']['coordinates'] for f in level['features']
                     if f.get('properties', {}).get('kind') == 'goal_point']
            for feature in level['features']:
                if feature.get('properties', {}).get('kind') == 'hero_spawn':
                    role = feature['properties']['heroRoles'][0]
                    feature['geometry']['coordinates'] = (exits[0 if role == 'primary' else 1]
                        if args.exit_overlap else [1520.25, 1100.75] if role == 'primary' else [1700.5, 900.125])
            level_file.write_text(json.dumps(level, indent=2) + '\n')
        shutil.copytree(GAME / 'Tools', root / 'Tools', ignore=shutil.ignore_patterns('reports', '__pycache__'))
        (root / 'Liberty Line/LibertyLineApp.swift').write_text((GAME / 'Tools/HeroExitRuntimeProbe.swift').read_text())
        runner = root / 'Liberty Line/LevelRunner.swift'
        with runner.open('a') as output:
            output.write('''
extension LevelRunner {
    func probeCharlestonWaveStarts() throws -> [[String: Any]] {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "CharlestonWaveProbe", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        try require(waves.count == 15 && paths.count == 4, "Expected 15 waves and four routes")
        let authored = try db.levelGeoJSONDao.getEnemyRoutes(mapImageName: mapImageName)!
        try require(paths == authored.map(\\.path), "Runtime routes differ from GeoJSON")
        try require(try db.pathDao.getPathsFor(levelInfoId: UUID(uuidString: "4ca73a47-98f6-41b6-815d-c2c797aa746e")!) == paths,
                    "Bundled SQL routes differ from GeoJSON")
        let movementArea = try db.levelGeoJSONDao.getHeroMovementArea(mapImageName: mapImageName, defaultPathWidth: virtualCanvas.pathWidth)
        for route in paths {
            try require(zip(route.points, route.points.dropFirst()).allSatisfy {
                movementArea.containsSegment(from: $0.0, to: $0.1)
            }, "An enemy route leaves the authored path area")
        }
        var checks: [[String: Any]] = []
        startNextWave()
        var expectedCount = 0
        for index in waves.indices {
            let wave = waves[index]
            let startTick = Int64((wave.startTime / SimClock.dt).rounded())
            if index > 0 {
                while timer.tick < startTick - 1 {
                    timer.advanceTick()
                    advanceWaveSchedule()
                }
                try require(waveIndex == index - 1, "Wave started before its authored deadline")
                try require(awaitingWaveStart && waveCountdownSeconds == 1, "Missing final countdown second")
                try require(callWaveButtonPositions.count == Set(wave.spawns.map { authored[$0.pathIndex].entranceID }).count,
                            "Incorrect entrance buttons for the incoming wave")
                timer.advanceTick()
                advanceWaveSchedule()
            }
            expectedCount += wave.spawns.reduce(0) { $0 + $1.count }
            try require(waveIndex == index, "Wave did not start at its authored deadline")
            try require(pendingSpawns.count == expectedCount, "Missing queued enemies")
            try require(pendingSpawns.allSatisfy { paths.indices.contains($0.pathIndex) }, "Invalid spawn route")
            checks.append(["wave": index + 1, "startSeconds": Double(timer.tick) * SimClock.dt,
                           "enemies": wave.spawns.reduce(0) { $0 + $1.count }])
        }
        try require(expectedCount == 424 && waveSchedule.allWavesStarted, "Incomplete finale")
        return checks
    }
    func probeHeroRespawns() -> [CGPoint] {
        for i in heroPosts.indices {
            heroPosts[i].unit.state = .dead
            heroPosts[i].unit.respawnTicksLeft = 0
        }
        var claimed = Set<Int>(), killed = Set<Int>()
        stepHeroesTick(claimed: &claimed, killedIDs: &killed, indexByWalkerID: [:])
        publishHeroes()
        return heroes.map(\\.position)
    }
}
''')
        build = temp / 'build'
        with (args.output / 'device-build.log').open('w') as log:
            run('xcodebuild', '-project', str(root / 'InDefenseOfHistory.xcodeproj'),
                '-scheme', 'Liberty Line', '-configuration', 'Debug', '-destination', f'id={args.device}',
                '-derivedDataPath', str(build), '-allowProvisioningUpdates',
                f'PRODUCT_BUNDLE_IDENTIFIER={BUNDLE_ID}', 'INFOPLIST_KEY_CFBundleDisplayName=Hero Exit Check', 'build', stdout=log, stderr=subprocess.STDOUT)
        app = build / 'Build/Products/Debug-iphoneos/Liberty Line.app'
        run('xcrun', 'devicectl', 'device', 'install', 'app', '--device', args.device, str(app))
        run('xcrun', 'devicectl', 'device', 'process', 'launch', '--device', args.device,
            '--terminate-existing', BUNDLE_ID, '--probe-run-id', run_id,
            *(['--custom-starts'] if args.custom_starts and not args.exit_overlap else []),
            *(['--exit-overlap'] if args.exit_overlap else []),
            *([] if args.all_levels else ['--level-15-only']))
        result = args.output / 'hero-exits.json'
        result.unlink(missing_ok=True)
        deadline = time.monotonic() + 420
        while time.monotonic() < deadline:
            copy = subprocess.run(['xcrun', 'devicectl', 'device', 'copy', 'from', '--device', args.device,
                '--domain-type', 'appDataContainer', '--domain-identifier', BUNDLE_ID,
                '--source', 'Documents/hero-exits.json', '--destination', str(result)], capture_output=True)
            if copy.returncode == 0 and result.exists():
                if json.loads(result.read_text()).get('runID') == run_id:
                    break
                result.unlink()
            time.sleep(5)
        assert result.exists(), 'Physical-device probe did not finish'
        # The visual view mounts after the functional checks; wait for both
        # native-device and minimum-size captures before collecting documents.
        if args.exit_overlap:
            ready = args.output / 'captures-ready.txt'
            ready.unlink(missing_ok=True)
            for _ in range(20):
                copy = subprocess.run(['xcrun', 'devicectl', 'device', 'copy', 'from', '--device', args.device,
                    '--domain-type', 'appDataContainer', '--domain-identifier', BUNDLE_ID,
                    '--source', 'Documents/captures-ready.txt', '--destination', str(ready)], capture_output=True)
                if copy.returncode == 0 and ready.exists() and ready.read_text() == run_id:
                    break
                time.sleep(2)
            assert ready.exists() and ready.read_text() == run_id, 'Overlap captures did not finish'
        run('xcrun', 'devicectl', 'device', 'copy', 'from', '--device', args.device,
            '--domain-type', 'appDataContainer', '--domain-identifier', BUNDLE_ID,
            '--source', 'Documents', '--destination', str(args.output / 'device-documents'))
        data = json.loads(result.read_text())
        assert data['passed'], f"After {len(data.get('checks', []))} loads: {data.get('error')}"
        print(f"Passed {data['loads']} LevelRunner loads on physical iPhone. {args.output}")


if __name__ == '__main__':
    main()
