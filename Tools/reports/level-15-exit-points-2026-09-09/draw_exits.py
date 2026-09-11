"""Draw literal GeoJSON exits and road boundaries; no gameplay/artwork edits."""
import json,hashlib
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
source=ROOT/'Db/level_15_charleston.geojson'
data=json.loads(source.read_text())
area=data['coordinateReferenceSystem']['playArea']
road=next(f for f in data['features'] if f.get('properties',{}).get('kind')=='enemy_path')
exits=[f for f in data['features'] if f.get('properties',{}).get('kind')=='goal_point']
assert road['geometry']['type']=='Polygon'
img=Image.new('RGB',(1100,930),'#faf9f5');d=ImageDraw.Draw(img)
font_path='/System/Library/Fonts/Supplemental/Arial.ttf'
def font(size):return ImageFont.truetype(font_path,size)
def xy(q):return (50+(q[0]-250)*.42,110+(1910-q[1])*.42)
d.text((28,20),'Level 15 — exit points in the bundled GeoJSON',font=font(28),fill='#182535')
d.text((28,62),'Each marker is an exact goal_point coordinate. Dashed box = rectangular play area.',font=font(18),fill='#485565')
d.rectangle((25,100,1075,856),fill='#eef0e7')
for i,ring in enumerate(road['geometry']['coordinates']):
 points=[xy(q) for q in ring]
 d.polygon(points,fill='#dbc28f' if i==0 else '#eef0e7')
 d.line(points,fill='#a58b56',width=1)
bl=xy((area['x'],area['y']));tr=xy((area['x']+area['width'],area['y']+area['height']))
def dashed(a,b):
 import math
 length=math.dist(a,b)
 for s in range(0,int(length),17):
  e=min(s+10,length)
  d.line([(a[0]+(b[0]-a[0])*s/length,a[1]+(b[1]-a[1])*s/length),(a[0]+(b[0]-a[0])*e/length,a[1]+(b[1]-a[1])*e/length)],fill='#344252',width=3)
for a,b in [((bl[0],bl[1]),(tr[0],bl[1])),((tr[0],bl[1]),(tr[0],tr[1])),((tr[0],tr[1]),(bl[0],tr[1])),((bl[0],tr[1]),(bl[0],bl[1]))]:dashed(a,b)
d.rectangle((bl[0]+8,tr[1]+8,bl[0]+222,tr[1]+34),fill='#faf9f5')
d.text((bl[0]+15,tr[1]+11),'PLAY AREA  1920 × 1080',font=font(16),fill='#344252')
labels=[(230,782),(784,279),(30,285),(714,724),(690,527)]
records=[]
for i,(f,(lx,ly)) in enumerate(zip(exits,labels)):
 q=f['geometry']['coordinates'];px,py=xy(q);roles=f['properties'].get('heroRoles',[])
 color='#b33238' if roles==['primary'] else '#245ab2' if roles==['secondary'] else '#655478'
 inside=area['x']<=q[0]<=area['x']+area['width'] and area['y']<=q[1]<=area['y']+area['height']
 role=roles[0].upper() if roles else 'No hero assigned'
 state='inside play area' if inside else 'OUTSIDE play area'
 w=270;h=77
 nearest=(min(max(px,lx),lx+w),min(max(py,ly),ly+h))
 d.line((px,py,*nearest),fill=color,width=2)
 d.rounded_rectangle((lx,ly,lx+w,ly+h),radius=6,fill='#fffefa',outline=color,width=2)
 d.text((lx+10,ly+8),f'exit.{i}  ·  {role}',font=font(19),fill=color)
 d.text((lx+10,ly+34),f'({q[0]:g}, {q[1]:g})',font=font(18),fill='#243343')
 d.text((lx+10,ly+56),state,font=font(14),fill='#485565')
 d.ellipse((px-10,py-10,px+10,py+10),fill='#fffefa',outline=color,width=3)
 d.ellipse((px-3,py-3,px+3,py+3),fill=color)
 records.append({'id':f['id'],'coordinates':q,'heroRoles':roles,'insidePlayArea':inside})
d.text((28,878),'Source: Db/level_15_charleston.geojson  •  Feature IDs are gameplay.exit.0 through gameplay.exit.4',font=font(17),fill='#38485a')
d.text((28,904),'Coordinates use the map’s lower-left origin, with +Y upward. No database route points are used in this drawing.',font=font(16),fill='#53616d')
img.save(HERE/'level-15-exit-points.png')
(HERE/'exit-points.json').write_text(json.dumps({'source':str(source),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'playArea':area,'exits':records},indent=2)+'\n')
