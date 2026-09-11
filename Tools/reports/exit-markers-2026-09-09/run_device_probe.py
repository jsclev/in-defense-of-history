"""Run the production exit loader and views in a separate physical-iPhone app."""
import json
import shutil
import subprocess
import tempfile
import time
from pathlib import Path

REPORT = Path(__file__).resolve().parent
GAME = REPORT.parents[2]
DEVICE = '00008130-000161D93E82001C'
BUNDLE_ID = 'com.zippyzen.exit-marker-probe'

def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)

with tempfile.TemporaryDirectory(prefix='td-exit-probe-') as temp_name:
    temp = Path(temp_name)
    root = temp / GAME.name
    root.mkdir()
    (temp / 'in-defense-of-history-data').symlink_to(GAME.parent / 'in-defense-of-history-data')
    for source in GAME.iterdir():
        if source.name in {'.git', '.codex', '.agents', '.build', 'build', 'Tools', 'Tests'}:
            continue
        target = root / source.name
        if source.name in {'Liberty Line', 'InDefenseOfHistory.xcodeproj', 'Versioning'}:
            shutil.copytree(source, target)
        else:
            target.symlink_to(source)
    shutil.copytree(GAME / 'Tools', root / 'Tools', ignore=shutil.ignore_patterns('reports', '__pycache__'))
    original = (root / 'Liberty Line/LibertyLineApp.swift').read_text()
    helpers = original[original.index('@MainActor\nfinal class OrientationLock'):]
    (root / 'Liberty Line/LibertyLineApp.swift').write_text((REPORT / 'ExitMarkerProbe.swift').read_text() + '\n' + helpers)
    build = temp / 'build'
    with (REPORT / 'probe-build.log').open('w') as log:
        run('xcodebuild', '-project', str(root / 'InDefenseOfHistory.xcodeproj'), '-scheme', 'Liberty Line',
            '-configuration', 'Debug', '-destination', f'id={DEVICE}', '-derivedDataPath', str(build),
            '-allowProvisioningUpdates', f'PRODUCT_BUNDLE_IDENTIFIER={BUNDLE_ID}',
            'INFOPLIST_KEY_CFBundleDisplayName=Exit Marker Check', 'build', stdout=log, stderr=subprocess.STDOUT)
    app = build / 'Build/Products/Debug-iphoneos/Liberty Line.app'
    run('xcrun', 'devicectl', 'device', 'install', 'app', '--device', DEVICE, str(app))
    # Installing a newer probe preserves its Documents directory. Invalidate the
    # old completion record before launch so a repeat cannot pass on stale data.
    pending = temp / 'pending.json'
    pending.write_text(json.dumps({'pending': True}))
    run('xcrun', 'devicectl', 'device', 'copy', 'to', '--device', DEVICE,
        '--domain-type', 'appDataContainer', '--domain-identifier', BUNDLE_ID,
        '--source', str(pending), '--destination', 'Documents/exit-markers.json')
    run('xcrun', 'devicectl', 'device', 'process', 'launch', '--device', DEVICE, '--terminate-existing', BUNDLE_ID)
    result = REPORT / 'exit-markers.json'
    deadline = time.monotonic() + 240
    while time.monotonic() < deadline:
        copied = subprocess.run(['xcrun', 'devicectl', 'device', 'copy', 'from', '--device', DEVICE,
            '--domain-type', 'appDataContainer', '--domain-identifier', BUNDLE_ID,
            '--source', 'Documents/exit-markers.json', '--destination', str(result)], capture_output=True)
        if copied.returncode == 0 and result.exists() and not json.loads(result.read_text()).get('pending'):
            break
        time.sleep(3)
    assert result.exists() and not json.loads(result.read_text()).get('pending'), 'Physical-device probe timed out'
    data = json.loads(result.read_text())
    assert data['passed'], data
    run('xcrun', 'devicectl', 'device', 'copy', 'from', '--device', DEVICE,
        '--domain-type', 'appDataContainer', '--domain-identifier', BUNDLE_ID,
        '--source', 'Documents', '--destination', str(REPORT / 'device-documents'))
    print(f"PASS: {sum(x['count'] for x in data['levels'])} authored exits across {len(data['levels'])} levels; physical-iPhone renders saved.")
