#!/usr/bin/env python3
"""Review device-resolved starts using the existing calibrated readability lab."""
import argparse
import json
import subprocess
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageOps

GAME = Path(__file__).resolve().parents[1]
DATA = GAME.parent / 'in-defense-of-history-data'
sys.path.insert(0, str(DATA / 'ArtReadability'))
import build_readability_lab as lab


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--probe', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    layers = output / 'layers'
    layers.mkdir(parents=True, exist_ok=True)
    config = lab.project_manifest()
    config['assets'] = [a for a in config['assets'] if a['id'] in ('henry_knox', 'george_washington')]
    for asset in config['assets']:
        idle = asset['states']['s']['idle']
        asset['states'] = {d: {'idle': idle, 'walk': idle} for d in lab.DIRECTIONS}
    inputs = []
    for suffix in ('', '_path', '_overlay', '_forest_occlusion', '_occlusion'):
        name = 'level_15_charleston' + suffix
        source = next((DATA / 'Levels' / (name + ext) for ext in ('.heic', '.png')
                       if (DATA / 'Levels' / (name + ext)).exists()), None)
        if source is None:
            continue
        target = layers / ('charleston' + suffix + '.png')
        subprocess.run(['sips', '-s', 'format', 'png', str(source), '--out', str(target)],
                       check=True, stdout=subprocess.DEVNULL)
        inputs.append({'path': str(source), 'sha256': lab.digest(source)})
    config['maps'] = [{'id': 'charleston', 'label': 'Charleston', 'base': str(layers / 'charleston.png')}]
    (output / 'lab-input.json').write_text(json.dumps(config, indent=2) + '\n')
    lab.build(config, output / 'lab')
    data = json.loads(args.probe.read_text())
    row = next(r for r in data['checks'] if r['level'] == 15 and r['scenario'] == 'pair' and r['viewport'] == 'minimum')
    under = Image.open(layers / 'charleston.png').convert('RGBA')
    over = Image.new('RGBA', under.size)
    for suffix in ('_path', '_overlay', '_forest_occlusion', '_occlusion'):
        source = layers / ('charleston' + suffix + '.png')
        if source.exists():
            (over if 'occlusion' in suffix else under).alpha_composite(Image.open(source).convert('RGBA'))
    x, y, w, h = config['canvas']['play_rect']
    ch = config['canvas']['height']
    crop = (round(x), round(ch-y-h), round(x+w), round(ch-y))
    for density in (1, 2, 3):
        scale = 340 / h * density
        size = (round(w * scale), 340 * density)
        for state, key in [('before', 'exitPosition'), ('after', 'position')]:
            scene = lab.resize_rgba(under.crop(crop), size)
            for placement in row['heroes']:
                asset = next(a for a in config['assets'] if a['label'] == placement['hero'])
                name = asset['states']['s']['idle'][0]
                sprite = lab.thumbnail(Image.open(lab.asset_path(name, density)).convert('RGBA'),
                                       lab.height(asset, config, 340) * density)
                px, py = placement[key]
                lab.put(scene, sprite, (px-x)*scale,
                        (y+h-py)*scale + sprite.height*asset.get('ground_inset_fraction', 0))
            scene.alpha_composite(lab.resize_rgba(over.crop(crop), size))
            scene.save(output / f'{state}-minimum@{density}x.png')
            ImageOps.grayscale(scene).save(output / f'{state}-gray-minimum@{density}x.png')
    before = Image.open(output / 'before-minimum@1x.png')
    after = Image.open(output / 'after-minimum@1x.png')
    comparison = Image.new('RGB', (before.width, 728), '#eeeade')
    draw = ImageDraw.Draw(comparison)
    draw.text((8, 6), 'BEFORE / exact exit / 340 pt playable height', fill='#252525')
    comparison.paste(before, (0, 24))
    draw.text((8, 370), 'AFTER / first clear station inside exit / same scale', fill='#252525')
    comparison.paste(after, (0, 388))
    comparison.save(output / 'before-after-minimum.png')
    (output / 'placement-evidence.json').write_text(json.dumps({
        'inputs': inputs, 'probe': str(args.probe.resolve()), 'placements': row,
        'minimumPlayableHeight': 340, 'densities': [1, 2, 3],
        'renderer': 'Calibrated Pillow lab; device-resolved positions and actual layers. Device capture verifies SwiftUI.'
    }, indent=2) + '\n')


if __name__ == '__main__':
    main()
