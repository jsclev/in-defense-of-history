import type { Level } from './data/records';
import type { GameDataAccess, OpenGameData, PlayerState } from './data/contracts';
import { manifestSchema, type Manifest } from './content/schema';
import { presentationSchema, type Presentation } from './content/presentation';
import { readSlots } from './content/geometry';
import { navigationSchema } from './game/navigation';
import { loadBattleContent } from './game/content';
import { BattleSession } from './game/session';
import { mountMenu } from './hud/menu';
import { BattleStore } from './game/store';
import type { Platform } from './platform/platform';
import type { Render, Renderer } from './game/renderer';

export interface Dependencies {
  document: Document; fetch: typeof fetch; openData: OpenGameData; platform: Platform; render: Render;
}
export async function startApplication(deps: Dependencies): Promise<() => void> {
  const { document, platform } = deps;
  const element = <T extends HTMLElement>(id: string): T => {
    const found = document.getElementById(id);
    if (!found) throw new Error(`Missing application element: ${id}`);
    return found as T;
  };
  const select = element<HTMLSelectElement>('level'), status = element('status'), error = element('error'), host = element('game');
  const dialog = element<HTMLDialogElement>('preview-menu');
  let database: GameDataAccess | undefined, renderer: Renderer | undefined, store: BattleStore | undefined;
  let menu: ReturnType<typeof mountMenu> | undefined, stopped = false;
  let stopHostPause: (() => void) | undefined;
  let manifest: Manifest, presentation: Presentation, navigation: ReturnType<typeof navigationSchema.parse>, levels: Level[], currentID: string;
  const request = async (url: string) => {
    const response = await deps.fetch(url, { cache: 'no-store' });
    if (!response.ok) throw new Error(`${url}: HTTP ${response.status}`);
    return response;
  };
  const stopBattle = () => { store?.dispatch({ type: 'pause' }); renderer?.destroy(); renderer = undefined; store = undefined; };
  const dispose = () => {
    stopped = true; select.disabled = true; document.removeEventListener('visibilitychange', visibility);
    stopHostPause?.(); stopHostPause = undefined;
    stopBattle(); menu?.destroy(); database?.close(); database = undefined;
  };
  const fail = (reason: unknown) => {
    error.hidden = false; error.textContent = reason instanceof Error ? reason.message : String(reason);
    status.textContent = 'Unable to load the battlefield.'; dispose();
  };
  const showLevel = async (id: string, loading: boolean) => {
    select.disabled = true;
    const level = levels.find(level => level.id === id);
    if (!level) throw new Error(`Unknown level_info.id: ${id}`);
    const map = manifest.maps[level.map_image_name];
    if (!map) throw new Error(`level_info[${id}].map_image_name: missing map`);
    const rings = navigation[level.map_image_name];
    if (!rings) throw new Error(`${level.map_image_name}: missing native road boundaries`);
    const geometry = await (await request(map.geometry)).json();
    if (stopped) return;
    const slots = readSlots(geometry, level.map_image_name);
    const content = await loadBattleContent(database!, level, geometry, rings);
    if (stopped) return;
    stopBattle(); currentID = id;
    const current = new BattleSession(content, presentation, () => performance.now(), {
      pause: () => menu!.show('pause', current.player),
      outcome: outcome => menu!.show(outcome, current.player),
      lifeLost: () => document.defaultView?.navigator.vibrate?.(50),
    });
    store = new BattleStore(current);
    store.dispatch({ type: 'pause' }); // Loading and host startup are outside the battle clock.
    renderer = deps.render(host, { manifest, presentation, level, slots, canvas: content.config.canvas, hud: { player: current.player, state: current.hud }, store }, fraction => {
      if (loading) platform.progress(0.2 + fraction * 0.8);
    });
    await renderer.ready;
    if (stopped) return;
    current.clock.resync(); if (!loading) store.dispatch({ type: 'resume' });
    status.textContent = level.level_name; status.classList.add('sr-only');
    select.value = id; select.disabled = false; menu!.close();
  };
  function hostPause() {
    if (store && !store.session.paused && !store.session.outcome) {
      store.dispatch({ type: 'activate', control: 'pause' });
    }
  }
  function visibility() { if (document.hidden) hostPause(); }
  const play = async (id: string) => { try { await showLevel(id, false); } catch (reason) { fail(reason); } };
  function updatePlayer(player: PlayerState) { store?.dispatch({ type: 'setPlayer', player }); return player; }
  try {
    await platform.initialize();
    stopHostPause = platform.onPause?.(hostPause);
    const [rawManifest, rawPresentation, rawNavigation] = await Promise.all([
      request('content/manifest.json').then(r => r.json()), request('content/presentation.json').then(r => r.json()), request('content/navigation.json').then(r => r.json()),
    ]);
    manifest = manifestSchema.parse(rawManifest); presentation = presentationSchema.parse(rawPresentation); navigation = navigationSchema.parse(rawNavigation);
    database = await deps.openData(manifest.database);
    document.title = manifest.name;
    levels = (await database.levels.getAll()).filter(level => level.map_image_name !== '');
    if (!levels.length) throw new Error('level_info.map_image_name: no authored maps');
    select.replaceChildren(...levels.map(level => {
      const option = document.createElement('option'); option.value = level.id; option.textContent = level.level_name; return option;
    }));
    menu = mountMenu(dialog, manifest, await database.heroes.getAll(), {
      resume: () => { store!.dispatch({ type: 'resume' }); host.querySelector<HTMLButtonElement>('[data-control="pause"]')?.focus({ preventScroll: true }); },
      restart: () => play(currentID), campaign: stopBattle, play,
      setting: async (key, enabled) => updatePlayer(await database!.player.setSetting(key, enabled)),
      heroAI: async (id, enabled) => updatePlayer(await database!.player.setHeroAI(id, enabled)),
    });
    const initial = levels.find(level => level.map_image_name === 'level_15_charleston');
    if (!initial) throw new Error('Missing startup level: level_15_charleston');
    platform.progress(.2); await showLevel(initial.id, true);
    if (!stopped) { platform.progress(1); await platform.start(); store!.dispatch({ type: 'resume' }); document.addEventListener('visibilitychange', visibility); }
  } catch (reason) { fail(reason); }
  return dispose;
}
