"""Render the production painted paths and gameplay views in a separate physical-iPhone app."""
import json
import hashlib
import shutil
import subprocess
import tempfile
import time
import uuid
from pathlib import Path

REPORT = Path(__file__).resolve().parent
GAME = REPORT.parents[2]
DEVICE = '00008130-000161D93E82001C'
BUNDLE_ID = 'com.zippyzen.charleston-geometry-probe'
RUN_ID = str(uuid.uuid4())

def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)

with tempfile.TemporaryDirectory(prefix='td-path-probe-') as temp_name:
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
    (root / 'Liberty Line/LibertyLineApp.swift').write_text((REPORT / 'PathProbe.swift').read_text().replace('PROBE_RUN_ID', RUN_ID).replace('PROBE_GEO_SHA', hashlib.sha256((GAME / 'Db/level_15_charleston.geojson').read_bytes()).hexdigest()).replace('PROBE_PATH_SHA', hashlib.sha256((GAME.parent / 'in-defense-of-history-data/Levels/level_15_charleston_path.png').read_bytes()).hexdigest()) + '\n' + helpers)
    # Reuse the current game's compiled catalog for this terrain-only probe.
    # The final production build runs actool and validates these renditions.
    compiled = Path('/private/tmp/td-runtime-canvas-device-build/Build/Products/Debug-iphoneos/Liberty Line.app/Assets.car')
    if compiled.exists():
        shutil.copy2(compiled, root / 'Assets.car')
        project = root / 'InDefenseOfHistory.xcodeproj/project.pbxproj'
        source = project.read_text()
        source = source.replace('lastKnownFileType = folder.assetcatalog; name = LibertyLineAssets.xcassets; path = "../in-defense-of-history-data/LibertyLineAssets.xcassets";',
            'lastKnownFileType = file; name = Assets.car; path = Assets.car;')
        project.write_text(source)
        (REPORT / 'compiled-catalog.json').write_text(json.dumps({'source': str(compiled), 'sha256': hashlib.sha256(compiled.read_bytes()).hexdigest()}, indent=2))
    (REPORT / 'tested-path-sha256.txt').write_text(hashlib.sha256((GAME.parent / 'in-defense-of-history-data/Levels/level_15_charleston_path.png').read_bytes()).hexdigest()+'\n')
    build = temp / 'build'
    with (REPORT / 'probe-build.log').open('w') as log:
        run('xcodebuild', '-project', str(root / 'InDefenseOfHistory.xcodeproj'), '-scheme', 'Liberty Line',
            '-configuration', 'Debug', '-destination', f'id={DEVICE}', '-derivedDataPath', str(build),
            '-allowProvisioningUpdates', f'PRODUCT_BUNDLE_IDENTIFIER={BUNDLE_ID}',
            'INFOPLIST_KEY_CFBundleDisplayName=Path Art Check', 'build', stdout=log, stderr=subprocess.STDOUT)
    app = build / 'Build/Products/Debug-iphoneos/Liberty Line.app'
    assert hashlib.sha256((app / 'level_15_charleston.geojson').read_bytes()).hexdigest() == hashlib.sha256((GAME / 'Db/level_15_charleston.geojson').read_bytes()).hexdigest()
    assert hashlib.sha256((app / 'Levels/level_15_charleston_path.png').read_bytes()).hexdigest() == (REPORT / 'tested-path-sha256.txt').read_text().strip()
    run('xcrun', 'devicectl', 'device', 'install', 'app', '--device', DEVICE, str(app))
    run('xcrun', 'devicectl', 'device', 'process', 'launch', '--device', DEVICE, '--terminate-existing', BUNDLE_ID)
    result = REPORT / 'paths-check.json'
    deadline = time.monotonic() + 240
    while time.monotonic() < deadline:
        copied = subprocess.run(['xcrun', 'devicectl', 'device', 'copy', 'from', '--device', DEVICE,
            '--domain-type', 'appDataContainer', '--domain-identifier', BUNDLE_ID,
            '--source', 'Documents/paths-check.json', '--destination', str(result)], capture_output=True)
        if copied.returncode == 0 and result.exists() and json.loads(result.read_text()).get("runID") == RUN_ID:
            break
        time.sleep(3)
    assert result.exists(), 'Physical-device probe timed out'
    data = json.loads(result.read_text())
    assert data.get('runID') == RUN_ID and data['passed'], data
    run('xcrun', 'devicectl', 'device', 'copy', 'from', '--device', DEVICE,
        '--domain-type', 'appDataContainer', '--domain-identifier', BUNDLE_ID,
        '--source', 'Documents', '--destination', str(REPORT / 'device-documents'))
    assert data['pathHash'] == (REPORT / 'tested-path-sha256.txt').read_text().strip()
    run('xcrun', 'devicectl', 'device', 'uninstall', 'app', '--device', DEVICE, BUNDLE_ID)
    print('PASS: physical-iPhone production map captures and exact path hash; temporary probe removed.')
