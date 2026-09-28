import { beforeAll, expect, it, vi } from 'vitest';
import type Phaser from 'phaser';
import { ActorMarks } from '../src/game/actor-marks';
import { actorPlan } from '../src/game/actors';
import { moralePlan } from '../src/game/combat-view';
import { EnemyMorale } from '../src/game/combat-math';
import { hudCanvas } from '../src/hud/layout';
import { authored, battleSession, testManifest } from './fixtures';
import type { BattleSession } from '../src/game/session';
let session:BattleSession,art:ReturnType<typeof testManifest>;
beforeAll(async()=>{const db=(await authored()).open();try{session=await battleSession(db);art=testManifest(db,session.presentation);}finally{db.close();}});
function setup(){
  const graphics=Object.fromEntries(['setVisible','setPosition','setDepth','clear','lineStyle','beginPath','arc','strokePath','fillStyle','fillCircle','strokeCircle','strokeRoundedRect','fillRoundedRect']
    .map(k=>[k,vi.fn().mockReturnThis()]));
  return {graphics,marks:new ActorMarks(graphics as unknown as Phaser.GameObjects.Graphics)};
}
function plan(x=100,y=200,width=874,height=402){
  return actorPlan({...session.actors(1)[0]!,position:{x,y},health:.5,selected:true},hudCanvas(session.content.config.canvas,width,height,session.presentation.towerGeometry),art,session.presentation);
}
it('moves retained health and selection geometry without redrawing, then updates damage, size and visibility',()=>{
  const {graphics:g,marks}=setup(),p=plan(),minimum=session.presentation.healthHeight.minimum;
  marks.update(p,null,minimum);
  expect(g.fillRoundedRect).toHaveBeenLastCalledWith(p.healthOffset.x,p.healthOffset.y,p.healthRect.width*.5,p.healthRect.height,p.healthRect.height/2);
  expect(g.strokeCircle).toHaveBeenCalledWith(0,p.selectionOffsetY,p.selection.radius);
  for(const fn of Object.values(g))fn.mockClear();
  const moved=plan(171.345,287.891);marks.update(moved,null,minimum);
  expect(g.clear).not.toHaveBeenCalled();expect(g.setPosition).toHaveBeenCalledWith(moved.foot.x,moved.foot.y);
  marks.update(moved,null,minimum);expect(g.setPosition).toHaveBeenCalledOnce();
  marks.update({...moved,health:.2,kind:'militia',depth:12},null,minimum);
  expect(g.fillRoundedRect).toHaveBeenLastCalledWith(moved.healthOffset.x,moved.healthOffset.y,moved.healthRect.width*.2,moved.healthRect.height,moved.healthRect.height/2);
  expect(g.fillStyle).toHaveBeenLastCalledWith(0x007aff);expect(g.setDepth).toHaveBeenLastCalledWith(12.00001);
  marks.update({...moved,health:1,selected:false},null,minimum);expect(g.setVisible).toHaveBeenLastCalledWith(false);
  const resized=plan(171.345,287.891,1600,900);marks.update(resized,null,minimum);
  expect(g.setVisible).toHaveBeenLastCalledWith(true);expect(g.strokeCircle).toHaveBeenLastCalledWith(0,resized.selectionOffsetY,resized.selection.radius);
});
it('keeps a continuous fixed morale track while its remaining blue fill shrinks',()=>{
  const {graphics:g,marks}=setup(),p={...plan(),selected:false,health:1},minimum=session.presentation.healthHeight.minimum;
  const state=new EnemyMorale(session.content.config.combat);state.apply(40,1);
  const m=moralePlan(state,{x:0,y:0},p.frame.height,session.presentation,true);
  marks.update(p,m,minimum);const track=g.arc!.mock.calls[0],fill=g.arc!.mock.calls[1];
  expect(track).toBeDefined();expect(fill).toBeDefined();
  g.clear!.mockClear();g.arc!.mockClear();marks.update(p,m,minimum);expect(g.clear).not.toHaveBeenCalled();
  state.apply(40,1);const damaged=moralePlan(state,{x:0,y:0},p.frame.height,session.presentation,true);
  marks.update(p,damaged,minimum);expect(g.arc!.mock.calls[0]).toEqual(track);
  expect(g.arc!.mock.calls[1]![4]).toBeLessThan(fill![4]);
  g.arc!.mockClear();marks.update(p,{...damaged,fraction:0},minimum);expect(g.arc).toHaveBeenCalledOnce();
  marks.update(p,{...damaged,visible:false},minimum);expect(g.setVisible).toHaveBeenLastCalledWith(false);
});
