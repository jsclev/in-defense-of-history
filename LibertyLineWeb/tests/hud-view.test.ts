// @vitest-environment jsdom
import { afterEach, beforeAll, expect, it, vi } from 'vitest';
import { authored, hudBattle, battleSession, type Authored } from './fixtures';
import { hudCanvas, statsLayout } from '../src/hud/layout';
import { hudArt, mountHud } from '../src/hud/view';
import type { HudBattlefield } from '../src/game/renderer';
import type { HudControl, HudState } from '../src/hud/state';
import { readWaveMarkers, visibleWaveMarkers } from '../src/content/geometry';
import { join } from 'node:path';
import { project } from '../tools/paths';
import { SqliteGameData } from '../src/data/sqlite';

let fixture: Authored, battle: HudBattlefield;
beforeAll(async () => { fixture = await authored(); battle = await hudBattle(fixture); });
afterEach(() => document.body.replaceChildren());
const view = () => hudCanvas(battle.canvas, 874, 402, battle.presentation.towerGeometry, { top: 0, right: 62, bottom: 20, left: 62 });
const button = (key: string) => document.querySelector<HTMLButtonElement>(`[data-control="${key}"]`)!;
function mount(state: HudState = structuredClone(battle.hud.state), interactive = false, guides = false) {
  const host = document.createElement('div'); document.body.append(host);
  const actions = Object.fromEntries((['primaryHero', 'secondaryHero', 'reinforcements', 'speed', 'pause', 'inventory'] as HudControl[]).map(id => [id, vi.fn()]));
  const callWave = vi.fn();
  const player = structuredClone(battle.hud.player); player.settings.show_debug_layout_guides = guides ? 1 : 0;
  const hud = mountHud(host, battle.manifest, { player, state }, interactive ? { activate: actions, callWave } : undefined);
  hud.draw(view()); return { hud, actions, callWave, host, state };
}
it('uses canonical portraits, normalized painted frames and native statistics', () => {
  const { hud } = mount();
  expect(button('primaryHero').querySelector('img')!.getAttribute('src')).toBe(battle.manifest.images[battle.hud.state.heroes[0]!.portrait]!.url);
  expect(button('primaryHero').querySelector('img')!.style.clipPath).toContain('polygon(');
  const frame = button('reinforcements').querySelector('img')!;
  expect(Number.parseFloat(frame.style.width)).toBeCloseTo(Number.parseFloat(button('reinforcements').style.width) * 384 / 357);
  expect(frame.style.left.startsWith('-')).toBe(true);
  expect(document.querySelector(`[aria-label="Money: ${battle.level.starting_money}"]`)).not.toBeNull();
  expect(document.querySelector(`[aria-label="Lives: ${battle.level.num_starting_lives}"]`)).not.toBeNull();
  expect(document.querySelector('.hud-guides')).toBeNull();
  expect(Array.from(document.querySelectorAll<HTMLButtonElement>('button')).every(b => b.disabled)).toBe(true);
  hud.destroy(); expect(document.querySelector('.hud')).toBeNull(); expect(document.querySelector('.wave-controls')).toBeNull();
});
it('dispatches exactly the supplied commands, preserves focus and draws selected/dead/cooldown states', () => {
  const twoHeroes = { ...battle.hud.state, heroes: [battle.hud.state.heroes[0]!, { ...battle.hud.state.heroes[0]!, id: 'second-test-hero' }] };
  const { hud, actions, callWave, state } = mount(twoHeroes, true, true);
  const originalPause = button('pause');
  for (const id of Object.keys(actions)) { button(id).click(); expect(actions[id]).toHaveBeenCalledOnce(); }
  button('wave-0').click(); expect(callWave).toHaveBeenCalledWith(state.callWavePositions[0]);
  button('pause').focus();
  const next = { ...state, heroes: state.heroes.map((h, i) => ({ ...h, isAvailable: i === 0, isSelected: i === 0 })),
    isPaused: true, canCallReinforcements: false, reinforcementRemaining: .5, reinforcementSeconds: 10,
    activated: ['inventory', 'speed'] as HudControl[], money: 12345, selectedWave: state.callWavePositions[0]!, countdownSeconds: 5 };
  hud.update(next);
  expect(document.activeElement).toBe(button('pause')); expect(button('pause')).toBe(originalPause);
  expect(button('primaryHero').classList.contains('is-active')).toBe(true);
  expect(button('secondaryHero').disabled).toBe(true);
  expect(button('secondaryHero').querySelector('img')!.style.filter).toBe('grayscale(1)');
  expect(button('pause').getAttribute('aria-pressed')).toBe('true');
  expect(button('inventory').classList.contains('is-active')).toBe(true);
  expect(button('speed').classList.contains('is-active')).toBe(true);
  expect(document.querySelector<HTMLElement>('.hud-cooldown-shade')!.style.height).toBe('50%');
  expect(button('reinforcements').getAttribute('aria-description')).toBe('10 seconds remaining');
  expect(document.querySelector('[aria-label="Money: 12345"]')!.textContent).toBe('12,345');
  expect(button('wave-0').getAttribute('aria-label')).toBe(`Confirm call wave ${state.nextWave}`);
  expect(button('wave-0').getAttribute('aria-description')).toBe('Starts automatically in 5 seconds');
  expect(button('wave-0').querySelector('img')!.getAttribute('src')).toBe(battle.manifest.images[hudArt.confirmWave]!.url);
  expect(button('wave-0').textContent).toBe('5s');
  expect(document.querySelectorAll('.hud-guides path')).toHaveLength(7);
  hud.update({ ...next, isPlacingReinforcements: true, reinforcementRemaining: 0 });
  expect(button('reinforcements').getAttribute('aria-description')).toBe('Selected');
  expect(document.querySelector('.hud-cooldown')).toBeNull();
  hud.destroy();
});
it('renders explicit empty hero slots without substituting another portrait and rejects missing art', () => {
  const { hud } = mount({ ...battle.hud.state, heroes: [] });
  expect(button('primaryHero').getAttribute('aria-label')).toBe('No primary hero chosen');
  expect(button('secondaryHero').querySelectorAll('img')).toHaveLength(2);
  expect(button('secondaryHero').disabled).toBe(true);
  expect(() => hud.update({ ...battle.hud.state, heroes: [{ ...battle.hud.state.heroes[0]!, portrait: 'missing-canonical-portrait' }] })).toThrow('missing-canonical-portrait');
  hud.destroy();
});
it('keeps stats frames fixed for changing values and follows DB corner swaps and sizing edits', () => {
  const { hud, state } = mount();
  const plate = document.querySelector('[aria-label^="Money:"]') as HTMLElement;
  const before = plate.style.cssText;
  hud.update({ ...state, money: 7, lives: 3, wave: 2 });
  expect((document.querySelector('[aria-label="Money: 7"]') as HTMLElement).style.cssText).toBe(before);
  const landscape = statsLayout(view(), 'north_west', 1, 1);
  expect(landscape.money.plate.y).toBe(landscape.lives.plate.y);
  expect(landscape.wave.y).toBeGreaterThan(landscape.money.plate.y + landscape.money.plate.height);
  expect(landscape.wave.width).toBeLessThan(landscape.frame.width);
  hud.destroy();
});
it('takes budgets, heroes, HUD locations, guide settings and first-wave routes from the DAO after in-memory edits', async () => {
  const db = fixture.open(), dal = new SqliteGameData(db);
  try {
    db.db.run('UPDATE level_info SET starting_money = 1234, num_starting_lives = 9 WHERE id = ?', [battle.level.id]);
    db.db.run('UPDATE player_settings SET show_debug_layout_guides = 1');
    db.db.run("UPDATE virtual_canvas SET hero_bar_width_fraction = .4");
    const layout = db.read('player_hud_layout');
    db.db.run('DELETE FROM player_hud_layout');
    for (const row of layout) db.db.run('INSERT INTO player_hud_layout VALUES (?, ?, ?)', [row.id, row.hud_section_name,
      row.hud_section_name === 'hero_bar' ? 'north_east' : row.hud_section_name === 'master_controls' ? 'south_west' : row.hud_location_name]);
    const hero = battle.hud.player.selectedHeroes[0]!;
    db.db.run('UPDATE hero SET icon_image_name = ? WHERE id = ?', ['edited-canonical-key', hero.id]);
    const player = await dal.player.get();
    const wave = await dal.waves.get(battle.level.id, 1);
    const markers = [{ x: 20, y: 30, pathIndices: [wave.spawns[0]!.path_index] }, { x: 40, y: 50, pathIndices: [999] }];
    const session = await battleSession(db); session.content.markers = markers;
    const hud = { state: session.hud };
    expect(hud.state.money).toBe(1234); expect(hud.state.lives).toBe(9);
    expect(hud.state.heroes[0]!.portrait).toBe('edited-canonical-key');
    expect(hud.state.callWavePositions).toEqual([markers[0]]);
    expect(player.settings.show_debug_layout_guides).toBe(1);
    expect(player.hud.find(h => h.hud_section_name === 'hero_bar')!.hud_location_name).toBe('north_east');
    expect((await dal.configuration.get()).canvas.hero_bar_width_fraction).toBe(.4);
    expect(await dal.waves.get(battle.level.id, 1)).toEqual((await dal.waves.getForLevel(battle.level.id))[0]);
    db.db.run('UPDATE level_wave SET wave_index = 99 WHERE id = ?', [wave.id]);
    await expect(dal.waves.get(battle.level.id, 1)).rejects.toThrow('level_wave');
  } finally { dal.close(); }
});
const collection = (pathIndices?: unknown, coordinates: unknown = [10, 20], type = 'Point') => ({ type: 'FeatureCollection', features: [
  { properties: { kind: 'call_wave_button', ...(pathIndices === undefined ? {} : { pathIndices }) }, geometry: { type, coordinates } },
] });
it('reads exact authored wave coordinates and only shows distinct entrances used by the upcoming wave', () => {
  const any = readWaveMarkers(collection(), 'test')[0]!;
  const specific = readWaveMarkers(collection([0, 1]), 'test')[0]!;
  expect(any).toEqual({ x: 10, y: 20, pathIndices: null });
  expect(readWaveMarkers(collection(null), 'test')[0]).toEqual(any);
  expect(visibleWaveMarkers([specific, any], [0])).toEqual([specific]);
  expect(visibleWaveMarkers([specific], [5])).toEqual([]);
  expect(visibleWaveMarkers([any], [])).toEqual([any]);
});
it.each([[], [-1], [0, 0], [0.5], [true], ['0'], '0', 0])('rejects malformed wave path assignments %j', paths => {
  expect(() => readWaveMarkers(collection(paths), 'test')).toThrow('call_wave_button');
});
it('rejects missing/malformed markers instead of inventing positions', () => {
  for (const data of [{ type: 'FeatureCollection', features: [] }, collection(undefined, [1]), collection(undefined, [[1, 2]], 'LineString')])
    expect(() => readWaveMarkers(data, 'test')).toThrow('call_wave_button');
});

