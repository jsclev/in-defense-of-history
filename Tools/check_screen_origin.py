#!/usr/bin/env python3
"""UIKit regression: verify the production screen/viewport origin on a booted iOS simulator.

Example: python3 Tools/check_screen_origin.py --device <simulator-udid>
Uses a separate disposable probe app; it never opens the game's database/saves.
"""
import argparse
import json
import plistlib
import subprocess
import tempfile
import time
import uuid
from pathlib import Path

GAME = Path(__file__).resolve().parent.parent
BUNDLE_ID = 'com.zippyzen.viewport-origin-probe'

def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True, help='Booted iOS 26.5+ simulator UDID')
    parser.add_argument('--output', type=Path, default=Path('/tmp/td-screen-origin-results.json'))
    args = parser.parse_args()
    sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
    token = str(uuid.uuid4())
    with tempfile.TemporaryDirectory(prefix='td-screen-origin-') as directory:
        temp = Path(directory)
        app = temp / 'OriginProbe.app'
        app.mkdir()
        info = dict(CFBundleIdentifier=BUNDLE_ID, CFBundleExecutable='OriginProbe',
                    CFBundleName='OriginProbe', CFBundlePackageType='APPL', CFBundleVersion='1',
                    CFBundleShortVersionString='1.0', MinimumOSVersion='26.5', UIDeviceFamily=[1, 2],
                    UISupportedInterfaceOrientations=['UIInterfaceOrientationLandscapeLeft',
                                                       'UIInterfaceOrientationLandscapeRight'],
                    UILaunchScreen={})
        (app/'Info.plist').write_bytes(plistlib.dumps(info))
        run('swiftc', '-module-cache-path', str(temp/'cache'), '-parse-as-library',
            '-target', 'arm64-apple-ios26.5-simulator', '-sdk', sdk,
            str(GAME/'Tools/ScreenOriginProbe.swift'),
            str(GAME/'Engine/Layout/LevelViewport.swift'),
            str(GAME/'Engine/Layout/ScreenCanvas.swift'), '-o', str(app/'OriginProbe'))
        run('codesign', '--force', '--sign', '-', '--timestamp=none', str(app))
        subprocess.run(['xcrun', 'simctl', 'terminate', args.device, BUNDLE_ID],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        run('xcrun', 'simctl', 'install', args.device, str(app))
        run('xcrun', 'simctl', 'launch', args.device, BUNDLE_ID, token)
        container = Path(subprocess.check_output(
            ['xcrun', 'simctl', 'get_app_container', args.device, BUNDLE_ID, 'data'], text=True).strip())
        result_file = container/'Documents/origin-results.json'
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            try:
                rows = json.loads(result_file.read_text())
                if len(rows) == 9 and all(row.get('runID') == token for row in rows):
                    break
            except (OSError, json.JSONDecodeError):
                pass
            time.sleep(0.25)
        else:
            raise RuntimeError('Simulator did not complete the origin probe')
        fixed = [row for row in rows if row['phase'].startswith('mode-2-')]
        assert len(fixed) == 3
        for row in fixed:
            width, height = row['window']
            for layer in ['stage', 'map', 'hud']:
                assert row['frames'][layer] == [0, 0, width, height], (row['phase'], layer, row['frames'][layer])
            assert row['frames']['map-marker'] == [94, 94, 12, 12], row
            for button in ['speed', 'pause']:
                assert row['frames'][button][1] == row['measuredTop'] + 7, row
        assert all(row['frames'] == fixed[0]['frames'] for row in fixed)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(rows, indent=2) + '\n')
        print(f'PASS: UIKit window origin (0,0), correct control margin, and no wave-toggle movement. {args.output}')

if __name__ == '__main__':
    main()
