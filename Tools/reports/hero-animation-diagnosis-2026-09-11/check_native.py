"""Audit device frame selection against rendered distance and prepare timed evidence."""
from pathlib import Path
from PIL import Image, ImageSequence
import json, math, collections, shutil

root = Path(__file__).resolve().parent
out = root.parents[3] / 'in-defense-of-history-data/ArtReadability/reports/hero-animation-diagnosis-2026-09-11'
dev = root / 'device-documents'
g = Image.open(dev / 'native-minimum-animation.gif')
delays = dict(collections.Counter(f.info.get('duration') for f in ImageSequence.Iterator(g)))
print('Original GIF:', g.size, g.n_frames, delays)
# Exact 50 Hz timestamps avoid short GIF delays being clamped by browser players.
frames = []
for i in range(105):
    g.seek(int(i * 60 / 50))
    frames.append(g.convert('RGB').copy())
frames[0].save(out / 'native-minimum-animation.gif', save_all=True,
               append_images=frames[1:], duration=20, loop=0, optimize=False)
frames[8].save(out / 'native-minimum-still.png')
checks = json.loads((root / 'animation-check.json').read_text())
assert len(checks['pixelChecks']) == 26
assert all(r['meanByteDifference'] < 0.13 and r['compiledPixels'] == r['sourcePixels']
           for r in checks['pixelChecks'])
trace = json.loads((dev / 'runtime-trace.json').read_text())
groups = collections.defaultdict(list)
for r in trace:
    prefix, di, frame = r['asset'].rsplit('_', 2)
    assert di == r['direction']
    count = 16 if 'washington' in prefix else 64
    assert 0 <= int(frame) < count
    groups[(prefix, di)].append(r)
max_error = 0
for (prefix, di), rows in groups.items():
    count = 16 if 'washington' in prefix else 64
    assert len(rows) == 126
    for r in rows:
        p = r['position']
        distance = math.hypot(p[0] - 1200, p[1] - 1000)
        raw = (distance % 75.6) / 75.6 * count
        actual = int(r['asset'].rsplit('_', 1)[1])
        expected = int(raw) % count
        # IEEE rounding at exact frame boundaries can choose either neighbor.
        assert (actual == expected or abs(raw - round(raw)) < 1e-8 and actual in
                [int(round(raw)) % count, (int(round(raw)) - 1) % count]), (r, raw)
        max_error = max(max_error, abs(distance - r['sample'] * 3))
check = dict(direction_frame_records_checked=len(trace),
             all_640_images_seen=len(set(r['asset'] for r in trace)) == 640,
             max_position_error_map_units=max_error,
             compiled_source_comparisons=26,
             max_mean_byte_difference=max(r['meanByteDifference'] for r in checks['pixelChecks']),
             original_gif_delay_counts_ms=delays,
             presentation_gif='105 native frames resampled at 20ms intervals: 2.1 seconds, five 0.42-second loops. Browser scheduling remains approximate.',
             passed=True)
(out / 'runtime-audit.json').write_text(json.dumps(check, indent=2) + '\n')
shutil.copy2(root / 'animation-check.json', out / 'device-check.json')
print(check)
