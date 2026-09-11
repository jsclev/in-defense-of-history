#!/usr/bin/env python3
"""Run the UI-free production hero movement regression and campaign integration tests."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--scratch-path', type=Path, default=Path('/tmp/td-hero-movement-tests'))
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    command = ['swift', 'test', '--disable-sandbox', '--scratch-path', str(args.scratch_path),
               '--filter', 'HeroMovement']
    environment = dict(os.environ)
    environment.setdefault('CLANG_MODULE_CACHE_PATH', '/tmp/td-hero-clang-cache')
    environment.setdefault('SWIFTPM_MODULECACHE_OVERRIDE', '/tmp/td-hero-swift-cache')
    result = subprocess.run(command, cwd=ROOT, env=environment, capture_output=True, text=True)
    log = args.output / 'tests.log'
    log.write_text(result.stdout + result.stderr)
    sources = [ROOT / path for path in [
        'Engine/Models/HeroMovementArea.swift', 'Engine/Models/HeroMovement.swift',
        'Engine/Layout/MapDestinationInput.swift',
        'Engine/Persistence/Data Access Objects/LevelGeoJSONDAO.swift',
        'Liberty Line/LevelRunner.swift', 'Liberty Line/Level Views/HeroMapLayer.swift',
        'Liberty Line/Level Views/MapDestinationInputView.swift',
        'Tests/LevelEditorFormatsTests/HeroMovementTests.swift',
        'Tests/LevelEditorFormatsTests/HeroMovementIntegrationTests.swift',
    ]] + sorted((ROOT / 'Db').glob('*.geojson'))
    report = dict(passed=result.returncode == 0, command=command,
                  sources={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},
                  limitation='Host tests invoke the production model and input projection; no iPhone touch-delivery claim.')
    (args.output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f"{'PASS' if report['passed'] else 'FAIL'}: hero movement model and all 15 campaign maps; see {log}")
    raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
