// @vitest-environment jsdom
import { beforeAll, beforeEach, expect, it, vi } from 'vitest';
import { authored, hudBattle, battleSession, type Authored } from './fixtures';
import { battlefieldPlan } from '../src/game/battlefield';
import { hudImageKeys } from '../src/hud/view';
import { EnemyMorale } from '../src/game/combat-math';
import { actorPlan, destination } from '../src/game/actors';
import { BattleStore } from '../src/game/store';
import { ticks } from '../src/game/schedules';
import { hudCanvas } from '../src/hud/layout';

const fake = vi.hoisted(() => ({ game: undefined as unknown, scene: undefined as unknown, fail: false }));
vi.mock('phaser', async () => {
  const { EventEmitter } = await import('node:events');
  class Scene {
    scale = Object.assign(new EventEmitter(), { width: 800, height: 450 });
    events = new EventEmitter();
    load = Object.assign(new EventEmitter(), { image: vi.fn() });
    children = { removeAll: vi.fn() };
    textures = { get: vi.fn(() => ({add:vi.fn(),getSourceImage:()=>document.createElement('canvas')})),remove:vi.fn(),addCanvas:vi.fn() };
    add = { group: vi.fn(() => {
      const images:{active:boolean;setActive(v:boolean):unknown;setVisible(v:boolean):unknown}[]=[];
      return {add:(image:typeof images[number])=>images.push(image),getFirstDead:()=>images.find(i=>!i.active)??null,
        killAndHide:(image:typeof images[number])=>{image.setActive(false);image.setVisible(false);}};
    }),image: vi.fn(() => ({ active:true,setActive:vi.fn(function(this:{active:boolean},value:boolean){this.active=value;return this;}),setVisible:vi.fn().mockReturnThis(),
      setOrigin: vi.fn().mockReturnThis(), setDisplaySize: vi.fn().mockReturnThis(), setDepth: vi.fn().mockReturnThis(),
      setTexture: vi.fn().mockReturnThis(), setPosition: vi.fn().mockReturnThis(),setRotation:vi.fn().mockReturnThis(),setAlpha:vi.fn().mockReturnThis(), destroy: vi.fn() })),
      graphics: vi.fn(() => Object.fromEntries(['setVisible','setPosition','strokeEllipse','beginPath','arc','strokePath','clear', 'setDepth', 'lineStyle', 'strokeCircle', 'fillStyle','fillCircle','fillEllipse', 'strokeRoundedRect', 'fillRoundedRect', 'destroy'].map(key => [key, vi.fn().mockReturnThis()]))) };
    preload() {} create() {}
  }
  class Game {
    destroy = vi.fn();
    constructor(config: { scene: (new () => Scene)[] }) {
      fake.game = this;
      const scene = new config.scene[0]!(); fake.scene = scene;
      queueMicrotask(() => {
        scene.preload(); scene.load.emit('progress', 1);
        if (fake.fail) scene.load.emit('loaderror', { key: 'broken-image' });
        scene.create();
      });
    }
  }
  return { default: { Scene, Game, AUTO: 0, Scale: { RESIZE: 5 } } };
});
import { render, type HudBattlefield } from '../src/game/renderer';
let battle: HudBattlefield, fixture: Authored;
beforeAll(async () => {
  fixture = await authored(); battle = await hudBattle(fixture);
});
beforeEach(() => { fake.fail = false;
  vi.spyOn(HTMLCanvasElement.prototype,'getContext').mockReturnValue(Object.fromEntries(['drawImage','beginPath','moveTo','lineTo','closePath','clip'].map(k=>[k,vi.fn()])) as unknown as CanvasRenderingContext2D);
  vi.spyOn(HTMLCanvasElement.prototype,'toDataURL').mockReturnValue('data:image/png;base64,cursor');
});
it('queues canonical textures once, reuses map objects on resize, and detaches handlers', async () => {
  fake.fail = false; const progress = vi.fn(); const renderer = render(document.createElement('div'), battle, progress);
  await renderer.ready;
  const scene = fake.scene as { load: { image: ReturnType<typeof vi.fn> }; add: { image: ReturnType<typeof vi.fn> };
    scale: import('node:events').EventEmitter; events: import('node:events').EventEmitter };
  expect(scene.load.image).toHaveBeenCalledTimes(2 + hudImageKeys(battle.hud.state).length);
  expect(scene.add.image).toHaveBeenCalledTimes(battle.slots.length + 1);
  scene.scale.emit('resize');
  expect(scene.add.image).toHaveBeenCalledTimes(battle.slots.length + 1);
  scene.events.emit('shutdown'); expect(scene.scale.listenerCount('resize')).toBe(0);
  expect(progress).toHaveBeenCalledWith(1);
  renderer.destroy(); expect((fake.game as { destroy: ReturnType<typeof vi.fn> }).destroy).toHaveBeenCalledWith(true);
});
it('reprojects the same scene when the viewport and browser safe insets change', async () => {
  const host = document.createElement('div');
  document.body.append(host);
  host.style.setProperty('--safe-left', '30px');
  host.style.setProperty('--safe-right', '10px');
  const renderer = render(host, battle, () => {});
  await renderer.ready;
  const game = fake.game;
  const scene = fake.scene as { add: { image: ReturnType<typeof vi.fn> }; load: { image: ReturnType<typeof vi.fn> };
    scale: import('node:events').EventEmitter & { width: number; height: number } };
  let plan = battlefieldPlan(battle, 800, 450, { left: 30, right: 10, top: 0, bottom: 0 });
  expect(scene.add.image).toHaveBeenNthCalledWith(1, plan[0]!.x, plan[0]!.y, plan[0]!.key);
  const images=scene.add.image.mock.results.map(r=>r.value);
  host.style.setProperty('--safe-left', '0px');
  host.style.setProperty('--safe-right', '0px');
  host.style.setProperty('--safe-top', '44px');
  host.style.setProperty('--safe-bottom', '34px');
  Object.assign(scene.scale, { width: 390, height: 844 });
  scene.scale.emit('resize');
  plan = battlefieldPlan(battle, 390, 844, { left: 0, right: 0, top: 44, bottom: 34 });
  plan.forEach((p, index) => {
    expect(images[index].setPosition).toHaveBeenLastCalledWith(p.x,p.y);
    expect(images[index].setDisplaySize).toHaveBeenLastCalledWith(p.width,p.height);
    expect(images[index].destroy).not.toHaveBeenCalled();
  });
  expect(scene.add.image).toHaveBeenCalledTimes(images.length);
  expect(fake.game).toBe(game);
  expect(scene.load.image).toHaveBeenCalledTimes(2 + hudImageKeys(battle.hud.state).length);
  renderer.destroy(); host.remove();
});
it('rejects malformed browser safe geometry', async () => {
  const host = document.createElement('div');
  host.style.setProperty('--safe-top', 'invalid');
  const renderer = render(host, battle, () => {});
  await expect(renderer.ready).rejects.toThrow('Invalid viewport safe insets');
  renderer.destroy();
});
it('rejects failed required textures instead of showing placeholder art', async () => {
  fake.fail = true;
  const renderer = render(document.createElement('div'), battle, () => {});
  await expect(renderer.ready).rejects.toThrow('broken-image'); renderer.destroy();
});
it('renders and updates living actors, health, selection and diagnostics without rebuilding the map', async () => {
  const db = fixture.open(), session = await battleSession(db); db.close();
  const host = document.createElement('div'); document.body.append(host);
  const renderer = render(host, { ...battle, store: new BattleStore(session) }, () => {}); await renderer.ready;
  const scene = fake.scene as { update(): void; add: { image: ReturnType<typeof vi.fn>; graphics: ReturnType<typeof vi.fn> };
    scale: import('node:events').EventEmitter };
  const before = scene.add.image.mock.calls.length;
  session.activate('primaryHero'); session.heroes[0]!.hp /= 2; scene.update();
  expect(scene.add.image).toHaveBeenCalledTimes(before);
  const marks = scene.add.graphics.mock.results.find(r=>r.value.strokeCircle.mock.calls.length>0)!.value;
  expect(marks.strokeCircle).toHaveBeenCalled(); expect(marks.fillRoundedRect).toHaveBeenCalled();
  session.player.settings.show_debug_info = 1; scene.update(); expect(host.querySelector<HTMLElement>('.simulation-readout')!.hidden).toBe(false);
  session.activate('reinforcements'); session.mapTap(session.content.routes[0]!.point(200)); session.advance(1); scene.update();
  session.soldiers[0]!.hp /= 2; scene.update();
  const old = scene.add.image.mock.results.at(-1)!.value;
  session.soldiers = []; scene.update(); expect(old.destroy).toHaveBeenCalledOnce();
  session.heroes[0]!.state = 'dead'; scene.update();
  scene.scale.emit('resize'); renderer.destroy(); expect(host.querySelector('.simulation-readout')).toBeNull(); host.remove();
});
it('replaces open slot artwork, renders towers and road-clipped obstacles, shows rally/charge feedback and updates resized placements',async()=>{
  const db=fixture.open();db.db.run('UPDATE level_tower_unlock SET max_tower_level=4');const session=await battleSession(db);db.close();session.money=100000;
  const host=document.createElement('div');document.body.append(host);const renderer=render(host,{...battle,store:new BattleStore(session)},()=>{});await renderer.ready;
  const scene=fake.scene as {update():void;add:{image:ReturnType<typeof vi.fn>;graphics:ReturnType<typeof vi.fn>};textures:{addCanvas:ReturnType<typeof vi.fn>;remove:ReturnType<typeof vi.fn>};scale:import('node:events').EventEmitter};
  const t=session.towers,slot=session.content.slots[0]!.index;t.select(slot);t.tapBuild('special');t.tapBuild('special');scene.update();
  expect(scene.add.image.mock.results.some(r=>r.value.setTexture.mock.calls.some((call:unknown[])=>call[0]==='tower_slot_field'))).toBe(true);expect(scene.textures.addCanvas).toHaveBeenCalledOnce();
  scene.update();expect(scene.textures.addCanvas).toHaveBeenCalledOnce();const tower=t.placed[0]!;tower.site={x:tower.site!.x+1,y:tower.site!.y};scene.update();expect(scene.textures.remove).toHaveBeenCalled();
  tower.site=null;tower.level=4;tower.branch=session.content.towers.find(k=>k.tower_type_key==='special')!.tiers.find(l=>l.has_demolition_charge)!.branch;
  tower.charge=tower.position;t.select(slot);scene.update();expect(scene.add.graphics.mock.results.some(r=>r.value.fillCircle.mock.calls.length)).toBe(true);
  tower.chargeRemaining=2;scene.update();t.flash=tower.position;t.flashRemaining=4;scene.update();expect(scene.add.image.mock.calls.some(call=>call[2]==='rally_point_icon')).toBe(true);
  t.flash=null;scene.update();scene.scale.emit('resize');renderer.destroy();host.remove();
});
it('uses native hero hit targets and map projection, ignores drags/cancellations and removes pointer listeners', async () => {
  const db = fixture.open(), session = await battleSession(db); db.close();
  const host = document.createElement('div'), canvas = document.createElement('canvas'); host.append(canvas); document.body.append(host);
  host.getBoundingClientRect = () => ({ x: 20, y: 30, width: 800, height: 450 } as DOMRect);
  const renderer = render(host, { ...battle, store: new BattleStore(session) }, () => {}); await renderer.ready;
  const view = hudCanvas(battle.canvas, 800, 450,battle.presentation.towerGeometry), plan = actorPlan(session.actors(1)[0]!, view, battle.manifest, session.presentation);
  const event = (type: string, x: number, y: number, target: HTMLElement = canvas, id = 1) => {
    const event = new MouseEvent(type, { clientX: x + 20, clientY: y + 30, bubbles: true }); Object.defineProperty(event, 'pointerId', { value: id }); target.dispatchEvent(event);
  };
  const tap = (x: number, y: number) => { event('pointerdown', x, y); event('pointerup', x, y); };
  const center = { x: plan.tapRect.x + plan.tapRect.width / 2, y: plan.tapRect.y + plan.tapRect.height / 2 };
  event('pointerup', center.x, center.y); expect(session.selectedHero).toBeNull();
  event('pointerdown', center.x, center.y, host); event('pointerup', center.x, center.y); expect(session.selectedHero).toBeNull();
  event('pointerdown', center.x, center.y); event('pointercancel', center.x, center.y); event('pointerup', center.x, center.y); expect(session.selectedHero).toBeNull();
  event('pointerdown', center.x - 50, center.y); event('pointerup', center.x, center.y); expect(session.selectedHero).toBeNull();
  event('pointerdown', center.x, center.y); event('pointerup', center.x, center.y, canvas, 2); expect(session.selectedHero).toBeNull();
  event('pointerdown', center.x, center.y); event('pointerup', center.x, center.y, host); expect(session.selectedHero).toBeNull();
  event('pointerdown', center.x, center.y); event('pointerleave', center.x, center.y); event('pointerup', center.x, center.y); expect(session.selectedHero).toBeNull();
  // A HUD gesture replaces any stale canvas press; its release cannot select a hero.
  event('pointerdown', center.x, center.y); event('pointerdown', center.x, center.y, host); event('pointerup', center.x, center.y); expect(session.selectedHero).toBeNull();
  tap(center.x, center.y); expect(session.selectedHero).toBe(0);
  tap(0, 0); expect(session.selectedHero).toBe(0);
  const point = session.content.routes[0]!.point(session.content.routes[0]!.total * .6), screen = view.point(point.x, point.y);
  expect(destination(view, screen)).not.toBeNull(); tap(screen.x, screen.y); expect(session.selectedHero).toBeNull();
  expect(session.heroes[0]!.station.x).toBeCloseTo(point.x); expect(session.heroes[0]!.station.y).toBeCloseTo(point.y);
  session.pause(); tap(center.x, center.y); expect(session.selectedHero).toBeNull();
  session.resume(); tap(400, 50); expect(session.selectedHero).toBeNull();
  renderer.destroy(); tap(center.x, center.y); expect(session.selectedHero).toBeNull(); host.remove();
});

