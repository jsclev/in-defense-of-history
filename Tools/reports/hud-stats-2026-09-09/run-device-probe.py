"""Verify the production HUD and runner in an isolated physical-iPhone app."""
from pathlib import Path
import json, shutil, subprocess, tempfile, time
OUT = Path(__file__).resolve().parent
GAME = OUT.parents[2]
DEVICE = '360E6205-8810-54D7-AA21-4E0D7DAA7BE0'
BUNDLE = 'com.zippyzen.hud-stats-probe'
def run(*args, **kwargs):
    return subprocess.run(args,check=True,**kwargs)
with tempfile.TemporaryDirectory(prefix='td-hud-stats-device-') as tempdir:
    temp = Path(tempdir); root = temp / GAME.name; root.mkdir()
    (temp/'in-defense-of-history-data').symlink_to(GAME.parent/'in-defense-of-history-data')
    for source in GAME.iterdir():
        if source.name in {'.git','.codex','.agents','build','.build','Tools','Tests'}: continue
        target = root/source.name
        if source.name in {'Liberty Line','InDefenseOfHistory.xcodeproj','Versioning'}:
            shutil.copytree(source,target)
        else: target.symlink_to(source)
    shutil.copytree(GAME/'Tools',root/'Tools',ignore=shutil.ignore_patterns('reports','__pycache__'))
    appsource = root/'Liberty Line/LibertyLineApp.swift'
    orientation = appsource.read_text().split('@MainActor\nfinal class OrientationLock')[1]
    appsource.write_text((OUT/'HudStatsRuntimeProbe.swift').read_text()+'\n@MainActor\nfinal class OrientationLock'+orientation)
    with (root/'Liberty Line/LevelRunner.swift').open('a') as f:
        f.write('''
extension LevelRunner {
    func probeWaveProgression() -> [Int] {
        startNextWave()
        var displayed = [currentWaveNumber]
        for index in waves.indices.dropFirst() {
            while currentWaveNumber < index + 1 { timer.advanceTick(); advanceWaveSchedule() }
            precondition(currentWaveNumber == index + 1)
            displayed.append(currentWaveNumber)
        }
        return displayed
    }
    func probeCounterValues() { lives = 1; money = 9999 }
}
''')
    build = temp/'build'
    with (OUT/'device-probe-build.log').open('w') as log:
        run('xcodebuild','-project',str(root/'InDefenseOfHistory.xcodeproj'),'-scheme','Liberty Line','-configuration','Debug','-destination',f'id={DEVICE}','-derivedDataPath',str(build),'-allowProvisioningUpdates',f'PRODUCT_BUNDLE_IDENTIFIER={BUNDLE}','INFOPLIST_KEY_CFBundleDisplayName=HUD Stats Check','build',stdout=log,stderr=subprocess.STDOUT)
    app = build/'Build/Products/Debug-iphoneos/Liberty Line.app'
    run('xcrun','devicectl','device','install','app','--device',DEVICE,str(app))
    run('xcrun','devicectl','device','process','launch','--device',DEVICE,'--terminate-existing',BUNDLE)
    result = OUT/'stats.json'
    for attempt in range(36):
        copied = subprocess.run(['xcrun','devicectl','device','copy','from','--device',DEVICE,'--domain-type','appDataContainer','--domain-identifier',BUNDLE,'--source','Documents/stats.json','--destination',str(result)],capture_output=True)
        if copied.returncode == 0 and result.exists(): break
        time.sleep(5)
    assert result.exists(),'Device check did not finish'
    run('xcrun','devicectl','device','copy','from','--device',DEVICE,'--domain-type','appDataContainer','--domain-identifier',BUNDLE,'--source','Documents','--destination',str(OUT/'device-documents'))
    data = json.loads(result.read_text()); assert data['passed'],data
    print(f"PASS: HUD wave progression across {len(data['levels'])} levels, plus device captures")
