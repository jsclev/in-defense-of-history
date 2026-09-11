"""Compare native iPhone button captures; this does not certify recognition."""
import hashlib
import json
import math
import shutil
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

REPORT = Path(__file__).resolve().parent
PREVIOUS = REPORT.parent / 'knox-headroom-2026-09-10/device-documents'
CAPTURES = REPORT / 'device-documents'
ART = REPORT.parents[3] / 'in-defense-of-history-data/ArtReadability/reports/knox-background-2026-09-10'

results = []
for mode in ['minimum', 'device']:
    for density in [1, 2, 3]:
        for name in ['hero', 'ready', 'selected', 'cooldown']:
            filename = f'{name}-{mode}@{density}x.png'
            before = Image.open(PREVIOUS / filename).convert('RGBA')
            after = Image.open(CAPTURES / filename).convert('RGBA')
            assert before.size == after.size
            delta = max(hi for lo, hi in ImageChops.difference(before, after).getextrema())
            assert delta <= 1, (filename, delta)
            results.append({'unchanged_neighbor': filename, 'max_channel_delta': delta})
        for name in ['knox-ready', 'knox-selected', 'knox-unavailable']:
            filename = f'{name}-{mode}@{density}x.png'
            before = Image.open(PREVIOUS / filename).convert('RGBA')
            after = Image.open(CAPTURES / filename).convert('RGBA')
            w, h = after.size
            # Exclude antialiased perimeter pixels that blend with the new fill.
            portrait = (math.ceil(w * .18) + 1, math.ceil(h * .20) + 1,
                        math.floor(w * .82) - 1, math.floor(h * .84) - 1)
            delta = max(hi for lo, hi in ImageChops.difference(
                before.crop(portrait), after.crop(portrait)).getextrema())
            assert delta <= 1, (filename, 'portrait changed', delta)
            top_padding = (math.ceil(w * .22), math.ceil(h * .13),
                           math.floor(w * .78), math.floor(h * .18))
            pixels = list(after.crop(top_padding).getdata())
            blue = sum(b > r * 1.25 and b > g * 1.1 for r, g, b, a in pixels)
            assert blue == 0, (filename, 'blue padding', blue)
            results.append({'portrait': filename, 'max_channel_delta': delta,
                            'top_padding_blue_pixels': blue, 'sample_count': len(pixels)})

for name in ['tested-source-hashes.json', 'original-knox-hashes.json', 'unchanged-art-hashes.json']:
    hashes = json.loads((REPORT / name).read_text())
    changed = [p for p, expected in hashes.items()
               if hashlib.sha256(Path(p).read_bytes()).hexdigest() != expected]
    assert not changed, (name, changed)
    results.append({'hash_manifest': name, 'verified_files': len(hashes), 'changed': changed})

(REPORT / 'render-checks.json').write_text(json.dumps(results, indent=2) + '\n')
(ART / 'Device').mkdir(exist_ok=True)
for source in CAPTURES.glob('*.png'):
    shutil.copy2(source, ART / 'Device' / source.name)
shutil.copy2(REPORT / 'render-checks.json', ART / 'render-checks.json')
proof = Image.new('RGB', (214, 87), (38, 61, 38))
draw = ImageDraw.Draw(proof)
for col, (name, label) in enumerate([
        ('knox-before', 'Before'), ('knox-ready', 'Updated'), ('knox-selected', 'Selected')]):
    icon = Image.open(CAPTURES / f'{name}-minimum@1x.png').convert('RGBA')
    proof.paste(icon, (12 + col * 70, 9), icon)
    draw.text((7 + col * 70, 64), label, fill='white')
proof.save(ART / 'knox-background-minimum@1x.png')
print(f'PASS: {len(results)} native render/preservation checks; small proof saved.')
