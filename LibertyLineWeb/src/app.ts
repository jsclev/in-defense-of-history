import type { SqlJsStatic } from 'sql.js';
import { ContentDatabase, type Level } from './content/database';
import { manifestSchema, type Manifest } from './content/schema';
import { readSlots } from './content/geometry';
import type { Platform } from './platform/platform';
import type { Render, Renderer } from './game/renderer';

export interface Dependencies {
  document: Document; fetch: typeof fetch; sql: () => Promise<SqlJsStatic>; platform: Platform; render: Render;
}
export async function startApplication(deps: Dependencies): Promise<() => void> {
  const { document, platform } = deps;
  const element = <T extends HTMLElement>(id: string): T => {
    const found = document.getElementById(id);
    if (!found) throw new Error(`Missing application element: ${id}`);
    return found as T;
  };
  const select = element<HTMLSelectElement>('level');
  const status = element('status');
  const error = element('error');
  const stats = element('stats');
  const host = element('game');
  let database: ContentDatabase | undefined;
  let renderer: Renderer | undefined;
  let stopped = false;
  let manifest: Manifest;
  let levels: Level[];
  const request = async (url: string) => {
    const response = await deps.fetch(url, { cache: 'no-store' });
    if (!response.ok) throw new Error(`${url}: HTTP ${response.status}`);
    return response;
  };
  const dispose = () => {
    stopped = true; select.disabled = true; select.removeEventListener('change', change);
    renderer?.destroy(); renderer = undefined; database?.close(); database = undefined;
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
    const slots = readSlots(await (await request(map.geometry)).json(), level.map_image_name);
    if (stopped) return;
    renderer?.destroy();
    renderer = deps.render(host, { manifest, level, slots, canvas: database!.canvas() }, fraction => {
      if (loading) platform.progress(0.2 + fraction * 0.8);
    });
    await renderer.ready;
    if (stopped) return;
    stats.textContent = `${level.campaign_name} · ${level.starting_money} gold · ${level.num_starting_lives} lives · ${level.num_waves} waves`;
    status.textContent = 'Battlefield preview';
    select.disabled = false;
  };
  async function change() {
    try { await showLevel(select.value, false); } catch (reason) { fail(reason); }
  }
  try {
    await platform.initialize();
    manifest = manifestSchema.parse(await (await request('content/manifest.json')).json());
    const [sql, response] = await Promise.all([deps.sql(), request(manifest.database)]);
    database = new ContentDatabase(sql, new Uint8Array(await response.arrayBuffer()));
    document.title = manifest.name; element('title').textContent = manifest.name;
    levels = database.levels().filter(level => level.map_image_name !== '');
    if (!levels.length) throw new Error('level_info.map_image_name: no authored maps');
    select.replaceChildren(...levels.map(level => {
      const option = document.createElement('option'); option.value = level.id; option.textContent = level.level_name;
      return option;
    }));
    platform.progress(0.2);
    await showLevel(levels[0]!.id, true);
    platform.progress(1);
    await platform.start();
    select.addEventListener('change', change);
  } catch (reason) { fail(reason); }
  return dispose;
}
