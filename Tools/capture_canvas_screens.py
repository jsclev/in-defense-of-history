#!/usr/bin/env python3
"""Capture actual SwiftUI screens with a disposable simulator app and asset bundle."""
import argparse
import plistlib
import shutil
import subprocess
import tempfile
import time
from pathlib import Path

GAME = Path(__file__).resolve().parents[1]
ID = 'com.zippyzen.canvas-screen-probe'

def run(*args):
    return subprocess.run(args, text=True, check=True)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--resources', required=True, type=Path, help='Built device app containing Assets.car and bundled database')
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='td-canvas-screen-') as tmp:
        temp = Path(tmp)
        app = temp / 'CanvasScreenProbe.app'
        app.mkdir()
        for name in ['Assets.car', 'in_defense_of_history.sqlite']:
            shutil.copy2(args.resources / name, app / name)
        shutil.copytree(args.resources / 'LevelMaps', app / 'LevelMaps')
        info = dict(CFBundleIdentifier=ID, CFBundleExecutable='CanvasScreenProbe', CFBundleName='CanvasScreenProbe',
            CFBundlePackageType='APPL', CFBundleVersion='1', CFBundleShortVersionString='1.0',
            MinimumOSVersion='26.5', UIDeviceFamily=[1, 2], UILaunchScreen={},
            UISupportedInterfaceOrientations=['UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight'])
        (app/'Info.plist').write_bytes(plistlib.dumps(info))
        omit = {'LibertyLineApp.swift', 'RootView.swift', 'Renderer.swift', 'TiledBackgroundMetalView.swift',
                'CampaignMapMetalView.swift', 'CampaignMapView.swift'}
        sources = sorted(GAME.glob('Engine/**/*.swift')) + [p for p in sorted(GAME.glob('Liberty Line/**/*.swift')) if p.name not in omit]
        sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
        run('swiftc', '-swift-version', '5', '-module-cache-path', str(temp/'cache'), '-parse-as-library',
            '-target', 'arm64-apple-ios26.5-simulator', '-sdk', sdk,
            str(GAME/'Tools/CanvasScreenProbe.swift'), *map(str, sources), '-o', str(app/'CanvasScreenProbe'))
        run('codesign', '--force', '--sign', '-', '--timestamp=none', str(app))
        subprocess.run(['xcrun', 'simctl', 'terminate', args.device, ID], capture_output=True)
        run('xcrun', 'simctl', 'install', args.device, str(app))
        container = Path(subprocess.check_output(['xcrun', 'simctl', 'get_app_container', args.device, ID, 'data'], text=True).strip())
        complete = container/'Documents/complete.txt'
        complete.unlink(missing_ok=True)
        run('xcrun', 'simctl', 'launch', args.device, ID)
        deadline = time.monotonic()+40
        while not complete.exists() and time.monotonic() < deadline:
            time.sleep(0.3)
        assert complete.exists(), 'Screen capture did not complete'
        args.output.mkdir(parents=True, exist_ok=True)
        for image in (container/'Documents').glob('*.png'):
            shutil.copy2(image, args.output/image.name)
        print(f'Captured 7 production screens at 1x and 3x: {args.output}')

if __name__ == '__main__':
    main()