it('preserves live actors, towers and obstacle textures across building and resizing',async()=>{
  const db=fixture.open();db.db.run('UPDATE level_tower_unlock SET max_tower_level=4');
  const session=await battleSession(db);db.close();session.money=100000;
  const host=document.createElement('div'),store=new BattleStore(session),renderer=render(host,{...battle,store},()=>{});await renderer.ready;
  const scene=fake.scene as {update():void;add:{image:ReturnType<typeof vi.fn>};children:{removeAll:ReturnType<typeof vi.fn>};
    textures:{addCanvas:ReturnType<typeof vi.fn>;remove:ReturnType<typeof vi.fn>};scale:import('node:events').EventEmitter&{width:number;height:number}};
  const initial=scene.add.image.mock.results.map(r=>r.value);
  const build=(index:number)=>{store.dispatch({type:'selectTower',slot:session.content.slots[index]!.index});
    store.dispatch({type:'buildTower',kind:'special'});store.dispatch({type:'buildTower',kind:'special'});
    expect(session.towers.placed).toHaveLength(index+1);scene.update();};
  build(0);expect(scene.add.image).toHaveBeenCalledTimes(initial.length+2);
  for(const image of initial)expect(image.destroy).not.toHaveBeenCalled();
  const after=scene.add.image.mock.results.map(r=>r.value), textures=scene.textures.addCanvas.mock.calls.length;
  Object.assign(scene.scale,{width:390,height:844});scene.scale.emit('resize');
  expect(scene.add.image).toHaveBeenCalledTimes(after.length);expect(scene.textures.addCanvas).toHaveBeenCalledTimes(textures);
  expect(scene.textures.remove).not.toHaveBeenCalled();for(const image of after)expect(image.destroy).not.toHaveBeenCalled();
  build(1);expect(scene.add.image).toHaveBeenCalledTimes(after.length+2);
  expect(scene.children.removeAll).not.toHaveBeenCalled();
  session.towers.placed.splice(0);scene.update();expect(scene.textures.remove).toHaveBeenCalledTimes(2);
  renderer.destroy();
});

