// @vitest-environment jsdom
import { beforeAll, expect, it, vi } from 'vitest';
import { authored, battleSession } from './fixtures';
import type { TowerTier } from '../src/data/contracts';
import { Route } from '../src/game/navigation';
import { chargeSymbol,fieldArtwork,obstacleField,obstacleSlow } from '../src/game/tower-effects';
let tuning:TowerTier;
beforeAll(async()=>{const db=(await authored()).open();try{tuning=(await battleSession(db)).towers.base('special');}finally{db.close();}});
it('aligns abatis to its closest road, uses authored radius/width and applies the strongest overlapping slowdown',()=>{
  const t={...tuning,obstacle_radius:40,obstacle_width_fraction:.25,obstacle_slow_fraction:.3};
  const routes=[new Route([{x:0,y:-100},{x:0,y:100}]),new Route([{x:300,y:0},{x:500,y:0}])];
  const field=obstacleField({x:0,y:0},t,routes);expect(field.heading).toBeCloseTo(Math.PI/2);
  expect(obstacleSlow({x:0,y:39},[field])).toBe(.7);expect(obstacleSlow({x:11,y:0},[field])).toBe(1);
  expect(obstacleSlow({x:0,y:0},[field,{...field,slow:.6}])).toBe(.4);
  expect(()=>obstacleField({x:0,y:0},t,[])).toThrow('missing road');expect(()=>obstacleField({x:0,y:0},{...t,obstacle_radius:null},routes)).toThrow('tuning');
});
it('renders the original obstacle art through the exact native local transform and even-odd road mask',()=>{
  const context=Object.fromEntries(['drawImage','beginPath','moveTo','lineTo','closePath','clip'].map(k=>[k,vi.fn()]));
  const spy=vi.spyOn(HTMLCanvasElement.prototype,'getContext').mockReturnValue(context as unknown as CanvasRenderingContext2D);
  const field={position:{x:100,y:200},heading:0,radius:50,widthFraction:.5,slow:.3},source=document.createElement('img');
  const canvas=fieldArtwork(document,source,200,field,[[[50,175],[150,175],[150,225],[50,225],[50,175]]]);
  expect(canvas.width).toBe(200);expect(canvas.height).toBe(100);expect(context.moveTo).toHaveBeenCalledWith(0,100);expect(context.lineTo).toHaveBeenCalledWith(200,0);
  expect(context.clip).toHaveBeenCalledWith('evenodd');expect(context.drawImage).toHaveBeenCalledWith(source,0,0,200,100);
  spy.mockReturnValue(null);expect(()=>fieldArtwork(document,source,200,field,[])).toThrow('road mask');spy.mockRestore();
});
it('keeps the charge marker at native screen-point dimensions with a broad blinking light',()=>{
  const on=chargeSymbol({x:100,y:200},0),off=chargeSymbol({x:100,y:200},.7);
  expect(on[0]).toMatchObject({kind:'ellipse',x:100,y:200,width:27,height:12});
  expect(on.at(-1)).toMatchObject({kind:'circle',width:10.8,color:0xff1721});expect(off.at(-1)!.color).toBe(0x47090b);
});
