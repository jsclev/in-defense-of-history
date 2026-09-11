"""Plot the current geometry only; does not edit game artwork or code."""
import json, math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
rows=json.loads((HERE/'exit-vectors.json').read_text())
g=json.loads((ROOT/'Db/level_15_charleston.geojson').read_text())
rings=next(f['geometry']['coordinates'] for f in g['features'] if f.get('properties',{}).get('kind')=='enemy_path')
placements=next(r['heroes'] for r in json.loads((ROOT/'Tools/reports/hero-path-centering-2026-09-09/hero-exits.json').read_text())['checks'] if r['scenario']=='pair' and r['viewport']=='minimum')
font_path='/System/Library/Fonts/Supplemental/Arial.ttf'
def font(size): return ImageFont.truetype(font_path,size)
fig=Image.new('RGB',(1200,860),'#faf9f5');d=ImageDraw.Draw(fig)
d.text((30,20),'How the current code forms the direction vector',font=font(27),fill='#172331')
d.text((30,58),'Map coordinates: +X right, +Y up. The arrows show the database route direction.',font=font(18),fill='#485464')
colors={'route':'#567e9a','direction':'#b63138','normal':'#6154af','cross':'#197351'}
for index,(row,placement,limits,title) in enumerate(zip(rows,placements,[(1220,1810,240,930),(2010,2480,760,1400)],['Primary / bottom exit / route 0','Secondary / right exit / route 1'])):
 panel=Image.new('RGB',(560,650),'#f3f6ec');p=ImageDraw.Draw(panel)
 xmin,xmax,ymin,ymax=limits
 scale=min(500/(xmax-xmin),550/(ymax-ymin));ox=(560-scale*(xmax-xmin))/2;oy=65
 def xy(q):return(ox+(q[0]-xmin)*scale,oy+(ymax-q[1])*scale)
 for i,ring in enumerate(rings):
  p.polygon([xy(q) for q in ring],fill='#e0c693' if i==0 else '#f3f6ec')
  p.line([xy(q) for q in ring],fill='#b09159',width=1)
 p.rectangle((0,0,560,53),fill='#faf9f5')
 p.text((14,10),title,font=font(21),fill='#172331')
 route=[xy(q) for q in row['nearbyRoute']]
 for j in range(0,len(route)-1,2):p.line(route[j:j+2],fill=colors['route'],width=3)
 a,b=row['before'],row['after'];u=row['unitVector'];n=row['normal'];guide=row['guide']
 p.line([xy(a),xy(b)],fill=colors['direction'],width=4)
 for q,label,offset in [(a,'A',(-18,-20)),(b,'B',(-18,8))]:
  x,y=xy(q);p.ellipse((x-4,y-4,x+4,y+4),fill=colors['direction']);p.text((x+offset[0],y+offset[1]),label,font=font(18),fill=colors['direction'])
 start=xy(guide);end=xy([guide[k]+105*u[k] for k in (0,1)])
 p.line([start,end],fill=colors['direction'],width=3)
 angle=math.atan2(end[1]-start[1],end[0]-start[0]);head=[end]+[(end[0]-15*math.cos(angle+s),end[1]-15*math.sin(angle+s)) for s in (-.4,.4)]
 p.polygon(head,fill=colors['direction'])
 p.line([xy([guide[k]-85*n[k] for k in (0,1)]),xy([guide[k]+85*n[k] for k in (0,1)])],fill=colors['normal'],width=3)
 ex,ey=xy(row['exit']);p.line([(ex,ey-8),(ex+8,ey),(ex,ey+8),(ex-8,ey),(ex,ey-8)],fill='#172331',width=2)
 p.text((ex+12,ey-25),'GeoJSON exit',font=font(16),fill='#172331')
 left,right,_=placement['pathCrossSection'];center=placement['position'];width=math.dist(left,right)
 p.line([xy(left),xy(right)],fill=colors['cross'],width=4)
 cx,cy=xy(center);p.ellipse((cx-6,cy-6,cx+6,cy+6),fill=colors['cross'])
 label=f'Hero midpoint\nChosen width: {width:.1f}'
 box=(max(8,cx-180),cy+13,max(8,cx-180)+169,cy+60)
 p.rectangle(box,fill='#faf9f5');p.multiline_text((box[0]+5,box[1]+4),label,font=font(16),fill=colors['cross'],spacing=2)
 if index==0:
  y=xy((xmin,492))[1]
  for x in range(0,560,12):p.line((x,y,x+5,y),fill='#858d95',width=1)
  p.text((8,y+4),'Play-area bottom',font=font(14),fill='#65707b')
 p.rectangle((0,0,560,53),fill='#faf9f5')
 p.text((14,10),title,font=font(21),fill='#172331')
 p.rectangle((0,610,560,650),fill='#faf9f5')
 p.text((14,618),f'Exit unit vector = ({u[0]:.4f}, {u[1]:.4f})',font=font(18),fill=colors['direction'])
 fig.paste(panel,(30+index*590,104))
for i,(color,label) in enumerate([(colors['route'],'Database route'),(colors['direction'],'A to B direction (arrow extended)'),(colors['normal'],'Perpendicular at the exit guide'),(colors['cross'],'Cross-section used for the final hero')]):
 x=35+(i%2)*590;y=780+(i//2)*35
 d.line((x,y+8,x+30,y+8),fill=color,width=4);d.text((x+42,y),label,font=font(17),fill='#243444')
fig.save(HERE/'exit-vectors.png')