it('places tower menus above wave controls and below persistent HUD controls in sibling stacking layers', async () => {
  const { readFile }=await import('node:fs/promises');
  const css=document.createElement('style');css.textContent=await readFile(join(project,'src/style.css'),'utf8');document.head.append(css);
  const {hud,state}=mount();hud.update({...state,reinforcementRemaining:.5,reinforcementSeconds:1,canCallReinforcements:false});
  const root=document.querySelector<HTMLElement>('.hud')!,host=root.parentElement!;host.id='game';
  const menu=document.createElement('div');menu.className='tower-menu';host.append(menu);
  const world=document.createElement('div');world.className='world-controls';host.append(world);
  const canvas=document.createElement('canvas');host.append(canvas);
  const waves=button('wave-0').parentElement!;
  const z=(node:Element)=>Number(getComputedStyle(node).zIndex||0);
  // Compare stacking contexts, not child z-indices trapped inside a higher HUD.
  expect(waves.parentElement).toBe(host);expect(button('reinforcements').parentElement).toBe(root);
  expect(z(root)).toBeGreaterThan(z(menu));expect(z(menu)).toBeGreaterThan(z(waves));
  expect(z(waves)).toBeGreaterThan(z(world));expect(z(world)).toBeGreaterThan(z(canvas));
  expect(getComputedStyle(waves).pointerEvents).toBe('none');expect(getComputedStyle(button('wave-0')).pointerEvents).toBe('auto');
  expect(getComputedStyle(root.querySelector('.hud-cooldown')!).pointerEvents).toBe('none');
  expect(getComputedStyle(host).overflow).toBe('clip');expect(getComputedStyle(host).isolation).toBe('isolate');
  hud.destroy();css.remove();
});

