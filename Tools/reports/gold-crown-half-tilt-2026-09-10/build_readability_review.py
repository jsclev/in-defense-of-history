"""Diagnostic rendering of the SwiftUI transform; approved source art is read-only."""
from pathlib import Path
from PIL import Image, ImageDraw
import importlib.util,json,math,hashlib
ROOT=Path('/Users/john/projects/td');DATA=ROOT/'in-defense-of-history-data'
REPORT=DATA/'ArtReadability/reports/gold-crown-half-tilt-2026-09-10'
REPORT.mkdir(parents=True,exist_ok=True)
spec=importlib.util.spec_from_file_location('lab',DATA/'ArtReadability/build_readability_lab.py')
lab=importlib.util.module_from_spec(spec);spec.loader.exec_module(lab)
q=math.cos(math.radians(27.5))/math.cos(math.radians(55))
c0,s0=math.cos(math.radians(20)),math.sin(math.radians(20));c1,s1=math.cos(math.radians(10)),math.sin(math.radians(10))
a=c1*c0+s1*q*s0;c=c1*s0-s1*q*c0;b=s1*c0-c1*q*s0;d=s1*s0+c1*q*c0
det=a*d-b*c
inv=(d/det,-c/det,-b/det,a/det)
# A padded 51.2pt diagnostic canvas contains the 25.6pt source frame and all
# transformed pixels. It is not a change to the runtime image frame or size.
def transformed(im,den):
 size=192*den;src=lab.resize_rgba(im,(96*den,96*den));pad=Image.new('RGBA',(size,size));pad.alpha_composite(src,(48*den,48*den))
 center=size/2
 aa,cc,bb,dd=inv
 coeff=(aa,cc,center-aa*center-cc*center,bb,dd,center-bb*center-dd*center)
 return pad.convert('RGBa').transform((size,size),Image.Transform.AFFINE,coeff,resample=Image.Resampling.BICUBIC).convert('RGBA')
files=[]
for den in (1,2,3):
 im=Image.open(lab.asset_path('path_exit_crown',den)).convert('RGBA')
 p=REPORT/f'corrected-diagnostic@{den}x.png';transformed(im,den).save(p);files.append(str(p))
config=json.loads((DATA/'ArtReadability/reports/gold-crown-exit-2026-09-10/input-manifest.json').read_text())
old=config['assets'][0];old['label']='Before / original baked angle'
new={'id':'half_tilt_crown','label':'After / perspective eased halfway','animated':False,'map_height':51.2*655/340,'ground_inset_fraction':.25,'states':{d:{'idle':['crown'],'walk':['crown']} for d in lab.DIRECTIONS},'files':{'crown':files}}
config['assets']=[old,new]
config['sizing_note']='Both use the unchanged 25.6pt source frame. After uses a padded 51.2pt diagnostic canvas solely to contain rotation/scale pixels. Runtime transform R(10deg) * Sy(cos27.5/cos55) * R(-20deg), centered. No source PNG edits.'
for entry in config['sizing_sources']:entry['sha256']=lab.digest(Path(entry['path']))
(REPORT/'input-manifest.json').write_text(json.dumps(config,indent=2)+'\n')
(REPORT/'transform.json').write_text(json.dumps({'source_roll_deg':20,'corrected_roll_deg':10,'source_face_normal_tilt_estimate_deg':55,'corrected_face_normal_tilt_deg':27.5,'vertical_recovery':q,'screen_matrix':[[a,c],[b,d]],'source_box_pt':25.6,'diagnostic_box_pt':51.2,'angle_precision':'approximate because original projection is baked into illustration'},indent=2)+'\n')
lab.build(config,REPORT/'lab')
out=Image.new('RGBA',(560,292),'#f5f1e5');draw=ImageDraw.Draw(out)
draw.text((18,14),'Crown angle / before and after at minimum size',font=lab.font(19),fill='#30343c')
draw.text((18,43),'Same 25.6pt source frame; perspective correction only',font=lab.font(13),fill='#30343c')
old_im=lab.thumbnail(Image.open(lab.asset_path('path_exit_crown',3)).convert('RGBA'),25.6)
new_im=lab.thumbnail(Image.open(files[2]).convert('RGBA'),51.2)
for i,(label,im) in enumerate([('Before',old_im),('Half tilt',new_im)]):
 cx=140+280*i;draw.text((cx-36,78),label,font=lab.font(14),fill='#30343c')
 for j,mode in enumerate(('color','gray','silhouette','three-value')):
  transformed_im=lab.transform(im,mode);x=52+280*i+52*j
  out.alpha_composite(transformed_im,(round(x-im.width/2),round(126-im.height/2)))
 for j,(map_id,fx,fy) in enumerate([('battle-road',.74,.49),('trenton',.48,.65)]):
  terrain=Image.open(REPORT/'lab'/f'{map_id}-under.jpg').convert('RGBA');terrain.alpha_composite(Image.open(REPORT/'lab'/f'{map_id}-over.png').convert('RGBA'))
  terrain=lab.resize_rgba(terrain,(604,340));x,y=round(terrain.width*fx),round(terrain.height*fy)
  patch=terrain.crop((x-115,y-26,x+115,y+26));patch.alpha_composite(im,(round(115-im.width/2),round(26-im.height/2)))
  out.alpha_composite(patch,(25+280*i,160+j*61))
out.convert('RGB').save(REPORT/'before-after-minimum.png')
print('Matrix:',[[a,c],[b,d]],'vertical recovery:',q)
