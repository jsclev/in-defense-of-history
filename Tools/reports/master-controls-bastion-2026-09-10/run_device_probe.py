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
BUNDLE_ID = 'com.zippyzen.master-controls-art-probe'
RUN_ID = str(uuid.uuid4())

def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)

with tempfile.TemporaryDirectory(prefix='td-controls-probe-') as temp_name:
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
    (root / 'Liberty Line/LibertyLineApp.swift').write_text((REPORT / 'MasterControlsProbe.swift').read_text().replace('PROBE_RUN_ID', RUN_ID) + '\n' + helpers)
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
    inputs = [GAME / 'Liberty Line/Level Views/HUD/HudMasterControlsView.swift', GAME / 'Engine/Layout/MasterControlsLayout.swift', GAME / 'Engine/Layout/HeroBarLayout.swift', GAME / 'Liberty Line/Level Views/HUD/HeroHUDButton.swift', GAME / 'Liberty Line/Level Views/HUD/HudHeroesBarView.swift', GAME / 'Engine/Layout/HudSizing.swift', GAME / 'Liberty Line/Level Views/HUD/HudButtonView.swift', GAME / 'Liberty Line/Level Views/HUD/ReinforcementButton.swift', GAME / 'Liberty Line/Level Views/HUD/CallWaveButtonView.swift', GAME / 'Liberty Line/Level Views/LevelMapView.swift', GAME / 'Engine/Models/TowerKind.swift', GAME / 'Engine/Layout/TowerMenuLayout.swift']
    names = ['hud_speed_up_framed','hud_back_to_main_framed','action_icon_call_reinforcements','hud_misc_sack_blue_frame','tower_menu_square_frame','hero_icon_george_washington','hero_icon_henry_knox','hud_hero_henry_knox_framed','hud_hero_george_washington_framed']
    for name in names:
        inputs += list((GAME.parent / 'in-defense-of-history-data/LibertyLineAssets.xcassets' / f'{name}.imageset').glob('*'))
    (REPORT / 'tested-source-hashes.json').write_text(json.dumps({str(f): hashlib.sha256(f.read_bytes()).hexdigest() for f in inputs}, indent=2))
    build = temp / 'build'
    with (REPORT / 'probe-build.log').open('w') as log:
        run('xcodebuild', '-project', str(root / 'InDefenseOfHistory.xcodeproj'), '-scheme', 'Liberty Line',
            '-configuration', 'Debug', '-destination', f'id={DEVICE}', '-derivedDataPath', str(build),
            '-allowProvisioningUpdates', f'PRODUCT_BUNDLE_IDENTIFIER={BUNDLE_ID}',
            'INFOPLIST_KEY_CFBundleDisplayName=HUD Controls Check', 'build', stdout=log, stderr=subprocess.STDOUT)
    app = build / 'Build/Products/Debug-iphoneos/Liberty Line.app'
    run('xcrun', 'devicectl', 'device', 'install', 'app', '--device', DEVICE, str(app))
    run('xcrun', 'devicectl', 'device', 'process', 'launch', '--device', DEVICE, '--terminate-existing', BUNDLE_ID)
    result = REPORT / 'hud-check.json'
    deadline = time.monotonic() + 240
    while time.monotonic() < deadline:
        copied = subprocess.run(['xcrun', 'devicectl', 'device', 'copy', 'from', '--device', DEVICE,
            '--domain-type', 'appDataContainer', '--domain-identifier', BUNDLE_ID,
            '--source', 'Documents/hud-check.json', '--destination', str(result)], capture_output=True)
        if copied.returncode == 0 and result.exists() and json.loads(result.read_text()).get("runID") == RUN_ID:
            break
        time.sleep(3)
    assert result.exists(), 'Physical-device probe timed out'
    data = json.loads(result.read_text())
    assert data.get('runID') == RUN_ID and data['passed'], data
    run('xcrun', 'devicectl', 'device', 'copy', 'from', '--device', DEVICE,
        '--domain-type', 'appDataContainer', '--domain-identifier', BUNDLE_ID,
        '--source', 'Documents', '--destination', str(REPORT / 'device-documents'))
    print("PASS: production speed and home buttons and live HUD captured at minimum and device sizes.")
