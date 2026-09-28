import { afterEach, beforeAll, beforeEach, expect, it, vi } from 'vitest';
import { authored, battleSession, type Authored } from './fixtures';
import type { ContentDatabase } from '../src/content/database';
import type { BattleSession } from '../src/game/session';
import { inRange, nearestRangePoint, rallyPoint } from '../src/game/towers';
import { Route, distance } from '../src/game/navigation';
import { MetaEffects, upgraded, type TowerKind } from '../src/game/tower-tuning';

let fixture: Authored, db: ContentDatabase, session: BattleSession;
beforeAll(async () => { fixture = await authored(); });
beforeEach(async () => {
  db = fixture.open(); db.db.run('UPDATE level_tower_unlock SET max_tower_level=4');
  session = await battleSession(db); session.money = 100000;
  session.player.meta.selections.forEach(s => { s.is_selected = 0; });
});
afterEach(() => db.close());
function build(kind: TowerKind, index = 0) {
  const t = session.towers; t.select(session.content.slots[index]!.index);
  expect(t.tapBuild(kind)).toBeNull(); expect(t.tapBuild(kind)).toBe('ok');
  return t.placed.at(-1)!;
}
it('reuses immutable tuning until tier, branch, ranks or selected meta upgrades change', () => {
  const t = session.towers, tower = build('ranged'), original = t.tuning(tower);
  const derive = vi.spyOn(t.meta, 'combat');
  for (let i = 0; i < 120; i++) expect(t.tuning(tower)).toBe(original);
  expect(derive).not.toHaveBeenCalled();
  expect(() => { original.tower_range = 0; }).toThrow();
  tower.level = 4;
  const advanced = t.tuning(tower), path = advanced.upgrades[0]!;
  expect(advanced).not.toBe(original); expect(Object.isFrozen(path.ranks)).toBe(true);
  tower.ranks[path.id] = 1;
  const ranked = t.tuning(tower); expect(ranked).not.toBe(advanced);
  expect(advanced).toEqual(t.meta.combat(upgraded(t.base('ranged', 4), {}), 'ranged'));
  delete tower.ranks[path.id]; expect(t.tuning(tower)).toEqual(advanced);
  tower.branch = t.content.towers.find(k => k.tower_type_key === 'ranged')!.tiers.find(p => p.tower_level === 4 && p.branch !== tower.branch)!.branch;
  expect(t.tuning(tower).id).not.toBe(advanced.id);
  tower.level = 1; tower.branch = 1;
  const player = structuredClone(session.player), selection = player.meta.selections.find(s => s.upgrade_key === 'rangeEstimation')!;
  selection.is_selected = 1; session.setPlayer(player);
  expect(t.tuning(tower).tower_range).toBe(original.tower_range * t.meta.value('rangeEstimation', 'rangeMultiplier')!);
  selection.is_selected = 0; expect(t.tuning(tower)).toEqual(original);
  tower.ranks.missing = 1; expect(() => t.tuning(tower)).toThrow('Unknown path');
});
it('creates a fresh tuning cache from reloaded SQL and still rejects missing authored tiers', async () => {
  const tower = build('ranged'), old = session.towers.tuning(tower);
  db.db.run('UPDATE tower SET tower_range=tower_range+17 WHERE id=?', [old.id]);
  const next = await battleSession(db); next.player.meta.selections.forEach(s => { s.is_selected = 0; });
  expect(next.towers.tuning(tower).tower_range).toBe(old.tower_range + 17);
  expect(session.towers.tuning(tower)).toBe(old);
  next.content.towers.find(k => k.tower_type_key === 'ranged')!.tiers = [];
  expect(() => next.towers.tuning(tower)).toThrow('Missing authored tier');
});
it('requires two matching build taps, cancels a mismatched arm, debits SQL prices once and replaces only the selected slot', () => {
  const t = session.towers, slot = session.content.slots[0]!, start = session.money, cost = t.base('ranged').cost;
  expect(t.tapBuild('ranged')).toBe('invalid'); t.select(-100); expect(t.selected).toBeNull();
  session.activate('primaryHero'); t.select(slot.index); expect(session.selectedHero).toBeNull();
  t.select(slot.index); expect(t.selected).toBeNull(); t.select(slot.index);
  expect(t.tapBuild('ranged')).toBeNull(); expect(t.range?.radius).toBe(t.base('ranged').tower_range);
  t.tapBuild('supply'); expect(t.armed).toBeNull(); expect(t.placed).toHaveLength(0);
  t.tapBuild('ranged'); expect(t.tapBuild('ranged')).toBe('ok');
  expect(session.money).toBe(start-cost); expect(t.placed[0]).toMatchObject({slot:slot.index,kind:'ranged',level:1,position:{x:slot.x,y:slot.y}});
  expect(t.selected).toBeNull(); t.select(slot.index); expect(t.tapBuild('supply')).toBe('invalid');
  expect(t.current).toBe(t.placed[0]); expect(t.range?.radius).toBe(t.base('ranged').tower_range);
  session.mapTap({x:0,y:0}); expect(t.selected).toBeNull();
});
it('preserves authored locks, no-money dismissal, pause restrictions and mutually exclusive input modes', () => {
  const t = session.towers, slot = session.content.slots[0]!.index;
  session.content.unlocks.find(u=>u.tower_kind==='supply')!.max_tower_level=0;
  t.select(slot); expect(t.tapBuild('supply')).toBe('invalid'); session.money=0;
  t.tapBuild('ranged'); expect(t.range).toBeNull(); expect(t.tapBuild('ranged')).toBe('needGold'); expect(t.selected).toBeNull();
  t.select(slot); session.activate('reinforcements'); expect(t.selected).toBeNull(); t.select(slot); expect(session.placing).toBe(false);
  session.pause(); t.select(slot); expect(t.selected).toBe(slot); expect(t.tapBuild('ranged')).toBe('invalid');
  expect(t.tapUpgrade(1)).toBe('invalid'); expect(t.tapPath('missing')).toBe('invalid'); t.beginPlacement(); expect(t.place({x:0,y:0})).toBe(false);
  session.resume(); session.selectHero(0); expect(t.selected).toBeNull();
  expect(t.tapUpgrade(1)).toBe('invalid'); expect(t.tapPath('missing')).toBe('invalid'); t.beginPlacement();
  expect(t.place({x:0,y:0})).toBe(false); expect(t.offers).toEqual([]); expect(t.paths).toEqual([]);
  expect(()=>t.base('ranged',99)).toThrow('ranged:99'); session.content.unlocks=[]; expect(()=>t.maxLevel('ranged')).toThrow('unlock');
});
it('upgrades every authored kind and branch, applies every specialty rank, and keeps completed paths inspectable', () => {
  const t=session.towers;
  for(const kind of session.content.towers) for(const tier of kind.tiers.filter(t=>t.tower_level===4)) {
    t.placed.splice(0); const tower=build(kind.tower_type_key);
    for(const level of [2,3,4]) {
      t.select(tower.slot); const branch=level===4?tier.branch:1;
      expect(t.offers.find(o=>o.branch===branch)).toBeDefined();
      expect(t.tapUpgrade(branch)).toBeNull(); const cost=t.offers.find(o=>o.branch===branch)!.cost, start=session.money;
      expect(t.tapUpgrade(branch)).toBe('ok'); expect(session.money).toBe(start-cost); expect(tower.level).toBe(level); expect(t.selected).toBeNull();
    }
    t.select(tower.slot); expect(t.offers).toEqual([]);
    for(const path of t.paths) {
      expect(t.tapPath(path.id)).toBeNull();
      for(const rank of path.ranks) {
        if(t.armed===null) expect(t.tapPath(path.id)).toBeNull();
        const start=session.money; expect(t.tapPath(path.id)).toBe('ok'); expect(session.money).toBe(start-rank.cost);
        expect(tower.ranks[path.id]).toBe(rank.rank); expect(t.selected).toBe(tower.slot); expect(t.armed).toBeNull();
      }
      t.tapPath(path.id); expect(t.tapPath(path.id)).toBe('invalid'); expect(t.armed).toBe(`path:${path.id}`);
    }
    expect(t.tuning(tower)).toBeDefined(); t.dismiss();
  }
});
it('changes upgrade branches directly, checks funds on confirmation and leaves insufficient specialty purchases selected', () => {
  const t=session.towers, tower=build('ranged'); tower.level=3; t.select(tower.slot);
  const branches=t.offers; expect(branches.length).toBeGreaterThan(1);
  t.tapUpgrade(branches[0]!.branch); t.tapUpgrade(branches[1]!.branch); expect(t.armed).toBe(`tier:${branches[1]!.branch}`);
  session.money=0; expect(t.range?.upgrade).toBeNull(); expect(t.tapUpgrade(branches[1]!.branch)).toBe('needGold'); expect(t.selected).toBeNull();
  tower.level=4; tower.branch=branches[0]!.branch; t.select(tower.slot); const p=t.paths[0]!;
  expect(t.tapPath(p.id)).toBeNull(); expect(t.tapPath(p.id)).toBe('needGold'); expect(t.armed).toBe(`path:${p.id}`); expect(t.selected).toBe(tower.slot);
  session.money=100000; expect(t.range).not.toBeNull(); expect(t.tapPath(p.id)).toBe('ok');
});
it('creates garrisons, heals on tier upgrade, applies HP/rate rank deltas and moves rally formations within the native circle', () => {
  const t=session.towers,tower=build('melee'),base=t.tuning(tower),soldier=session.soldiers[0]!;
  expect(session.soldiers).toHaveLength(base.melee!.soldier_count); expect(tower.rally).not.toBeNull();
  soldier.hp=1; t.select(tower.slot); t.tapUpgrade(1); t.tapUpgrade(1); expect(soldier.hp).toBe(t.tuning(tower).melee!.hp);
  soldier.hp=1; t.select(tower.slot); t.beginPlacement(); const requested=tower.position;
  expect(t.placement).toBe('rally'); expect(t.place(requested)).toBe(true); expect(soldier.hp).toBe(1);
  expect(distance(tower.rally!,tower.position)).toBeLessThanOrEqual(t.tuning(tower).melee!.rally_point_radius+1e-8);
  expect(t.flash).toEqual(tower.rally); expect(session.soldiers.every(s=>s.rally===tower.rally)).toBe(true);
  t.advance(3.5);expect(t.flashRemaining).toBe(.5);t.advance(1);expect(t.flash).toBeNull();
  t.select(tower.slot);t.beginPlacement();expect(t.place({x:1e6,y:1e6})).toBe(false);expect(t.selected).toBeNull();
  for(const level of [3,4]) {t.select(tower.slot);t.tapUpgrade(1);t.tapUpgrade(1);expect(tower.level).toBe(level);}
  t.select(tower.slot);soldier.hp=1;soldier.swing=20;soldier.respawn=20;
  const path=t.paths.find(p=>p.ranks.some(r=>r.effects_json.some(e=>e.attribute==='meleeHP')))!;
  t.tapPath(path.id);const before=t.tuning(tower).melee!;t.tapPath(path.id);const after=t.tuning(tower).melee!;
  expect(soldier.hp).toBe(1+Math.max(0,after.hp-before.hp));expect(soldier.combat).toMatchObject(after);
});
it('starts engineers on the nearest available road, repositions within the ellipse and makes new sapper charges ready but unplaced', () => {
  const t=session.towers,tower=build('special');expect(tower.site).not.toBeNull();
  t.select(tower.slot);t.beginPlacement();expect(t.placement).toBe('obstacles');expect(t.place(tower.position)).toBe(true);
  for(const level of [2,3]) {t.select(tower.slot);t.tapUpgrade(1);t.tapUpgrade(1);expect(tower.level).toBe(level);}
  t.select(tower.slot);const sapper=t.offers.find(o=>o.tier.has_demolition_charge)!;
  t.tapUpgrade(sapper.branch);t.tapUpgrade(sapper.branch);expect(tower.site).toBeNull();expect(tower.charge).toBeNull();
  t.select(tower.slot);t.beginPlacement();expect(t.placement).toBe('charge');expect(t.place(tower.position)).toBe(true);expect(tower.charge).not.toBeNull();
  expect(tower.chargeRemaining).toBe(0);t.select(tower.slot);t.beginPlacement();expect(t.place(tower.position)).toBe(true);expect(tower.chargeRemaining).toBe(0);
  tower.charge={x:tower.charge!.x+1,y:tower.charge!.y};t.select(tower.slot);t.beginPlacement();t.place(tower.position);expect(tower.chargeRemaining).toBe(t.tuning(tower).demolition_prepare_seconds);
  t.advance(.5);expect(tower.chargeRemaining).toBe(t.tuning(tower).demolition_prepare_seconds!-.5);
  t.select(tower.slot);t.beginPlacement();const previous=tower.charge;expect(t.place({x:1e8,y:0})).toBe(false);expect(tower.charge).toEqual(previous);
  t.select(tower.slot);session.content.routes=[new Route([{x:1e9,y:0},{x:1e9+100,y:0}])];t.beginPlacement();expect(t.place(tower.position)).toBe(false);
});
it('omits impossible sapper upgrades, exposes authored unlock caps and pays supply income once for each wave including the first', () => {
  const t=session.towers,tower=build('special');tower.level=3;t.select(tower.slot);
  session.content.routes=[new Route([{x:1e9,y:0},{x:1e9+100,y:0}])];expect(t.offers.every(o=>!o.tier.has_demolition_charge)).toBe(true);
  session.content.unlocks.find(u=>u.tower_kind==='special')!.max_tower_level=3;expect(t.offers).toEqual([]);
  t.dismiss();const supply=build('supply',1);t.select(supply.slot);t.beginPlacement();expect(t.placement).toBeNull();t.dismiss();
  const money=session.money,p=session.hud.callWavePositions[0]!,income=t.tuning(supply).income_per_wave;
  session.tapWave(p);session.tapWave(p);expect(session.money).toBe(money+income);session.tapWave(p);expect(session.money).toBe(money+income);
});
it('clips whole road segments to the range ellipse and samples/clamps rallies rather than snapping to arbitrary endpoints', () => {
  const route=new Route([{x:-100,y:0},{x:100,y:0}]),o={x:0,y:0};
  expect(nearestRangePoint({x:90,y:30},o,40,.5,[route])).toEqual({x:40,y:0});
  expect(nearestRangePoint(o,o,0,.5,[route])).toBeNull();expect(nearestRangePoint({x:NaN,y:0},o,20,.5,[route])).toBeNull();
  expect(nearestRangePoint(o,{x:0,y:80},20,.5,[route])).toBeNull();expect(nearestRangePoint(o,{x:300,y:0},20,.5,[route])).toBeNull();
  const duplicate=new Route([{x:0,y:0},{x:0,y:0},{x:100,y:0}]);expect(nearestRangePoint(o,o,10,.5,[duplicate])).toEqual(o);
  expect(nearestRangePoint(o,{x:500,y:0},10,.5,[duplicate])).toBeNull();
  expect(inRange({x:0,y:21},o,40,.5)).toBe(false);expect(inRange({x:0,y:20},o,40,.5)).toBe(true);expect(inRange(o,o,0,.5)).toBe(false);
  expect(rallyPoint({x:1,y:0},o,40,[route])).toEqual({x:-4,y:0});expect(rallyPoint({x:80,y:0},o,40,[route])).toEqual({x:40,y:0});
  expect(rallyPoint(o,o,40,[])).toEqual(o);
});
it('uses selected SQL meta effects for pricing, range, cadence, service, incomes and melee instead of copied defaults', () => {
  const t=session.towers,meta=t.meta;
  for(const entry of session.content.catalog.upgrades) {
    const selection=session.player.meta.selections.find(s=>s.upgrade_key===entry.upgrade_key);
    if(selection)selection.is_selected=1;else session.player.meta.selections.push({profile_key:'active',upgrade_key:entry.upgrade_key,is_selected:1});
  }
  const effect=(key: Parameters<MetaEffects['value']>[0],p:string)=>meta.value(key,p)!;
  expect(meta.cost(t.base('supply'),'supply',false,true,false)).toBe(Math.ceil(t.base('supply').cost*effect('localSuppliers','priceMultiplier')*effect('artificerCorps','priceMultiplier')-1e-9));
  const ranged=t.base('ranged');expect(meta.combat(ranged,'ranged').tower_range).toBe(ranged.tower_range*effect('rangeEstimation','rangeMultiplier'));
  for(const kind of session.content.towers)for(const base of kind.tiers) {
    expect(meta.combat(base,kind.tower_type_key).tower_range).toBeGreaterThanOrEqual(0);
    expect(meta.cost(base,kind.tower_type_key,true,true,true)).toBeLessThanOrEqual(base.cost);
  }
  const supply=build('supply'),target=session.content.slots[1]!;supply.position={x:target.x,y:target.y};
  const tower=build('ranged',1);t.select(tower.slot);const base=t.base('ranged',2);
  expect(t.cost('ranged',2,1,tower.slot)).toBe(meta.cost(base,'ranged',false,true,true));
  t.tapUpgrade(1);t.tapUpgrade(1);expect(t.cost('ranged',2)).toBe(meta.cost(base,'ranged',true,true,false));
  t.select(tower.slot);t.tapUpgrade(1);t.tapUpgrade(1);t.select(tower.slot);const offer=t.offers[0]!;t.tapUpgrade(offer.branch);t.tapUpgrade(offer.branch);
  expect(t.cost('ranged',4,offer.branch)).toBe(meta.cost(offer.tier,'ranged',false,false,false));
  session.content.catalog.upgrades.find(u=>u.upgrade_key==='rangeEstimation')!.effects=[];expect(()=>meta.combat(ranged,'ranged')).toThrow('rangeEstimation');
});
it('propagates SQL tower edits and rejects missing/invalid required content and incompatible purchased tuning', async () => {
  const base=session.towers.base('ranged');db.db.run('UPDATE tower SET cost=321,tower_range=456 WHERE id=?',[base.id]);
  const next=await battleSession(db);next.player.meta.selections.forEach(s=>{s.is_selected=0;});
  expect(next.towers.cost('ranged')).toBe(321);expect(next.towers.base('ranged').tower_range).toBe(456);
  expect(()=>upgraded(base,{missing:1})).toThrow('Unknown path');
  const specialty=session.content.towers.flatMap(k=>k.tiers).find(t=>t.upgrades.length)!;const path=specialty.upgrades[0]!;
  expect(()=>upgraded(specialty,{[path.id]:-1})).toThrow('Invalid purchased rank');
  const broken=structuredClone(specialty);broken.upgrades[0]!.ranks[0]!.effects_json=[{attribute:'meleeHP',delta:1}];broken.melee=null;
  expect(()=>upgraded(broken,{[path.id]:1})).toThrow('Incompatible');
  broken.upgrades[0]!.ranks[0]!.effects_json=[{attribute:'preparation',delta:1}];broken.demolition_prepare_seconds=null;
  expect(()=>upgraded(broken,{[path.id]:1})).toThrow('Incompatible');
  broken.upgrades[0]!.ranks[0]!.effects_json=[{attribute:'fireInterval',delta:-1e6}];expect(()=>upgraded(broken,{[path.id]:1})).toThrow('Incompatible');
  db.db.run('DELETE FROM level_tower_unlock WHERE tower_kind=?',['ranged']);await expect(battleSession(db)).rejects.toThrow('unlock');
});
