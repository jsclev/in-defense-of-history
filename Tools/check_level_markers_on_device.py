#!/usr/bin/env python3
"""Verify GeoJSON marker alignment using production SwiftUI views on a physical iPhone."""
import argparse
import hashlib
import json
import shutil
import subprocess
import tempfile
import time
import uuid
from pathlib import Path

from PIL import Image

GAME = Path(__file__).resolve().parents[1]
BUNDLE_ID = 'com.zippyzen.level-marker-probe'


def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    run_id = str(uuid.uuid4())
    with tempfile.TemporaryDirectory(prefix='td-marker-device-') as tmp:
        temp = Path(tmp)
        root = temp / GAME.name
        root.mkdir()
        (temp / 'in-defense-of-history-data').symlink_to(GAME.parent / 'in-defense-of-history-data')
        for source in GAME.iterdir():
            if source.name in {'.git', '.codex', '.agents', 'build', '.build', 'Tools', 'Tests'}:
                continue
            target = root / source.name
            if source.name in {'Liberty Line', 'InDefenseOfHistory.xcodeproj', 'Versioning'}:
                shutil.copytree(source, target)
            else:
                target.symlink_to(source)
        shutil.copytree(GAME / 'Tools', root / 'Tools', ignore=shutil.ignore_patterns('reports', '__pycache__'))
        (root / 'Liberty Line/LibertyLineApp.swift').write_text((GAME / 'Tools/LevelMarkerRuntimeProbe.swift').read_text())
        build = temp / 'build'
        with (output / 'device-build.log').open('w') as log:
            run('xcodebuild', '-project', str(root / 'InDefenseOfHistory.xcodeproj'),
                '-scheme', 'Liberty Line', '-configuration', 'Debug', '-destination', f'id={args.device}',
                '-derivedDataPath', str(build), '-allowProvisioningUpdates',
                f'PRODUCT_BUNDLE_IDENTIFIER={BUNDLE_ID}', 'INFOPLIST_KEY_CFBundleDisplayName=Marker Check',
                'build', stdout=log, stderr=subprocess.STDOUT)
        app = build / 'Build/Products/Debug-iphoneos/Liberty Line.app'
        run('xcrun', 'devicectl', 'device', 'install', 'app', '--device', args.device, str(app))
        run('xcrun', 'devicectl', 'device', 'process', 'launch', '--device', args.device,
            '--terminate-existing', BUNDLE_ID, '--probe-run-id', run_id)
        ready = output / 'captures-ready.txt'
        deadline = time.monotonic() + 180
        while time.monotonic() < deadline:
            copy = subprocess.run(['xcrun', 'devicectl', 'device', 'copy', 'from', '--device', args.device,
                '--domain-type', 'appDataContainer', '--domain-identifier', BUNDLE_ID,
                '--source', 'Documents/captures-ready.txt', '--destination', str(ready)], capture_output=True)
            if copy.returncode == 0 and ready.exists() and ready.read_text() == run_id:
                break
            time.sleep(3)
        assert ready.exists() and ready.read_text() == run_id, 'Physical-device captures did not finish'
        documents = output / 'device-documents'
        run('xcrun', 'devicectl', 'device', 'copy', 'from', '--device', args.device,
            '--domain-type', 'appDataContainer', '--domain-identifier', BUNDLE_ID,
            '--source', 'Documents', '--destination', str(documents))
        data = json.loads((documents / 'marker-placement.json').read_text())
        assert data['passed'] and data['runID'] == run_id, data
        geo = GAME / 'Db/level_15_charleston.geojson'
        path = GAME.parent / 'in-defense-of-history-data/Levels/level_15_charleston_path.png'
        assert data['geoJSONSHA256'] == hashlib.sha256(geo.read_bytes()).hexdigest(), 'Bundled GeoJSON is stale'
        assert data['pathSHA256'] == hashlib.sha256(path.read_bytes()).hexdigest(), 'Bundled path image is stale'
        for row in data['checks']:
            alpha = Image.open(documents / row['image']).convert('RGBA').getchannel('A')
            box = alpha.point(lambda v: 255 if v >= 128 else 0).getbbox()
            assert box, f"Empty marker render: {row['image']}"
            center = [(box[i] + box[i + 2]) / 2 / row['density'] - row['padding'] for i in (0, 1)]
            delta = [center[i] - row['center'][i] for i in (0, 1)]
            row['renderedAlphaCenter'] = center
            row['centerErrorPoints'] = delta
            # Tight source alpha bounds and pixel rounding allow at most 1 point.
            assert max(map(abs, delta)) <= 1, f"Visible marker shifted: {row}"
        (output / 'verified-placement.json').write_text(json.dumps(data, indent=2) + '\n')
        print(f"Passed {len(data['checks'])} actual SwiftUI marker renders on physical iPhone: {output}")


if __name__ == '__main__':
    main()
