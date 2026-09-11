#!/usr/bin/env python3
"""UIKit regression: verify live RuntimeCanvas updates and stable screen sizing.

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
BUNDLE_ID = 'com.zippyzen.runtime-canvas-probe'

def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True, help='Booted iOS 26.5+ simulator UDID')
    parser.add_argument('--output', type=Path, default=Path('/tmp/td-runtime-canvas-results.json'))
    args = parser.parse_args()
    sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
    token = str(uuid.uuid4())
    with tempfile.TemporaryDirectory(prefix='td-runtime-canvas-') as directory:
        temp = Path(directory)
        app = temp / 'RuntimeCanvasProbe.app'
        app.mkdir()
        info = dict(CFBundleIdentifier=BUNDLE_ID, CFBundleExecutable='RuntimeCanvasProbe',
                    CFBundleName='RuntimeCanvasProbe', CFBundlePackageType='APPL', CFBundleVersion='1',
                    CFBundleShortVersionString='1.0', MinimumOSVersion='26.5', UIDeviceFamily=[1, 2],
                    UISupportedInterfaceOrientations=['UIInterfaceOrientationLandscapeLeft',
                                                       'UIInterfaceOrientationLandscapeRight'],
                    UILaunchScreen={})
        (app/'Info.plist').write_bytes(plistlib.dumps(info))
        run('swiftc', '-module-cache-path', str(temp/'cache'), '-parse-as-library',
            '-target', 'arm64-apple-ios26.5-simulator', '-sdk', sdk,
            str(GAME/'Tools/RuntimeCanvasProbe.swift'),
            str(GAME/'Engine/Layout/LevelViewport.swift'),
            str(GAME/'Engine/Layout/ScreenCanvas.swift'),
            str(GAME/'Engine/Layout/RuntimeCanvasView.swift'),
            str(GAME/'Engine/Core/RuntimeCanvas.swift'),
            str(GAME/'Engine/Design/VirtualCanvas.swift'),
            str(GAME/'Liberty Line/WindowReader.swift'),
            str(GAME/'Liberty Line/ScreenGeometry+SwiftUI.swift'), '-o', str(app/'RuntimeCanvasProbe'))
        run('codesign', '--force', '--sign', '-', '--timestamp=none', str(app))
        subprocess.run(['xcrun', 'simctl', 'terminate', args.device, BUNDLE_ID],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        run('xcrun', 'simctl', 'install', args.device, str(app))
        run('xcrun', 'simctl', 'launch', args.device, BUNDLE_ID, token)
        container = Path(subprocess.check_output(
            ['xcrun', 'simctl', 'get_app_container', args.device, BUNDLE_ID, 'data'], text=True).strip())
        result_file = container/'Documents/runtime-canvas-results.json'
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            try:
                rows = json.loads(result_file.read_text())
                if len(rows) == 4 and all(row.get('runID') == token for row in rows):
                    break
            except (OSError, json.JSONDecodeError):
                pass
            time.sleep(0.25)
        else:
            raise RuntimeError('Simulator did not complete the origin probe')
        identities = set()
        for row in rows:
            window = row['window']
            canvas = row['canvas']
            assert canvas['physical'] == window, row
            assert canvas['safe'] == row['safe'], row
            for layer in ['map', 'screen']:
                assert row['frames'][layer] == window, row
            x, y, width, height = canvas['play']
            marker = row['frames']['marker']
            expected = [x + width / 2 - 6, y + height / 2 - 6, 12, 12]
            assert all(abs(a - b) < 0.01 for a, b in zip(marker, expected)), row
            identities.add(canvas['identity'])
        assert len(identities) == 1, 'Canvas changes recreated the stateful screen'
        assert rows[0]['window'] != rows[2]['window'], 'Resize fixture did not resize the window'
        assert rows[0]['canvas']['play'] != rows[2]['canvas']['play'], 'Playable area did not refresh'
        assert rows[0]['frames'] == rows[1]['frames'] == rows[3]['frames'], rows
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(rows, indent=2) + '\n')
        print(f'PASS: live window/safe-area measurement, stable root/map frames, preserved screen state. {args.output}')

if __name__ == '__main__':
    main()
