import type { Point } from '../hud/layout';
import type { TowerTier } from '../data/contracts';
import type { Route } from './navigation';

export type ObstacleField={position:Point;heading:number;radius:number;widthFraction:number;slow:number};
export function obstacleField(position:Point,tuning:TowerTier,routes:Route[]):ObstacleField {
  const nearest=routes.map(route=>({route,...route.nearest(position)})).sort((a,b)=>a.gap-b.gap)[0];
  if(!nearest || tuning.obstacle_radius===null || tuning.obstacle_width_fraction===null || tuning.obstacle_slow_fraction===null)
    throw Error(`tower[${tuning.id}].obstacles: missing road or tuning`);
  const radius=tuning.obstacle_radius,before=nearest.route.point(nearest.along-radius/2),after=nearest.route.point(nearest.along+radius/2);
  return {position,heading:Math.atan2(after.y-before.y,after.x-before.x),radius,widthFraction:tuning.obstacle_width_fraction,slow:tuning.obstacle_slow_fraction};
}
export function obstacleContains(point:Point,f:ObstacleField) {
  const dx=point.x-f.position.x,dy=point.y-f.position.y,c=Math.cos(f.heading),s=Math.sin(f.heading);
  return Math.abs(dx*c+dy*s)<=f.radius&&Math.abs(-dx*s+dy*c)<=f.radius*f.widthFraction;
}
export function obstacleSlow(point:Point,fields:ObstacleField[]) {
  return 1-fields.reduce((strongest,f)=>obstacleContains(point,f)?Math.max(strongest,f.slow):strongest,0);
}
// Same worldToArtwork transform and even-odd road mask as EngineerObstacleView.
// This is a transient GPU texture made from the original image, never a new asset.
export function fieldArtwork(document:Document,source:CanvasImageSource,width:number,field:ObstacleField,rings:number[][][]) {
  const canvas=document.createElement('canvas');canvas.width=width;canvas.height=Math.ceil(width*field.widthFraction);
  const ctx=canvas.getContext('2d');if(!ctx)throw Error('Unable to render engineer road mask');
  const scale=width/(2*field.radius),c=Math.cos(field.heading),s=Math.sin(field.heading),p=field.position;
  ctx.beginPath();
  for(const ring of rings)ring.forEach(([x,y],i)=>{
    const localX=(c*(x!-p.x)+s*(y!-p.y))*scale+canvas.width/2;
    const localY=(s*(x!-p.x)-c*(y!-p.y))*scale+canvas.height/2;
    if(i===0)ctx.moveTo(localX,localY);else ctx.lineTo(localX,localY);
  });
  ctx.closePath();ctx.clip('evenodd');ctx.drawImage(source,0,0,canvas.width,canvas.height);return canvas;
}
export type MarkerShape = {kind:'rect'|'ellipse'|'circle';x:number;y:number;width:number;height:number;color:number;alpha:number;round:number};
// DemolitionGroundChargeSymbol is native vector artwork, recreated as drawing commands.
export function chargeSymbol(p:Point,seconds:number):MarkerShape[] {
  const result:MarkerShape[]=[];
  const add=(kind:MarkerShape['kind'],x:number,y:number,width:number,height:number,color:number,round=0,alpha=1)=>result.push({kind,x:p.x+x,y:p.y+y,width,height,color,round,alpha});
  add('ellipse',0,0,27,12,0x000000,0,.45);
  add('rect',-9,-19,18,22,0x1f2933,3.6);add('rect',-8.19,-18.19,16.38,20.38,0xc7631f,3);
  add('rect',-4.86,-16.91,5.04,17.82,0xffb54f,1.8);
  for(const y of [-15.15,-3.71])add('rect',-8.73,y,17.46,2.86,0x263647,1.43);
  add('ellipse',0,-16.36,13.32,3.96,0xfab054);
  add('circle',5,-12,13.2,13.2,0x141a21);add('circle',5,-12,10.8,10.8,seconds%.9<.55?0xff1721:0x47090b);
  return result;
}
