"""Measure actual iPhone SwiftUI marker pixels against the authored centers."""
import json
import math
from pathlib import Path
from PIL import Image

REPORT = Path(__file__).resolve().parent
DATA = REPORT.parents[3] / 'in-defense-of-history-data'
source = Image.open(DATA / 'LibertyLineAssets.xcassets/path_exit_crown.imageset/path_exit_crown@3x.png').convert('RGBA')
box = source.getchannel('A').point(lambda a: 255 if a >= 128 else 0).getbbox()
results = json.loads((REPORT / 'exit-markers.json').read_text())
checks = []
for level in results['levels']:
    for density in (1, 3):
        image = Image.open(REPORT / 'device-documents' / f"{level['map']}-markers@{density}x.png").convert('RGBA')
        for point in level['positions']:
            cx, cy = (v * density for v in point['view'])
            side = level['minimumBoxPoints'] * density
            expected = [cx + (box[0] / source.width - 0.5) * side,
                        cy + (box[1] / source.height - 0.5) * side * level['verticalFraction'],
                        cx + (box[2] / source.width - 0.5) * side,
                        cy + (box[3] / source.height - 0.5) * side * level['verticalFraction']]
            crop = (max(0, math.floor(cx-side/2-2)), max(0, math.floor(cy-side/2-2)),
                    min(image.width, math.ceil(cx+side/2+2)), min(image.height, math.ceil(cy+side/2+2)))
            if crop[0] >= crop[2] or crop[1] >= crop[3]:
                checks.append({'map': level['map'], 'density': density, 'center': point['view'], 'outsideViewport': True})
                continue
            actual = image.crop(crop).getchannel('A').point(lambda a: 255 if a >= 128 else 0).getbbox()
            assert actual is not None, (level['map'], point, 'missing visible marker')
            actual = [actual[0]+crop[0], actual[1]+crop[1], actual[2]+crop[0], actual[3]+crop[1]]
            clipped = [max(0, expected[0]), max(0, expected[1]), min(image.width, expected[2]), min(image.height, expected[3])]
            errors = [abs(a-b) for a,b in zip(actual, clipped)]
            assert max(errors) <= 2, (level['map'], density, point, actual, clipped)
            checks.append({'map': level['map'], 'density': density, 'center': point['view'],
                'actualBounds': actual, 'expectedBounds': clipped, 'maxRasterError': max(errors),
                'clippedAtViewport': clipped != expected})
(REPORT / 'raster-checks.json').write_text(json.dumps({'passed': True, 'checks': checks}, indent=2)+'\n')
print(f'PASS: {len(checks)} actual-device marker bounds agree with authored centers within two raster pixels.')
