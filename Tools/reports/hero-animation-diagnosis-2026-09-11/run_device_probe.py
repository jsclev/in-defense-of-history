"""Trace production hero frame selection and render current art on a physical iPhone."""
import json
import re
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
BUNDLE_ID = 'com.zippyzen.hero-animation-probe'
RUN_ID = str(uuid.uuid4())

def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)

with tempfile.TemporaryDirectory(prefix='td-ranged-probe-') as temp_name:
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
    (root / 'Liberty Line/LibertyLineApp.swift').write_text((REPORT / 'HeroAnimationProbe.swift').read_text().replace('PROBE_RUN_ID', RUN_ID) + '\n' + helpers)
    # Reuse the current game's compiled catalog for this HUD-art probe.
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
    runner = root / 'Liberty Line/LevelRunner.swift'
    with runner.open('a') as f:
        f.write((REPORT / 'RunnerProbeExtension.swift.txt').read_text())
    references = []
    for hero, frames in [('george_washington', [0, 4, 8, 12, 15]), ('henry_knox', [0, 8, 16, 24, 32, 40, 48, 56])]:
        for facing in ['e', 'se']:
            for frame in frames:
                name = f'hero_unit_{hero}_walk_{facing}_{frame}'
                source = GAME.parent / f'in-defense-of-history-data/LibertyLineAssets.xcassets/{name}.imageset/{name}@3x.png'
                filename = f'animation-reference-{len(references)}.png'
                shutil.copy2(source, root / 'Liberty Line' / filename)
                references.append({'name': name, 'file': filename})
    (root / 'Liberty Line/animation-references.json').write_text(json.dumps(references))
    inputs = [GAME / 'Engine/Models/UnitFacing.swift', GAME / 'Liberty Line/LevelRunner.swift', GAME / 'Liberty Line/Level Views/HeroMapLayer.swift']
    (REPORT / 'tested-source-hashes.json').write_text(json.dumps({str(f): hashlib.sha256(f.read_bytes()).hexdigest() for f in inputs}, indent=2))
    build = temp / 'build'
    with (REPORT / 'probe-build.log').open('w') as log:
        run('xcodebuild', '-project', str(root / 'InDefenseOfHistory.xcodeproj'), '-scheme', 'Liberty Line',
            '-configuration', 'Debug', '-destination', f'id={DEVICE}', '-derivedDataPath', str(build),
            '-allowProvisioningUpdates', f'PRODUCT_BUNDLE_IDENTIFIER={BUNDLE_ID}',
            'INFOPLIST_KEY_CFBundleDisplayName=Hero Animation Check', 'build', stdout=log, stderr=subprocess.STDOUT)
    app = build / 'Build/Products/Debug-iphoneos/Liberty Line.app'
    for source in (root / 'Liberty Line').glob('animation-ref*'):
        shutil.copy2(source, app / source.name)
    signing_identity = re.search(r'codesign --force --sign ([A-F0-9]+)', (REPORT / 'probe-build.log').read_text())[1]
    run('/usr/bin/codesign', '--force', '--sign', signing_identity,
        '--preserve-metadata=entitlements,requirements,flags,runtime', str(app))
    run('xcrun', 'devicectl', 'device', 'install', 'app', '--device', DEVICE, str(app))
    run('xcrun', 'devicectl', 'device', 'process', 'launch', '--device', DEVICE, '--terminate-existing', BUNDLE_ID)
    result = REPORT / 'animation-check.json'
    deadline = time.monotonic() + 240
    while time.monotonic() < deadline:
        copied = subprocess.run(['xcrun', 'devicectl', 'device', 'copy', 'from', '--device', DEVICE,
            '--domain-type', 'appDataContainer', '--domain-identifier', BUNDLE_ID,
            '--source', 'Documents/animation-check.json', '--destination', str(result)], capture_output=True)
        if copied.returncode == 0 and result.exists() and json.loads(result.read_text()).get("runID") == RUN_ID:
            break
        time.sleep(3)
    assert result.exists(), 'Physical-device probe timed out'
    data = json.loads(result.read_text())
    assert data.get('runID') == RUN_ID and data['passed'], data
    run('xcrun', 'devicectl', 'device', 'copy', 'from', '--device', DEVICE,
        '--domain-type', 'appDataContainer', '--domain-identifier', BUNDLE_ID,
        '--source', 'Documents', '--destination', str(REPORT / 'device-documents'))
    print("PASS: physical iPhone hero frame trace, compiled pixels, and minimum-size animation captured.")