it('renders shots, impact frames and continuous morale cues and removes completed effects', async () => {
  const db=fixture.open(),session=await battleSession(db);db.close();
  const host=document.createElement('div'),renderer=render(host,{...battle,store:new BattleStore(session)},()=>{});await renderer.ready;
  const scene=fake.scene as {update():void;add:{image:ReturnType<typeof vi.fn>;graphics:ReturnType<typeof vi.fn>};scale:import('node:events').EventEmitter};
  const point=session.content.routes[0]!.point(200),type=session.content.enemies[0]!,morale=new EnemyMorale(session.content.config.combat);
  morale.apply(40,1);morale.age=.2;
  session.enemies=[{id:1,type,path:0,along:200,spawnTick:0,position:point,previous:point,hp:100,maximumHP:100,morale}];
  session.combat.projectiles=[{id:1,slot:0,kind:'areaOfEffect',tuning:session.towers.base('areaOfEffect'),position:point,previous:point,origin:point,
    heading:.5,target:1,damage:10,impact:point,remaining:100,volley:1,hits:new Set()}];
  session.combat.impacts=[{id:2,position:point,radius:100,age:.075,demolition:true},{id:3,position:point,radius:50,age:.3,demolition:false}];
  scene.update();scene.update();
  expect(scene.add.image.mock.calls.some(c=>c[2]===session.presentation.towers.areaOfEffect.projectile.asset)).toBe(true);
  expect(scene.add.image.mock.calls.some(c=>c[2]===session.presentation.explosion.asset&&c[3]==='1')).toBe(true);
  expect(scene.add.graphics.mock.results.some(r=>r.value.arc.mock.calls.length===2)).toBe(true);
  const projectile=session.combat.projectiles[0]!,count=scene.add.image.mock.calls.length;
  scene.scale.emit('resize');expect(scene.add.image).toHaveBeenCalledTimes(count);
  session.combat.projectiles=[];session.combat.impacts=[];scene.update();
  expect(scene.add.image.mock.results.some(r=>r.value.setVisible.mock.calls.some((c:unknown[])=>c[0]===false))).toBe(true);
  session.combat.projectiles=[{...projectile,id:99,heading:0}];scene.update();
  expect(scene.add.image).toHaveBeenCalledTimes(count);
  renderer.destroy();
});

