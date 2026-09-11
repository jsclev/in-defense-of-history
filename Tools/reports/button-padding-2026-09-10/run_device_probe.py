"""Render the production ranged towers and menus in a separate physical-iPhone app."""
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
BUNDLE_ID = 'com.zippyzen.button-padding-probe'
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
    (root / 'Liberty Line/LibertyLineApp.swift').write_text((REPORT / 'RangedProbe.swift').read_text().replace('PROBE_RUN_ID', RUN_ID) + '\n' + helpers)
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
    runner_path = root / 'Liberty Line/LevelRunner.swift'
    runner_text = runner_path.read_text()
    assert runner_text.count('            isReady = true') == 1
    runner_text = runner_text.replace('            isReady = true', '            isReady = true\n            RangedProbeState.runner = self')
    runner_text += "\n@MainActor extension LevelRunner { func prepareRangedArtProbe() { money = 100000; towerUnlocks[.ranged] = 4 } }\n"
    runner_path.write_text(runner_text)
    view_path = root / 'Liberty Line/Level Views/LevelMapView.swift'
    view_path.write_text(view_path.read_text() + (REPORT / 'MenuProbe.swift.txt').read_text())
    inputs = [GAME / 'Engine/Layout/HudSizing.swift', GAME / 'Liberty Line/Level Views/HUD/HudButtonView.swift', GAME / 'Liberty Line/Level Views/HUD/ReinforcementButton.swift', GAME / 'Liberty Line/Level Views/HUD/CallWaveButtonView.swift', GAME / 'Liberty Line/Level Views/LevelMapView.swift', GAME / 'Engine/Models/TowerKind.swift', GAME / 'Engine/Layout/TowerMenuLayout.swift']
    names = ['ranged_tower_level_1','ranged_tower_level_2','ranged_tower_level_3'] + [f'ranged_tower_level_4_branch_{x}' for x in (1,2,3)] + ['tower_menu_ranged_square','hud_misc_sack_blue_frame','hud_misc_sack','hud_call_wave','action_icon_call_reinforcements']
    for name in names:
        inputs += list((GAME.parent / 'in-defense-of-history-data/LibertyLineAssets.xcassets' / f'{name}.imageset').glob('*'))
    (REPORT / 'tested-source-hashes.json').write_text(json.dumps({str(f): hashlib.sha256(f.read_bytes()).hexdigest() for f in inputs}, indent=2))
    build = temp / 'build'
    with (REPORT / 'probe-build.log').open('w') as log:
        run('xcodebuild', '-project', str(root / 'InDefenseOfHistory.xcodeproj'), '-scheme', 'Liberty Line',
            '-configuration', 'Debug', '-destination', f'id={DEVICE}', '-derivedDataPath', str(build),
            '-allowProvisioningUpdates', f'PRODUCT_BUNDLE_IDENTIFIER={BUNDLE_ID}',
            'INFOPLIST_KEY_CFBundleDisplayName=Button Padding Check', 'build', stdout=log, stderr=subprocess.STDOUT)
    app = build / 'Build/Products/Debug-iphoneos/Liberty Line.app'
    run('xcrun', 'devicectl', 'device', 'install', 'app', '--device', DEVICE, str(app))
    run('xcrun', 'devicectl', 'device', 'process', 'launch', '--device', DEVICE, '--terminate-existing', BUNDLE_ID)
    result = REPORT / 'ranged-check.json'
    deadline = time.monotonic() + 240
    while time.monotonic() < deadline:
        copied = subprocess.run(['xcrun', 'devicectl', 'device', 'copy', 'from', '--device', DEVICE,
            '--domain-type', 'appDataContainer', '--domain-identifier', BUNDLE_ID,
            '--source', 'Documents/ranged-check.json', '--destination', str(result)], capture_output=True)
        if copied.returncode == 0 and result.exists() and json.loads(result.read_text()).get("runID") == RUN_ID:
            break
        time.sleep(3)
    assert result.exists(), 'Physical-device probe timed out'
    data = json.loads(result.read_text())
    assert data.get('runID') == RUN_ID and data['passed'], data
    run('xcrun', 'devicectl', 'device', 'copy', 'from', '--device', DEVICE,
        '--domain-type', 'appDataContainer', '--domain-identifier', BUNDLE_ID,
        '--source', 'Documents', '--destination', str(REPORT / 'device-documents'))
    print("PASS: all seven ranged assets, real build/upgrade confirmations and production map/menu renders at minimum and device sizes.")