it('retains wave buttons through countdowns and resize, clears their separate layer, and restores input correctly', () => {
  const {hud,state,callWave,host}=mount(undefined,true,true);
  const wave=button('wave-0'), pause=button('pause'), waves=wave.parentElement!;
  wave.focus();
  hud.update({...state,countdownSeconds:4,selectedWave:state.callWavePositions[0]!});
  hud.draw(hudCanvas(battle.canvas,400,800,battle.presentation.towerGeometry));
  expect(button('wave-0')).toBe(wave);expect(document.activeElement).toBe(wave);
  wave.click();expect(callWave).toHaveBeenCalledExactlyOnceWith(state.callWavePositions[0]);
  hud.update({...state,acceptsInput:false});wave.click();expect(callWave).toHaveBeenCalledTimes(1);
  hud.update({...state,callWavePositions:[]});expect(waves.children).toHaveLength(0);
  expect(button('pause')).toBe(pause);expect(host.querySelectorAll('.hud-guides')).toHaveLength(1);
  hud.update(state);button('wave-0').click();expect(callWave).toHaveBeenCalledTimes(2);
  hud.destroy();expect(host.children).toHaveLength(0);
});

it('does not rewrite unchanged HUD state and still redraws immediately for notifications and resize', () => {
  const {hud,state,host}=mount(undefined,true);
  const observer=new MutationObserver(()=>{});observer.observe(host,{subtree:true,childList:true,attributes:true});
  const call=button('reinforcements');
  hud.update(structuredClone(state));expect(observer.takeRecords()).toHaveLength(0);
  hud.update({...state,canCallReinforcements:false,reinforcementRemaining:.1,reinforcementSeconds:1});
  expect(observer.takeRecords().length).toBeGreaterThan(0);expect(call.disabled).toBe(true);
  hud.update(state);expect(call.disabled).toBe(false);observer.takeRecords();
  hud.draw(hudCanvas(battle.canvas,400,800,battle.presentation.towerGeometry));
  expect(observer.takeRecords().length).toBeGreaterThan(0);expect(button('reinforcements')).toBe(call);
  hud.update(structuredClone(state));expect(observer.takeRecords()).toHaveLength(0);
  observer.disconnect();hud.destroy();
});

it('isolates cooldown and money updates from other controls, stats and layout guides', () => {
  const {hud,state,host}=mount(undefined,true,true), call=button('reinforcements');
  const observer=new MutationObserver(()=>{});observer.observe(host,{subtree:true,childList:true,attributes:true});
  hud.update({...state,reinforcementRemaining:.5,reinforcementSeconds:10,canCallReinforcements:false});
  expect(observer.takeRecords().every(r=>r.target===call||call.contains(r.target))).toBe(true);
  hud.update({...state,money:state.money+1});observer.takeRecords();
  hud.update({...state,money:state.money+2});
  const plate=host.querySelector('[aria-label^="Money:"]')!;
  expect(observer.takeRecords().every(r=>r.target===plate||plate.contains(r.target))).toBe(true);
  hud.update({...state,callWavePositions:[]});
  expect(host.querySelectorAll('.hud-guides')).toHaveLength(1);
  expect(host.querySelector('.hud-wave')).toBeNull();
  observer.disconnect();hud.destroy();
});
