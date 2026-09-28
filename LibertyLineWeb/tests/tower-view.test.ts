// @vitest-environment jsdom
import { afterEach, beforeAll, beforeEach, expect, it, vi } from 'vitest';
import { authored, battleSession, testManifest, type Authored } from './fixtures';
import { BattleStore } from '../src/game/store';
import type { BattleSession } from '../src/game/session';
import type { Manifest } from '../src/content/schema';
import { towerCursor, mountTowerUI } from '../src/hud/tower-view';
import { labelPlacement, towerMenuPlan, towerSprite } from '../src/hud/tower-layout';
import { hudCanvas } from '../src/hud/layout';
import { resolveHeight } from '../src/content/presentation';
import type { TowerKind } from '../src/game/tower-tuning';
import { join } from 'node:path';
import { project } from '../tools/paths';

let fixture:Authored, session:BattleSession, art:Manifest, host:HTMLElement;
beforeAll(async()=>{fixture=await authored();});
beforeEach(async()=>{
  const db=fixture.open();db.db.run('UPDATE level_tower_unlock SET max_tower_level=4');
  try{session=await battleSession(db);art=testManifest(db,session.presentation);}finally{db.close();}
  session.money=100000;session.player.meta.selections.forEach(s=>{s.is_selected=0;});
  host=document.createElement('div');document.body.append(host);
  vi.spyOn(HTMLElement.prototype,'scrollHeight','get').mockReturnValue(180);
});
afterEach(()=>{host.remove();vi.restoreAllMocks();});
const view=(w=960,h=540)=>hudCanvas(session.content.config.canvas,w,h,session.presentation.towerGeometry);
const choice=(id:string)=>host.querySelector<HTMLButtonElement>(`[data-choice="${id}"]`)!;
function mount(manifest: Manifest, cursor: string) {
  const store = new BattleStore(session), ui = mountTowerUI(host, manifest, store, {build:cursor,upgrade:'url("upgrade.png") 22 4, pointer'});
  const stop = store.subscribe(() => ui.draw(view()));
  return { draw: ui.draw, destroy() { stop(); ui.destroy(); } };
}
function build(kind:TowerKind){const t=session.towers;t.select(session.content.slots[0]!.index);t.tapBuild(kind);t.tapBuild(kind);return t.placed[0]!;}
it('keeps static targets and menus untouched while updating only moving hero targets',()=>{
  const store=new BattleStore(session),ui=mountTowerUI(host,art,store,{build:'pointer',upgrade:'pointer'}),viewport=view();
  ui.draw(viewport);
  const observer=new MutationObserver(()=>{});observer.observe(host,{subtree:true,childList:true,attributes:true});
  ui.sync(viewport);ui.frame(viewport);expect(observer.takeRecords()).toHaveLength(0);
  const actor=session.actors(undefined,true)[0]!;actor.position.x+=20;
  ui.frame(viewport,[actor]);
  const hero=host.querySelector('[data-target="hero-0"]')!;
  expect(observer.takeRecords().every(r=>r.target===hero||r.type==='childList')).toBe(true);
  store.dispatch({type:'selectTower',slot:session.content.slots[0]!.index});ui.sync(viewport);observer.takeRecords();
  ui.sync(viewport);expect(observer.takeRecords()).toHaveLength(0);
  observer.disconnect();ui.destroy();
});
it.each([['build',7,16],['upgrade',22,4]] as const)('renders the %s cursor at 43px with its hotspot on the icon and rejects missing canvas support',(kind,x,y)=>{
  const drawImage=vi.fn();vi.spyOn(HTMLCanvasElement.prototype,'getContext').mockReturnValue({drawImage} as unknown as CanvasRenderingContext2D);
  const encode=vi.spyOn(HTMLCanvasElement.prototype,'toDataURL').mockReturnValue('data:image/png;base64,hammer');
  const image=document.createElement('img');expect(towerCursor(document,image,64,64,kind)).toBe(`url("data:image/png;base64,hammer") ${x} ${y}, pointer`);
  expect(encode.mock.instances[0]).toMatchObject({width:43,height:43});
  expect(drawImage).toHaveBeenCalledWith(image,0,0,43,43);
  vi.mocked(HTMLCanvasElement.prototype.getContext).mockReturnValue(null);expect(()=>towerCursor(document,image,10,10,kind)).toThrow('cursor');
});
it('uses accessible native world hit targets, hero pointers and a build cursor only on empty slots',()=>{
  const ui=mount(art,'url("build.png") 1 1, pointer');ui.draw(view());
  const slot=host.querySelector<HTMLButtonElement>('[data-target^="slot:"]')!,hero=host.querySelector<HTMLButtonElement>('[data-target="hero-0"]')!;
  expect(slot.style.cursor).toContain('build.png');expect(slot.style.clipPath).toBe('ellipse(50% 50%)');expect(parseFloat(slot.style.height)).toBeGreaterThanOrEqual(44);
  expect(hero.style.cursor).toBe('pointer');hero.click();expect(session.selectedHero).toBe(0);expect(slot.disabled).toBe(true);
  expect(Number(hero.style.zIndex)).toBeGreaterThan(Number(slot.style.zIndex));
  session.selectHero(0);ui.draw(view());slot.click();expect(session.towers.selected).toBe(session.content.slots[0]!.index);
  expect(host.querySelectorAll('.tower-choice')).toHaveLength(5);expect(slot.disabled).toBe(true);
  choice('build:ranged').focus();choice('build:ranged').click();expect(document.activeElement).toBe(choice('build:ranged'));
  expect(session.towers.placed).toHaveLength(0);expect(choice('build:ranged').getAttribute('aria-pressed')).toBe('true');
  choice('build:ranged').click();expect(session.towers.placed).toHaveLength(1);expect(slot.style.cursor).toContain('upgrade.png');expect(slot.getAttribute('aria-label')).toContain('Select tower');
  expect(host.querySelector<HTMLButtonElement>('[data-target="slot:1"]')!.style.cursor).toContain('build.png');
  slot.click();expect(choice('tier:1')).not.toBeNull();choice('tier:1').click();choice('tier:1').click();
  expect(session.towers.placed[0]!.level).toBe(2);expect(slot.style.cursor).toContain('upgrade.png');
  session.towers.dismiss();session.heroes[0]!.state='dead';ui.draw(view());expect(host.contains(hero)).toBe(false);
  session.content.slots=[];ui.draw(view());expect(host.contains(slot)).toBe(false);ui.destroy();expect(host.children).toHaveLength(0);
});
it('crops canonical alpha bounds at draw time, uses the shared inset and renders prices, locks, confirmation and authored descriptions',()=>{
  const ui=mount(art,'pointer'),t=session.towers;
  session.content.unlocks.find(u=>u.tower_kind==='supply')!.max_tower_level=0;
  const icon=session.presentation.towers.ranged.icon;art.images[icon]!.bounds={x:20,y:30,width:70,height:60};
  t.select(session.content.slots[0]!.index);session.money=0;ui.draw(view());
  expect(choice('build:supply').disabled).toBe(true);expect(choice('build:supply').querySelector('.tower-price')).toBeNull();
  const rendered=choice('build:ranged').querySelectorAll<SVGElement>('svg')[1]!;
  expect(rendered.getAttribute('viewBox')).toBe('20 30 70 60');expect(parseFloat(rendered.style.left)).toBeCloseTo(view().playArea.height*session.presentation.towerGeometry.button*session.presentation.towerGeometry.iconInset);
  expect(rendered.style.filter).toBe('grayscale(1)');expect(choice('build:ranged').querySelector('.tower-price')!.textContent).toBe(String(t.base('ranged').cost));
  choice('build:ranged').click();expect(choice('build:ranged').querySelectorAll('svg')).toHaveLength(2);expect(choice('build:ranged').querySelector('.tower-price')).toBeNull();
  expect(choice('build:ranged').getAttribute('aria-description')).toContain('Not enough money');expect(host.querySelector('.tower-label')!.textContent).toContain(t.base('ranged').tower_description);
  expect(host.querySelector('.tower-ranges')).toBeNull();choice('build:ranged').click();expect(host.querySelector('.tower-choice')).toBeNull();
  t.select(session.content.slots[0]!.index);session.money=10000;ui.draw(view());choice('build:ranged').click();
  expect(host.querySelector('ellipse')).not.toBeNull();const label=host.querySelector('.tower-label');ui.draw(view());expect(host.querySelector('.tower-label')).toBe(label);
  ui.draw(view(8,8));expect(host.querySelector('.tower-label')).toBeNull();
  ui.destroy();delete art.images[icon]!.bounds;t.dismiss();t.select(session.content.slots[0]!.index);
  expect(()=>mount(art,'pointer').draw(view())).toThrow('alpha bounds');
});
it('keeps upgrade, specialty, completed-rank and placement controls functional and reflects pause',()=>{
  const tower=build('melee'),t=session.towers,ui=mount(art,'pointer');t.select(tower.slot);ui.draw(view());
  choice('tier:1').click();expect(host.querySelectorAll('ellipse')).toHaveLength(t.range!.upgrade===null?1:2);
  choice('tier:1').click();expect(tower.level).toBe(2);
  t.select(tower.slot);ui.draw(view());choice('placement').click();expect(t.placement).toBe('rally');expect(host.querySelector('.tower-choice')).toBeNull();
  session.mapTap(tower.position);t.select(tower.slot);tower.level=3;ui.draw(view());
  const branch=t.offers[0]!.branch;choice(`tier:${branch}`).click();choice(`tier:${branch}`).click();expect(tower.level).toBe(4);
  t.select(tower.slot);ui.draw(view());const path=t.paths[0]!;
  expect(choice(`path:${path.id}`).querySelector('.tower-rank')).not.toBeNull();
  for(const rank of path.ranks){choice(`path:${path.id}`).click();choice(`path:${path.id}`).click();expect(tower.ranks[path.id]).toBe(rank.rank);}
  expect(choice(`path:${path.id}`).querySelector('.tower-price')!.textContent).toBe('MAX');choice(`path:${path.id}`).click();expect(host.querySelector('.tower-label')!.textContent).toContain('Purchased:');
  session.pause();ui.draw(view());expect(choice('placement').disabled).toBe(true);ui.destroy();
});
it('plans every authored build, tier, specialty, max and engineer seat from native presentation metadata',()=>{
  const t=session.towers,v=view(),g=session.presentation.towerGeometry;
  expect(towerMenuPlan(t,v,session.presentation)).toBeNull();
  for(const kind of session.content.towers)for(const tier of kind.tiers){
    t.placed.splice(0);t.dismiss();const tower=build(kind.tower_type_key);tower.level=tier.tower_level;tower.branch=tier.branch;t.select(tower.slot);
    const plan=towerMenuPlan(t,v,session.presentation)!;expect(plan.background.width).toBeCloseTo(v.playArea.height*g.backgroundWidth);
    expect(plan.buttons.length).toBeGreaterThan(0);
    for(const button of plan.buttons){expect(art.images[button.icon]).toBeDefined();expect(button.frame.width).toBeCloseTo(v.playArea.height*g.button*(button.id==='placement'?.9702:1));}
    if(tier.has_engineer_obstacles || tier.has_demolition_charge){const placement=plan.buttons.find(b=>b.id==='placement')!;
      expect(placement.frame.x+placement.frame.width/2).toBeCloseTo(plan.center.x);expect(placement.frame.y+placement.frame.height/2).toBeCloseTo(plan.center.y+v.playArea.height*g.seat);}
  }
  t.placed.splice(0);t.dismiss();const tower=build('ranged');t.select(tower.slot);session.content.unlocks.find(u=>u.tower_kind==='ranged')!.max_tower_level=1;
  const max=towerMenuPlan(t,v,session.presentation)!.buttons[0]!;expect(max.id).toBe('max');expect(max.disabled).toBe(true);
  const ui=mount(art,'pointer');ui.draw(v);expect(choice('max').querySelector('.tower-price')!.textContent).toBe('MAX');ui.destroy();
});
it('uses native tower height clamps, map foot anchors, atlas headings and the slot-wide sapper readiness pulse',()=>{
  const tower=build('areaOfEffect'),t=session.towers,p=session.presentation,canvas=session.content.config.canvas;
  for(const height of [200,340,655,900,1080]){
    const v=view(height*16/9,height),sprite=towerSprite(tower,t.tuning(tower),v,art,p,5.625,0),h=resolveHeight(p.towers.areaOfEffect.height,height);
    expect(sprite.frame).toBe('31');expect(sprite.rect.height).toBeCloseTo(h);
    const base=v.point(tower.position.x,tower.position.y+p.towerGeometry.artworkLift);
    expect(sprite.rect.y).toBeCloseTo(base.y-h*.8+resolveHeight(p.towerGeometry.baseLift,height));
  }
  t.placed.splice(0);const sapper=build('special');sapper.level=4;sapper.branch=session.content.towers.find(k=>k.tower_type_key==='special')!.tiers.find(t=>t.has_demolition_charge)!.branch;
  const v=view(),a=towerSprite(sapper,t.tuning(sapper),v,art,p,0,0),b=towerSprite(sapper,t.tuning(sapper),v,art,p,0,.7);
  expect(a.frame).toBeUndefined();expect(a.rect.width).toBeCloseTo(canvas.slot_width*v.scale);expect(b.rect.width).toBeCloseTo(a.rect.width*1.12);
  expect(a.rect.y+a.rect.height).toBeCloseTo(b.rect.y+b.rect.height);sapper.charge=sapper.position;
  expect(towerSprite(sapper,t.tuning(sapper),v,art,p,0,.7).rect).toEqual(a.rect);
  sapper.level=99;expect(()=>towerSprite(sapper,t.base('special'),v,art,p,0,0)).toThrow('Missing native');
});
it('keeps large copy scrollable, avoids blockers, and returns no label when the viewport has no readable region',()=>{
  const button={x:220,y:160,width:60,height:60},safe={x:0,y:0,width:500,height:400};
  const scrolling=labelPlacement(button,safe,[],()=>2000)!;expect(scrolling.frame.height).toBeLessThan(scrolling.contentHeight);
  expect(labelPlacement(button,safe,[safe],()=>100)).toBeNull();expect(labelPlacement(button,{x:0,y:0,width:10,height:10},[],()=>100)).toBeNull();
  expect(labelPlacement(button,safe,[{x:0,y:0,width:500,height:130}],()=>120)?.frame.y).toBeGreaterThan(130);
});

