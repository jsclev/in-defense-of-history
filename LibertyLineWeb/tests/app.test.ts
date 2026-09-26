// @vitest-environment jsdom
import { beforeAll, beforeEach, afterEach, expect, it, vi } from 'vitest';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { startApplication, type Dependencies } from '../src/app';
import { authored, geometry, testManifest, type Authored } from './fixtures';
import { project } from '../tools/paths';
import type { Manifest } from '../src/content/schema';

let fixture: Authored; let manifest: Manifest; let html: string;
let deps: Dependencies; let dispose: (() => void) | undefined;
beforeAll(async () => {
  fixture = await authored();
  const db = fixture.open(); manifest = testManifest(db); db.close();
  html = await readFile(join(project, 'index.html'), 'utf8');
});
beforeEach(() => {
  document.documentElement.innerHTML = html;
  deps = {
    document, sql: async () => fixture.sql,
    platform: { initialize: vi.fn().mockResolvedValue(undefined), progress: vi.fn(), start: vi.fn().mockResolvedValue(undefined) },
    render: vi.fn(() => ({ ready: Promise.resolve(), destroy: vi.fn() })),
    fetch: vi.fn(async input => {
      const url = String(input);
      if (url === 'content/manifest.json') return new Response(JSON.stringify(manifest));
      if (url === manifest.database) return new Response(new Uint8Array(fixture.bytes).buffer);
      return new Response(JSON.stringify(await geometry(url.replace('content/', '').replace('.geojson', ''))));
    }),
  };
});
afterEach(() => { dispose?.(); dispose = undefined; vi.restoreAllMocks(); });
it('loads bundled seeds, renders before starting, and changes battles', async () => {
  dispose = await startApplication(deps);
  expect(document.title).toBe(manifest.name);
  expect(document.getElementById('error')!.hidden).toBe(true);
  const select = document.getElementById('level') as HTMLSelectElement;
  expect(select.options.length).toBe(Object.keys(manifest.maps).length);
  expect(deps.platform.start).toHaveBeenCalledOnce();
  const first = vi.mocked(deps.render).mock.results[0]!.value;
  select.selectedIndex = 1; select.dispatchEvent(new Event('change'));
  await vi.waitFor(() => expect(deps.render).toHaveBeenCalledTimes(2));
  await vi.waitFor(() => expect(select.disabled).toBe(false));
  expect(first.destroy).toHaveBeenCalledOnce();
  expect(deps.platform.start).toHaveBeenCalledOnce();
});
it.each(['fetch', 'sql', 'render', 'start'])('stops and visibly reports %s errors', async kind => {
  if (kind === 'fetch') deps.fetch = vi.fn().mockResolvedValue(new Response('missing', { status: 404 }));
  if (kind === 'sql') deps.sql = async () => { throw new Error('SQLite failed'); };
  if (kind === 'render') deps.render = vi.fn(() => ({ ready: Promise.reject(new Error('Required art missing')), destroy: vi.fn() }));
  if (kind === 'start') deps.platform.start = async () => { throw new Error('Platform failed'); };
  dispose = await startApplication(deps);
  expect(document.getElementById('error')!.hidden).toBe(false);
  expect(document.getElementById('error')!.textContent!.length).toBeGreaterThan(0);
  expect((document.getElementById('level') as HTMLSelectElement).disabled).toBe(true);
});
it('reports a malformed subsequent map and releases resources', async () => {
  dispose = await startApplication(deps);
  deps.fetch = vi.fn().mockResolvedValue(new Response('{}'));
  const select = document.getElementById('level') as HTMLSelectElement;
  select.selectedIndex = 1; select.dispatchEvent(new Event('change'));
  await vi.waitFor(() => expect(document.getElementById('error')!.hidden).toBe(false));
  expect(vi.mocked(deps.render).mock.results[0]!.value.destroy).toHaveBeenCalledOnce();
});
it('makes disposal idempotent and does not leave change handlers', async () => {
  dispose = await startApplication(deps); dispose(); dispose();
  document.getElementById('level')!.dispatchEvent(new Event('change'));
  expect(deps.render).toHaveBeenCalledOnce();
  expect(vi.mocked(deps.render).mock.results[0]!.value.destroy).toHaveBeenCalledOnce();
});
