"""QA only: review production iPhone renders using the existing readability lab."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
from PIL import Image, ImageDraw, ImageOps

REPORT = Path(__file__).resolve().parent
GAME = REPORT.parents[2]
ART = GAME.parent / 'in-defense-of-history-data'
OUT = ART / 'ArtReadability/reports/master-controls-bastion-2026-09-10'
DEVICE = OUT / 'Device'
DEVICE.mkdir(parents=True, exist_ok=True)
for source in (REPORT / 'device-documents').iterdir():
    if source.is_file():
        shutil.copy2(source, DEVICE / source.name)
measurements = json.loads((REPORT / 'hud-check.json').read_text())
side = next(item['buttonSide'] for item in measurements['captures'] if item['mode'] == 'minimum')
config = json.loads((ART / 'ArtReadability/reports/control-padding-research-2026-09-08/source-manifest.json').read_text())
config['clamp'] = [340, 340]
map_directory = OUT / 'Maps'
map_directory.mkdir(exist_ok=True)
config['maps'] = []
map_inputs = []
for name in ('level_15_charleston', 'level_01_battle_road', 'level_008_trenton'):
    for suffix in ('', '_path', '_overlay', '_forest_occlusion', '_occlusion'):
        for extension in ('.heic', '.png'):
            source = ART / 'Levels' / (name + suffix + extension)
            if not source.exists():
                continue
            target = map_directory / (name + suffix + '.png')
            if extension == '.png':
                shutil.copy2(source, target)
            else:
                subprocess.run(['sips', '-s', 'format', 'png', str(source), '--out', str(target)], check=True, capture_output=True)
            map_inputs.append({'path': str(source), 'sha256': hashlib.sha256(source.read_bytes()).hexdigest()})
            break
    config['maps'].append({'id': name, 'label': name, 'base': str(map_directory / (name + '.png'))})
(OUT / 'map-source-hashes.json').write_text(json.dumps(map_inputs, indent=2)+'\n')
config['assets'] = [dict(id=name, label=name, animated=False, map_height=side,
    states={'se': {'idle': [name], 'walk': [name]}},
    files={name: [f'Device/{name}-minimum@{d}x.png' for d in (1,2,3)]})
    for name in ('speed', 'home', 'speed-before', 'home-before')]
config['sizing_sources'] = [
    f'Physical iPhone ImageRenderer of production HudMasterControlsView: minimum side {side} pt; 1x/2x/3x captures retain raster rounding.',
    'MasterControlsLayout, RuntimeCanvas and current SQLite virtual canvas; unchanged layout and action closures.',
    'Static HUD controls: one facing; no animation or cooldown state. Framed silhouettes establish border shape only; see separate emblem diagnostics.',
]
(OUT / 'source-manifest.json').write_text(json.dumps(config, indent=2)+'\n')
subprocess.run(['python3', str(ART / 'ArtReadability/build_readability_lab.py'),
    '--manifest', str(OUT / 'source-manifest.json'), '--output', str(OUT / 'lab')], check=True)

def view(image, mode):
    if mode == 'color':
        return image.copy()
    result = ImageOps.grayscale(image).convert('RGBA')
    if mode == 'three-value':
        result = ImageOps.grayscale(image).point(lambda x: 45 if x < 85 else (145 if x < 170 else 242)).convert('RGBA')
    result.putalpha(image.getchannel('A'))
    return result

checks = []
for density in (1,2,3):
    proof = Image.new('RGBA', (320*density, 200*density), '#e9e4d8')
    draw = ImageDraw.Draw(proof)
    for row, name in enumerate(('speed','home')):
        im = Image.open(DEVICE / f'{name}-minimum@{density}x.png').convert('RGBA')
        for col, mode in enumerate(('color','gray','three-value')):
            proof.alpha_composite(view(im, mode), (int((15+col*76)*density), int((30+row*65)*density)))
        # Isolate the warm emblem only, excluding the decorative rim. Diagnostic
        # thresholding is solely for silhouette review; never used in production.
        mask = Image.new('RGBA', im.size, (0,0,0,0))
        pixels, dst = im.load(), mask.load()
        for y in range(round(im.height*.19), round(im.height*.82)):
            for x in range(round(im.width*.19), round(im.width*.82)):
                r,g,b,a = pixels[x,y]
                if r > 115 and g > 85 and r > b*1.12 and g > b*1.03:
                    dst[x,y] = (0,0,0,255)
        proof.alpha_composite(mask, (243*density, (30+row*65)*density))
        mask.save(OUT / f'{name}-emblem-silhouette@{density}x.png')
        alpha=im.getchannel('A')
        checks.append({'asset': name, 'density': density, 'dimensions': list(im.size),
            'visible_bounds': alpha.getbbox(), 'transparent_corners': all(alpha.getpixel(p)==0 for p in [(0,0),(im.width-1,0),(0,im.height-1),(im.width-1,im.height-1)]),
            'sha256': hashlib.sha256((DEVICE/f'{name}-minimum@{density}x.png').read_bytes()).hexdigest()})
    if density==1:
        for x,label in [(15,'Color'),(91,'Grayscale'),(167,'Three values'),(243,'Emblem')]:
            draw.text((x,9),label,fill='#27382e')
        draw.text((15,167),f'{side:.2f} pt buttons / native size / no enlargement',fill='#27382e')
    proof.save(OUT / f'minimum-diagnostics@{density}x.png')

# Real map samples retain the minimum world scale, under the opaque HUD art.
plate=Image.new('RGBA',(340,155),'#e9e4d8')
draw=ImageDraw.Draw(plate)
maps=[('level_15_charleston.png',(0.56,0.47)),('level_01_battle_road.png',(0.40,0.55)),('level_008_trenton.png',(0.65,0.45))]
for col,(filename,center) in enumerate(maps):
    base=map_directory/filename
    source=Image.open(base).convert('RGBA')
    for suffix in ('_path','_overlay','_forest_occlusion','_occlusion'):
        layer=base.with_stem(base.stem+suffix)
        if layer.exists():
            source.alpha_composite(Image.open(layer).convert('RGBA'))
    factor=340/config['canvas']['play_rect'][3]
    source=source.resize((round(source.width*factor),round(source.height*factor)),Image.Resampling.LANCZOS)
    cx,cy=round(source.width*center[0]),round(source.height*center[1])
    patch=source.crop((cx-52,cy-55,cx+52,cy+55))
    x=9+col*110
    plate.alpha_composite(patch,(x,18))
    for row,name in enumerate(('speed','home')):
        im=Image.open(DEVICE/f'{name}-minimum@1x.png').convert('RGBA')
        plate.alpha_composite(im,(x+34,23+row*55))
draw.text((10,136),'Real terrain / minimum world scale',fill='#27382e')
plate.save(OUT/'terrain-minimum@1x.png')
(OUT/'render-checks.json').write_text(json.dumps({'device': measurements,'captures':checks},indent=2)+'\n')
assert all(item['transparent_corners'] for item in checks)
print('Saved existing readability lab, minimum diagnostics, terrain proofs and capture hashes.')
