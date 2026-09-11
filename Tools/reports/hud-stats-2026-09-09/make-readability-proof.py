"""Use the existing lab's transforms in a sheet sized for wide HUD strips."""
from pathlib import Path
import sys
from PIL import Image, ImageDraw
OUT = Path(__file__).resolve().parent
LAB = OUT.parents[3] / 'in-defense-of-history-data/ArtReadability'
sys.path.insert(0, str(LAB))
from build_readability_lab import transform
proof = Image.new('RGBA', (640, 250), '#f5f1e5')
draw = ImageDraw.Draw(proof)
for row, state in enumerate(['start', 'end', 'wide']):
    source = Image.open(OUT / f'minimum-{state}@1x.png').convert('RGBA')
    for col, mode in enumerate(['color', 'gray', 'silhouette']):
        draw.text((10 + col * 210, 5 + row * 82), mode, fill='#282b28')
        proof.alpha_composite(transform(source, mode), (10 + col * 210, 20 + row * 82))
proof.convert('RGB').save(OUT / 'minimum-readability.png')
