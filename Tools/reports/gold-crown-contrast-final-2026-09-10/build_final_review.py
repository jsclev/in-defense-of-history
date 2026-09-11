"""Review production density exports with crop-aware placement in the existing lab."""
from pathlib import Path
from PIL import Image,ImageDraw
import importlib.util,json,statistics
ROOT=Path('/Users/john/projects/td');DATA=ROOT/'in-defense-of-history-data'
REPORT=DATA/'ArtReadability/reports/gold-crown-contrast-2026-09-10'
ART=DATA/'Images/Path-Exit-Crown-Proposals/2026-09-10-outlined'
spec=importlib.util.spec_from_file_location('lab',DATA/'ArtReadability/build_readability_lab.py')
lab=importlib.util.module_from_spec(spec);spec.loader.exec_module(lab)
config=json.loads((REPORT/'input-manifest.json').read_text())
files=[]
for d in (1,2,3):
 im=Image.open(lab.asset_path('path_exit_crown',d)).convert('RGBA')
 padded=Image.new('RGBA',(192*d,192*d))
 padded.alpha_composite(im,(54*d,41*d))
 path=REPORT/f'production-diagnostic@{d}x.png';padded.save(path);files.append(str(path))
entry={'id':'final_production','label':'Cropped flat crown / production','animated':False,
 'map_height':51.2*655/340,'ground_inset_fraction':.25,
 'states':{d:{'idle':['crown'],'walk':['crown']} for d in lab.DIRECTIONS},'files':{'crown':files}}
config['assets']=[config['assets'][0],entry]
config['sizing_note']='Final cropped catalog 89x92 logical pixels. Source calibration 96 at 25.6 gameplay points; crop origin (54,41) in a 192 canvas with authored anchor (96,96). Lab pads only to reproduce the same placement; the production PNGs are cropped.'
for entry2 in config['sizing_sources']:
 path=Path(entry2['path'])
 if path.exists():entry2['sha256']=lab.digest(path)
(REPORT/'final-input-manifest.json').write_text(json.dumps(config,indent=2)+'\n')
lab.build(config,REPORT/'final-lab')
terrains={}
for key in ['battle-road','trenton']:
 im=Image.open(REPORT/'final-lab'/f'{key}-under.jpg').convert('RGBA')
 im.alpha_composite(Image.open(REPORT/'final-lab'/f'{key}-over.png').convert('RGBA'))
 terrains[key]=lab.resize_rgba(im,(604,340))
conditions=[('Tan path','battle-road',(430,138)),('Light path','battle-road',(325,100)),
 ('Snow','trenton',(288,297)),('Foliage','battle-road',(582,140))]
def luminance(rgb):
 linear=[v/255/12.92 if v/255<=.04045 else ((v/255+.055)/1.055)**2.4 for v in rgb[:3]]
 return sum(c*w for c,w in zip(linear,(.2126,.7152,.0722)))
metrics=[]
for den in (1,2,3):
 glyph=lab.thumbnail(Image.open(files[den-1]).convert('RGBA'),51.2*den)
 out=Image.new('RGBA',(448*den,116*den),'#f4f0e5');draw=ImageDraw.Draw(out)
 draw.text((12*den,8*den),'Minimum gameplay size',font=lab.font(14*den),fill='#292330')
 for idx,(name,map_id,(cx,cy)) in enumerate(conditions):
  patch=terrains[map_id].crop((cx-51,cy-30,cx+51,cy+30))
  patch=lab.resize_rgba(patch,(102*den,60*den));raw=patch.copy()
  px,py=round(51*den-glyph.width/2),round(30*den-glyph.height/2)
  patch.alpha_composite(glyph,(px,py));ratios=[]
  for y in range(glyph.height):
   for x in range(glyph.width):
    r,g,b,a=glyph.getpixel((x,y))
    if a>=220 and r<95 and g<75 and b<105 and 0<=x+px<patch.width and 0<=y+py<patch.height:
     bg=luminance(raw.getpixel((x+px,y+py)));fg=luminance(patch.getpixel((x+px,y+py)))
     ratios.append((max(fg,bg)+.05)/(min(fg,bg)+.05))
  assert ratios
  ratios.sort()
  metrics.append({'condition':name,'density':den,'core_outline_samples':len(ratios),
   'minimum_luminance_contrast':min(ratios),'median_luminance_contrast':statistics.median(ratios),
   'fraction_at_least_3_to_1':sum(v>=3 for v in ratios)/len(ratios)})
  out.alpha_composite(patch,((10+idx*110)*den,35*den))
  draw.text(((12+idx*110)*den,99*den),name,font=lab.font(11*den),fill='#292330')
 out.convert('RGB').save(REPORT/f'minimum-path-proof@{den}x.png')
(REPORT/'background-contrast.json').write_text(json.dumps({'note':'Diagnostic luminance contrast of the dark contour against real terrain samples; not a recognition score or accessibility certification.','conditions':metrics},indent=2)+'\n')
print([m for m in metrics if m['density']==3])
