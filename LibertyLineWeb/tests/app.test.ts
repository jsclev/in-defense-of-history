// @vitest-environment jsdom
import { beforeAll, beforeEach, afterEach, expect, it, vi } from 'vitest';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { startApplication, type Dependencies } from '../src/app';
import { authored, geometry, testManifest, presentation, navigation, type Authored } from './fixtures';
import { project } from '../tools/paths';
import type { Manifest } from '../src/content/schema';
import { loadSqliteData } from '../src/data/sqlite';
let fixture: Authored, manifest: Manifest, html: string;
let art: Awaited<ReturnType<typeof presentation>>, nav: Awaited<ReturnType<typeof navigation>>;
let deps: Dependencies, dispose: (() => void) | undefined;
beforeAll(async () => {
  fixture = await authored(); const db = fixture.open();
  [art, nav] = await Promise.all([presentation(), navigation(db)]);
  manifest = testManifest(db, art); db.close(); html = await readFile(join(project, 'index.html'), 'utf8');
});
const menu = () => document.getElementById('preview-menu') as HTMLDialogElement;
const click = (id: string) => document.getElementById(id)!.click();
const call = () => vi.mocked(deps.render).mock.calls.at(-1)!;
const session = () => call()[1].store!.session;
beforeEach(() => {
  document.documentElement.innerHTML = html;
  menu().showModal = vi.fn(() => { menu().open = true; });
  menu().close = vi.fn(() => { menu().open = false; menu().dispatchEvent(new Event('close')); });
  deps = {
    document, openData: url => loadSqliteData(url, { fetch: deps.fetch, sql: async () => fixture.sql }),
    platform: { initialize: vi.fn().mockResolvedValue(undefined), progress: vi.fn(), start: vi.fn().mockResolvedValue(undefined) },
    render: vi.fn(() => ({ ready: Promise.resolve(), destroy: vi.fn() })),
    fetch: vi.fn(async input => {
      const url = String(input);
      if (url === 'content/manifest.json') return new Response(JSON.stringify(manifest));
      if (url === 'content/presentation.json') return new Response(JSON.stringify(art));
      if (url === 'content/navigation.json') return new Response(JSON.stringify(nav));
      if (url === manifest.database) return new Response(new Uint8Array(fixture.bytes).buffer);
      return new Response(JSON.stringify(await geometry(url.replace('content/', '').replace('.geojson', ''))));
    }),
  };
});
afterEach(() => { dispose?.(); dispose = undefined; vi.restoreAllMocks(); });
it('loads shared seeds, connects every HUD handler and starts the platform only after rendering', async () => {
  dispose = await startApplication(deps);
  expect(document.getElementById('error')!.textContent).toBe(''); expect(document.title).toBe(manifest.name);
  expect((document.getElementById('level') as HTMLSelectElement).options.length).toBe(Object.keys(manifest.maps).length);
  expect(deps.platform.start).toHaveBeenCalledOnce();
  const { activate, callWave } = call()[1].store!.hudInput;
  activate!.primaryHero!(); expect(session().selectedHero).toBe(0);
  activate!.secondaryHero!(); expect(session().selectedHero).toBe(session().heroes.length > 1 ? 1 : 0);
  expect(session().content.level.map_image_name).toBe('level_15_charleston');
  expect(session().money).toBe(session().content.level.starting_money);
  activate!.reinforcements!(); expect(session().placing).toBe(true);
  activate!.speed!(); expect(session().clock.factor).toBe(session().content.config.playSpeeds.find(p => p.source === 'player')!.factor * 2);
  activate!.inventory!(); expect(session().hud.activated).toContain('inventory');
  const marker = session().hud.callWavePositions[0]!; callWave!(marker); callWave!(marker); expect(session().waves.next).toBe(1);
  activate!.pause!(); expect(menu().open).toBe(true); expect(session().paused).toBe(true);
  click('resume'); expect(menu().open).toBe(false); expect(session().paused).toBe(false);
});
it('restarts with authored resources, discards transient state, and exits to campaign selection', async () => {
  dispose = await startApplication(deps); const firstSession = session(), first = vi.mocked(deps.render).mock.results[0]!.value;
  firstSession.money = 10; firstSession.activate('pause'); click('restart');
  await vi.waitFor(() => expect(deps.render).toHaveBeenCalledTimes(2));
  expect(first.destroy).toHaveBeenCalledOnce(); expect(session().money).toBe(session().content.level.starting_money);
  expect(session().clock.tick).toBe(0); expect(session().waves.next).toBe(0);
  session().activate('pause'); click('campaign'); expect(document.getElementById('title')!.textContent).toBe('MAIN CAMPAIGN');
  const select = document.getElementById('level') as HTMLSelectElement; select.selectedIndex = 1; click('play-level');
  await vi.waitFor(() => expect(deps.render).toHaveBeenCalledTimes(3));
  expect(session().content.level.id).toBe(select.value); expect(deps.platform.start).toHaveBeenCalledOnce();
});
it('pauses when hidden, keeps settings modal, saves via SQLite, and resumes only explicitly', async () => {
  dispose = await startApplication(deps);
  vi.spyOn(document, 'hidden', 'get').mockReturnValue(true); document.dispatchEvent(new Event('visibilitychange'));
  expect(session().paused).toBe(true); click('settings');
  const checkbox = document.querySelector<HTMLInputElement>('[data-setting="show_debug_layout_guides"]')!;
  const before = checkbox.checked; checkbox.click();
  await vi.waitFor(() => expect(checkbox.checked).toBe(!before));
  expect(session().player.settings.show_debug_layout_guides).toBe(Number(!before));
  const hero = document.querySelector<HTMLInputElement>('[data-hero]')!; const previous = hero.checked; hero.click();
  await vi.waitFor(() => expect(hero.checked).toBe(!previous));
  expect(session().paused).toBe(true);
  menu().dispatchEvent(new Event('cancel', { cancelable: true })); expect(document.getElementById('title')!.textContent).toBe('PAUSED');
  menu().dispatchEvent(new Event('cancel', { cancelable: true })); expect(session().paused).toBe(false);
});
it.each(['fetch', 'data', 'render', 'start'])('reports %s failures and releases resources', async kind => {
  if (kind === 'fetch') deps.fetch = vi.fn().mockResolvedValue(new Response('missing', { status: 404 }));
  if (kind === 'data') deps.openData = async () => { throw new Error('Data service failed'); };
  if (kind === 'render') deps.render = vi.fn(() => ({ ready: Promise.reject(new Error('Required art missing')), destroy: vi.fn() }));
  if (kind === 'start') deps.platform.start = async () => { throw new Error('Platform failed'); };
  dispose = await startApplication(deps); expect(document.getElementById('error')!.hidden).toBe(false);
  expect((document.getElementById('level') as HTMLSelectElement).disabled).toBe(true);
});
it('reports subsequent malformed content and closes the overlay so the diagnostic is visible', async () => {
  dispose = await startApplication(deps); session().activate('pause');
  deps.fetch = vi.fn().mockResolvedValue(new Response('{}')); click('restart');
  await vi.waitFor(() => expect(document.getElementById('error')!.hidden).toBe(false));
  expect(menu().open).toBe(false); expect(vi.mocked(deps.render).mock.results[0]!.value.destroy).toHaveBeenCalledOnce();
});
it('disposal removes handlers and does not destroy a game twice', async () => {
  dispose = await startApplication(deps); dispose(); dispose(); click('restart');
  document.dispatchEvent(new Event('visibilitychange')); expect(deps.render).toHaveBeenCalledOnce();
  expect(vi.mocked(deps.render).mock.results[0]!.value.destroy).toHaveBeenCalledOnce();
});
it('routes host pause requests through the same pause menu and unregisters on disposal', async () => {
  let pause: (() => void) | undefined; const stop = vi.fn();
  deps.platform.onPause = handler => { pause = handler; return stop; };
  dispose = await startApplication(deps); pause!(); expect(session().paused).toBe(true); expect(menu().open).toBe(true);
  click('settings'); pause!(); expect(document.getElementById('title')!.textContent).toBe('SETTINGS');
  dispose(); expect(stop).toHaveBeenCalledOnce(); pause!(); expect(menu().open).toBe(false);
});

it('fails explicitly when the authored startup level is missing', async () => {
  const db=fixture.open();db.db.run("UPDATE level_info SET map_image_name='' WHERE map_image_name='level_15_charleston'");
  const bytes=db.db.export();db.close();const fetch=deps.fetch;
  deps.fetch=async input=>String(input)===manifest.database?new Response(new Uint8Array(bytes).buffer):fetch(input);
  dispose=await startApplication(deps);
  expect(document.getElementById('error')!.textContent).toContain('Missing startup level');expect(deps.render).not.toHaveBeenCalled();
});
