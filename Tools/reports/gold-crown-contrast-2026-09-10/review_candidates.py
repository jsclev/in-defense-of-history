"""Use the existing lab to compare phone-rendered contours on actual terrain."""
from pathlib import Path
from PIL import Image,ImageDraw
import importlib.util,json
ROOT=Path('/Users/john/projects/td');DATA=ROOT/'in-defense-of-history-data'
DEVICE=Path(__file__).resolve().parent/'device-documents'
REPORT=DATA/'ArtReadability/reports/gold-crown-contrast-2026-09-10'
REPORT.mkdir(parents=True,exist_ok=True)
spec=importlib.util.spec_from_file_location('lab',DATA/'ArtReadability/build_readability_lab.py')
lab=importlib.util.module_from_spec(spec);spec.loader.exec_module(lab)
config=json.loads((DATA/'ArtReadability/reports/gold-crown-flat-2026-09-10/input-manifest.json').read_text())
baseline=config['assets'][1];baseline['label']='Unoutlined / rejected'
config['assets']=[baseline]
for name,weight in [('thin',.55),('medium',.9),('bold',1.25)]:
 entry={'id':'outline_'+name,'label':f'{weight} pt contour','animated':False,
 'map_height':51.2*655/340,'ground_inset_fraction':.25,
 'states':{d:{'idle':['crown'],'walk':['crown']} for d in lab.DIRECTIONS},
 'files':{'crown':[str(DEVICE/f'outline-{name}@{d}x.png') for d in (1,2,3)]}}
 config['assets'].append(entry)
config['sizing_note']='Phone-rendered full marker, including half-angle transform and uniform contour. The 51.2pt QA canvas preserves the prior 25.6pt source scale, with padding for transformed pixels. All candidates share exactly the same gold/red face size.'
(REPORT/'input-manifest.json').write_text(json.dumps(config,indent=2)+'\n')
lab.build(config,REPORT/'lab')
# All swatches retain the real terrain's 604x340 map scale.
terrains={}
for key in ['battle-road','trenton']:
 im=Image.open(REPORT/'lab'/f'{key}-under.jpg').convert('RGBA')
 im.alpha_composite(Image.open(REPORT/'lab'/f'{key}-over.png').convert('RGBA'))
 terrains[key]=lab.resize_rgba(im,(604,340))
patches=[('Tan path','battle-road',(430,138)),('Light path','battle-road',(325,100)),
 ('Path edge','battle-road',(569,182)),('Grass','battle-road',(420,278)),
 ('Snow','trenton',(288,297)),('Snow / path','trenton',(365,244)),
 ('Busy bridge','trenton',(279,251)),('Dark foliage','battle-road',(582,140))]
for den in (1,2,3):
 w,h=740,600;sheet=Image.new('RGBA',(w*den,h*den),'#f4f0e5');draw=ImageDraw.Draw(sheet)
 font=lambda n:lab.font(n*den)
 draw.text((18*den,10*den),'Contour comparison / minimum gameplay size',font=font(18),fill='#25202d')
 imgs=[lab.thumbnail(Image.open(a['files']['crown'][den-1]).convert('RGBA'),51.2*den) for a in config['assets']]
 for i,(entry,im) in enumerate(zip(config['assets'],imgs)):
  x=(128+153*i)*den
  draw.text((x-55*den,42*den),entry['label'],font=font(12),fill='#25202d')
  for j,mode in enumerate(['color','gray','silhouette','three-value']):
   thumb=lab.transform(im,mode)
   cx=x+(j-1.5)*31*den
   sheet.alpha_composite(thumb,(round(cx-thumb.width/2),round(83*den-thumb.height/2)))
  for j,(label,map_id,point) in enumerate(patches):
   tx,ty=point;crop=terrains[map_id].crop((tx-57,ty-25,tx+57,ty+25))
   crop=lab.resize_rgba(crop,(114*den,50*den))
   crop.alpha_composite(im,(round(57*den-im.width/2),round(25*den-im.height/2)))
   sheet.alpha_composite(crop,(x-57*den,(115+j*58)*den))
   if i==0:draw.text((5*den,(117+j*58)*den),label,font=font(10),fill='#25202d')
 sheet.convert('RGB').save(REPORT/f'comparison@{den}x.png')
print(REPORT/'comparison@1x.png')
