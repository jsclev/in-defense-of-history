"""Audit corrected runtime selection and compare native Knox captures at real timing."""
from pathlib import Path
from PIL import Image, ImageDraw
import json, math, collections, shutil

root=Path(__file__).resolve().parent
out=root.parents[3]/'in-defense-of-history-data/ArtReadability/reports/hero-animation-repair-2026-09-11'
old=out.parent/'hero-animation-diagnosis-2026-09-11/native-minimum-animation.gif'
dev=root/'device-documents'
trace=json.loads((dev/'runtime-trace.json').read_text())
groups=collections.defaultdict(list)
for row in trace:
 prefix,direction,frame=row['asset'].rsplit('_',2)
 assert direction==row['direction']
 frames=list(range(16)) if 'washington' in prefix else [0,16,32,48]
 assert int(frame) in frames, row
 groups[(prefix,direction)].append(row)
for (prefix,direction),rows in groups.items():
 frames=list(range(16)) if 'washington' in prefix else [0,16,32,48]
 assert len(rows)==126
 for row in rows:
  distance=math.hypot(row['position'][0]-1200,row['position'][1]-1000)
  assert abs(distance-row['sample']*3)<1e-8
  raw=(distance%75.6)/75.6*len(frames)
  expected={frames[int(raw)%len(frames)]}
  if abs(raw-round(raw))<1e-8:
   expected|={frames[int(round(raw))%len(frames)],frames[(int(round(raw))-1)%len(frames)]}
  assert int(row['asset'].rsplit('_',1)[1]) in expected, (row,raw)
checks=json.loads((root/'animation-check.json').read_text())
assert checks['passed'] and checks['uniqueImages']==160
assert all(c['meanByteDifference']<.13 and c['compiledPixels']==c['sourcePixels'] for c in checks['pixelChecks'])
before=Image.open(old)
native=[];comparison=[]
for tick in range(105):
 before.seek(tick)
 capture=Image.open(dev/f'frame-{int(tick*60/50):03d}.png').convert('RGB')
 assert capture.size == (1813,675) or capture.size == (1812,675), capture.size
 new=capture.resize((604,225),Image.Resampling.LANCZOS);native.append(new.copy())
 im=Image.new('RGB',(604,217),(178,189,161));d=ImageDraw.Draw(im)
 d.text((12,6),'Knox: native iPhone capture / 41.5 pt / unchanged movement speed',fill='black')
 for i,direction in enumerate(['N','NE','E','SE','S','SW','W','NW']):d.text((38+i*74,26),direction,fill='black')
 d.text((12,44),'Before: 64 frames with blended limbs',fill='black')
 d.text((12,128),'After: four original drawings only',fill='black')
 im.paste(before.convert('RGB').crop((0,132,604,199)),(0,57))
 im.paste(new.crop((0,132,604,199)),(0,141))
 comparison.append(im)
for name,frames in [('native-minimum-animation.gif',native),('knox-before-after.gif',comparison)]:
 # One palette derived from all frames avoids per-frame palette flicker;
 # disabling dithering preserves clean color masses at the 41-point scale.
 palette_source=Image.new('RGB',(604*7,217*15))
 for i,frame in enumerate(frames):palette_source.paste(frame,(i%7*604,i//7*217))
 palette=palette_source.quantize(colors=256,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE)
 encoded=[frame.quantize(palette=palette,dither=Image.Dither.NONE) for frame in frames]
 encoded[0].save(out/name,save_all=True,append_images=encoded[1:],duration=20,loop=0,optimize=False,disposal=2)
comparison[8].save(out/'knox-before-after-still.png')
report={'passed':True,'records':len(trace),'unique_Washington_images':128,'unique_Knox_images':32,
 'directions':8,'knox_source_indices':[0,16,32,48],'cycle_seconds':.42,'compiled_source_comparisons':26,
 'maximum_mean_byte_difference':max(c['meanByteDifference'] for c in checks['pixelChecks']),
 'capture_density':3,'preview':'3x native PNGs reduced to logical size for the GIF; 1x offscreen capture aliases tiny details.',
 'limitation':'Physical iPhone uses production pose/publish/render code at controlled movement samples. Frozen anchors isolate gait. No live touch/display-link or art-quality acceptance claim.'}
(out/'runtime-audit.json').write_text(json.dumps(report,indent=2)+'\n')
shutil.copy2(root/'animation-check.json',out/'device-check.json')
review=json.loads((out/'review.json').read_text());review['device_status']=report
(out/'review.json').write_text(json.dumps(review,indent=2)+'\n')
print(json.dumps(report,indent=2))