it('synchronously enables reinforcements at cooldown completion and updates every input surface on the first click', async () => {
  let now=0;
  const db=fixture.open();db.db.run('UPDATE reinforcement_config SET cooldown_seconds=1');
  const session=await battleSession(db,undefined,()=>now);db.close();const store=new BattleStore(session);
  const host=document.createElement('div');document.body.append(host);
  const renderer=render(host,{...battle,store},()=>{});await renderer.ready;
  const scene=fake.scene as {update():void;events:import('node:events').EventEmitter;scale:import('node:events').EventEmitter};
  const changed=vi.fn();scene.events.on('battle-state-changed',changed);
  const button=host.querySelector<HTMLButtonElement>('[data-control="reinforcements"]')!;
  const slot=host.querySelector<HTMLButtonElement>('[data-target^="slot:"]')!;
  slot.click();expect(host.querySelector('.tower-choice')).not.toBeNull();
  button.click();
  expect(session.placing).toBe(true);expect(host.style.cursor).toBe('crosshair');expect(slot.disabled).toBe(true);
  expect(host.querySelector('.tower-choice')).toBeNull();expect(button.getAttribute('aria-description')).toBe('Selected');
  store.dispatch({type:'mapTap',point:session.content.routes[0]!.point(200)});
  expect(button.disabled).toBe(true);expect(host.style.cursor).toBe('');expect(slot.disabled).toBe(false);
  const ready=ticks(session.content.config.reinforcement.cooldown_seconds);
  for(let i=1;i<ready;i++){now=(i+.01)*1000/30;scene.update();}
  expect(button.disabled).toBe(true);button.click();expect(session.placing).toBe(false);
  now=(ready+.01)*1000/30;scene.update();
  expect(button.disabled).toBe(false);expect(button.getAttribute('aria-description')).toBe('Ready');
  expect(host.querySelector('[data-control="reinforcements"]')).toBe(button);
  expect(host.querySelector('.hud-cooldown')).toBeNull();
  // A complete press spans a rendering update and a resize without detaching.
  button.dispatchEvent(new MouseEvent('pointerdown',{bubbles:true}));scene.update();scene.scale.emit('resize');
  button.dispatchEvent(new MouseEvent('pointerup',{bubbles:true}));button.click();
  expect(session.placing).toBe(true);expect(button.getAttribute('aria-description')).toBe('Selected');
  expect(host.style.cursor).toBe('crosshair');expect(changed).toHaveBeenCalled();
  store.dispatch({type:'pause'});expect(button.disabled).toBe(true);expect(host.style.cursor).toBe('');
  store.dispatch({type:'resume'});expect(button.disabled).toBe(false);expect(host.style.cursor).toBe('crosshair');
  const count=changed.mock.calls.length;scene.events.emit('shutdown');
  store.dispatch({type:'activate',control:'reinforcements'});expect(changed).toHaveBeenCalledTimes(count);
  renderer.destroy();host.remove();
});
