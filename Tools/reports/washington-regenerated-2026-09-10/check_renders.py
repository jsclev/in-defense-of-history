"""Geometry and preservation checks for the regenerated complete HUD icon."""
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw

REPORT = Path(__file__).resolve().parent
CAPTURES = REPORT / 'device-documents'
PREVIOUS = REPORT.parent / 'knox-regenerated-2026-09-10/device-documents'
ART = REPORT.parents[3] / 'in-defense-of-history-data/ArtReadability/reports/washington-regenerated-2026-09-10'
results = []
for mode in ['minimum', 'device']:
    for density in [1, 2, 3]:
        for name in ['knox-ready','knox-selected','knox-unavailable','ready','selected','cooldown']:
            filename = f'{name}-{mode}@{density}x.png'
            before = Image.open(PREVIOUS / filename).convert('RGBA')
            after = Image.open(CAPTURES / filename).convert('RGBA')
            assert before.size == after.size
            delta = max(hi for lo, hi in ImageChops.difference(before, after).getextrema())
            assert delta <= 1, (filename, delta)
            results.append({'neighbor': filename, 'max_channel_delta': delta})
        filename = f'washington-ready-{mode}@{density}x.png'
        icon = Image.open(CAPTURES / filename).convert('RGBA')
        neighbor = Image.open(CAPTURES / f'ready-{mode}@{density}x.png').convert('RGBA')
        assert icon.size == neighbor.size
        bounds = icon.getchannel('A').point(lambda a: 255 if a >= 128 else 0).getbbox()
        other = neighbor.getchannel('A').point(lambda a: 255 if a >= 128 else 0).getbbox()
        assert all(abs(a-b) <= 1 for a,b in zip(bounds,other)), (filename,bounds,other)
        w,h=icon.size
        assert all(icon.getpixel(p)[3] == 0 for p in [(0,0),(w-1,0),(0,h-1),(w-1,h-1)])
        results.append({'complete_icon':filename, 'size':list(icon.size),
                        'visible_frame_bounds':bounds, 'neighbor_frame_bounds':other,
                        'outer_corners_transparent':True})

for name in ['tested-source-hashes.json','unchanged-art-hashes.json']:
    hashes=json.loads((REPORT/name).read_text())
    changed=[p for p,h in hashes.items() if hashlib.sha256(Path(p).read_bytes()).hexdigest()!=h]
    assert not changed,(name,changed)
    results.append({'hash_manifest':name,'verified_files':len(hashes),'changed':changed})
(REPORT/'render-checks.json').write_text(json.dumps(results,indent=2)+'\n')
(ART/'Device').mkdir(exist_ok=True)
for source in CAPTURES.glob('*.png'):
    shutil.copy2(source,ART/'Device'/source.name)
shutil.copy2(REPORT/'render-checks.json',ART/'render-checks.json')
proof=Image.new('RGB',(214,87),(38,61,38));draw=ImageDraw.Draw(proof)
for col,(name,label) in enumerate([('washington-before','Before'),('washington-ready','New artwork'),('washington-selected','Selected')]):
    icon=Image.open(CAPTURES/f'{name}-minimum@1x.png').convert('RGBA')
    proof.paste(icon,(12+70*col,9),icon)
    draw.text((7+70*col,64),label,fill='white')
proof.save(ART/'washington-regenerated-minimum@1x.png')
print(f'PASS: {len(results)} render/preservation checks; native visual review still required.')
