from pathlib import Path
import hashlib
import json
import shutil
import subprocess

out = Path(__file__).resolve().parent
game = out.parents[2]
build = Path('/tmp/td-bottom-center-tests/arm64-apple-macosx/debug')
shutil.copy2(game / 'Db/in_defense_of_history.sqlite', out / 'fixture.sqlite')
binary = '/tmp/td-bottom-center-render'
subprocess.run(['swiftc', '-parse-as-library', '-module-cache-path', '/tmp/td-bottom-center-swift-cache',
                '-I', str(build / 'Modules'), str(out / 'render.swift')]
               + [str(p) for p in (build / 'LevelEditorFormats.build').glob('*.swift.o')]
               + ['-o', binary], check=True)
subprocess.run([binary, str(out)], check=True)
files = ['Engine/Design/VirtualCanvas.swift', 'Engine/Core/RuntimeCanvas.swift',
         'Engine/Layout/TowerMenuLayout.swift', 'Engine/Layout/HeroStartingPositionManager.swift',
         'Tests/LevelEditorFormatsTests/BottomCenterOcclusionTests.swift']
(out / 'source-hashes.json').write_text(json.dumps({f: hashlib.sha256((game/f).read_bytes()).hexdigest()
                                                 for f in files}, indent=2) + '\n')

# Consolidate the two measurement batches, including the 11-inch iPad result
# completed while the second batch was already running.
measurements = json.loads((out / 'measurements.json').read_text())
rows = {(m['model'], m['runtime']): m for m in measurements}
for log in ['measure-18.log', 'measure-latest.log']:
    for line in (out / log).read_text().splitlines():
        if line.startswith('{"model":'):
            row = json.loads(line)
            rows[(row['model'], row['runtime'])] = row
(out / 'measurements.json').write_text(json.dumps(list(rows.values()), indent=2) + '\n')