it('keeps a held menu choice attached while affordability and pause state change', () => {
  session.towers.select(session.content.slots[0]!.index);
  const ui=mount(art,'pointer');ui.draw(view());
  const button=choice('build:ranged');button.focus();
  button.dispatchEvent(new MouseEvent('pointerdown',{bubbles:true}));
  session.money=0;ui.draw(view());
  expect(choice('build:ranged')).toBe(button);expect(document.activeElement).toBe(button);
  expect(button.getAttribute('aria-description')).toContain('Not enough money');
  session.money=100000;ui.draw(view());
  button.dispatchEvent(new MouseEvent('pointerup',{bubbles:true}));button.click();
  expect(session.towers.armed).toBe('build:ranged');expect(choice('build:ranged')).toBe(button);
  session.pause();ui.draw(view());expect(button.disabled).toBe(true);
  session.resume();ui.draw(view());expect(button.disabled).toBe(false);
  ui.destroy();
});

it('keeps the circular ring and range behind confirmation buttons after redraws', async () => {
  const { readFile }=await import('node:fs/promises');
  const css=document.createElement('style');css.textContent=await readFile(join(project,'src/style.css'),'utf8');document.head.append(css);
  const ui=mount(art,'pointer');
  try {
    session.towers.select(session.content.slots[0]!.index);ui.draw(view());
    const button=choice('build:ranged'),z=(node:Element)=>Number(getComputedStyle(node).zIndex||0);
    const checkLayers=()=>{
      const ring=host.querySelector('.tower-menu > .tower-art')!;
      expect(z(button)).toBeGreaterThan(z(ring));
      const range=host.querySelector('.tower-ranges');if(range)expect(z(ring)).toBeGreaterThan(z(range));
      const label=host.querySelector('.tower-label');if(label)expect(z(label)).toBeGreaterThan(z(button));
    };
    checkLayers();button.focus();button.click();
    expect(choice('build:ranged')).toBe(button);expect(document.activeElement).toBe(button);
    expect(button.querySelector('image')!.getAttribute('href')).toBe(art.images.tower_build_confirm!.url);
    // The retained button precedes the newly inserted ring: CSS must still keep it above the ring.
    expect(button.compareDocumentPosition(host.querySelector('.tower-menu > .tower-art')!) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    checkLayers();
    session.money=0;ui.draw(view(640,360));checkLayers();
    choice('build:melee').click();checkLayers();
    choice('build:melee').click();checkLayers();
    expect(choice('build:melee').querySelector('image')!.getAttribute('href')).toBe(art.images.tower_build_confirm!.url);
  } finally { ui.destroy();css.remove(); }
});
