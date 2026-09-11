#!/usr/bin/env python3
"""Check hero starts, respawns and bounds in 15 levels across three viewports."""
import argparse
import json
import plistlib
import shutil
import subprocess
import tempfile
import time
from pathlib import Path

GAME = Path(__file__).resolve().parents[1]
BUNDLE_ID = 'com.zippyzen.hero-exit-probe'


def run(*args):
    subprocess.run(args, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--resources', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='td-hero-exits-') as tmp:
        temp = Path(tmp)
        app = temp / 'HeroExitProbe.app'
        app.mkdir()
        for name in ['Assets.car', 'in_defense_of_history.sqlite']:
            shutil.copy2(args.resources / name, app / name)
        for source in args.resources.glob('*.geojson'):
            shutil.copy2(source, app / source.name)
        shutil.copytree(args.resources / 'LevelMaps', app / 'LevelMaps')
        info = dict(CFBundleIdentifier=BUNDLE_ID, CFBundleExecutable='HeroExitProbe',
            CFBundleName='HeroExitProbe', CFBundlePackageType='APPL', CFBundleVersion='1',
            CFBundleShortVersionString='1.0', MinimumOSVersion='26.5', UIDeviceFamily=[1, 2],
            UILaunchScreen={})
        (app / 'Info.plist').write_bytes(plistlib.dumps(info))
        omit = {'LibertyLineApp.swift', 'RootView.swift', 'Renderer.swift', 'TiledBackgroundMetalView.swift',
                'CampaignMapMetalView.swift', 'CampaignMapView.swift'}
        sources = sorted(GAME.glob('Engine/**/*.swift')) + [p for p in sorted(GAME.glob('Liberty Line/**/*.swift')) if p.name not in omit]
        # Same-file access lets the probe drive the real death/respawn branch.
        # Production code is copied unchanged; only this test helper is appended.
        runner = GAME / 'Liberty Line/LevelRunner.swift'
        probe_runner = temp / 'LevelRunner.swift'
        probe_runner.write_text(runner.read_text() + '''
extension LevelRunner {
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
        sources = [probe_runner if p == runner else p for p in sources]
        sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
        run('swiftc', '-swift-version', '5', '-module-cache-path', str(temp / 'cache'), '-parse-as-library',
            '-target', 'arm64-apple-ios26.5-simulator', '-sdk', sdk,
            str(GAME / 'Tools/HeroExitRuntimeProbe.swift'), *map(str, sources), '-o', str(app / 'HeroExitProbe'))
        run('codesign', '--force', '--sign', '-', '--timestamp=none', str(app))
        subprocess.run(['xcrun', 'simctl', 'terminate', args.device, BUNDLE_ID], capture_output=True)
        run('xcrun', 'simctl', 'install', args.device, str(app))
        container = Path(subprocess.check_output(['xcrun', 'simctl', 'get_app_container', args.device, BUNDLE_ID, 'data'], text=True).strip())
        result = container / 'Documents/hero-exits.json'
        result.unlink(missing_ok=True)
        run('xcrun', 'simctl', 'launch', args.device, BUNDLE_ID)
        deadline = time.monotonic() + 420
        while not result.exists() and time.monotonic() < deadline:
            time.sleep(0.25)
        assert result.exists(), 'Runner check did not finish'
        args.output.mkdir(parents=True, exist_ok=True)
        shutil.copy2(result, args.output / result.name)
        for proof in (container / 'Documents').glob('level-*.png'):
            shutil.copy2(proof, args.output / proof.name)
        data = json.loads(result.read_text())
        assert data['passed'], f"After {len(data.get('checks', []))} loads: {data.get('error')}"
        print(f"Passed {data['loads']} actual LevelRunner loads: {args.output}")


if __name__ == '__main__':
    main()
