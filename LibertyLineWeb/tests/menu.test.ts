// @vitest-environment jsdom
import { beforeAll, beforeEach, afterEach, expect, it, vi } from 'vitest';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { mountMenu, type MenuActions } from '../src/hud/menu';
import { SqliteGameData } from '../src/data/sqlite';
import { authored, testManifest, type Authored } from './fixtures';
import { project } from '../tools/paths';

let fixture: Authored, html: string, data: SqliteGameData, menu: ReturnType<typeof mountMenu>, actions: MenuActions;
let dialog: HTMLDialogElement;
beforeAll(async () => { fixture = await authored(); html = await readFile(join(project, 'index.html'), 'utf8'); });
beforeEach(async () => {
  document.documentElement.innerHTML = html; dialog = document.querySelector('dialog')!;
  dialog.showModal = () => { dialog.open = true; }; dialog.close = () => { dialog.open = false; };
  const db = fixture.open(); data = new SqliteGameData(db);
  actions = { resume: vi.fn(), restart: vi.fn().mockResolvedValue(undefined), campaign: vi.fn(), play: vi.fn().mockResolvedValue(undefined),
    setting: vi.fn((key, enabled) => data.player.setSetting(key, enabled)), heroAI: vi.fn((id, enabled) => data.player.setHeroAI(id, enabled)) };
  menu = mountMenu(dialog, testManifest(db), await data.heroes.getAll(), actions); menu.show('pause', await data.player.get());
});
afterEach(() => { menu.destroy(); data.close(); });
const click = (id: string) => document.getElementById(id)!.click();
const cancel = () => dialog.dispatchEvent(new Event('cancel', { cancelable: true }));
it('shares the quick haptic control with the settings checkbox through the same SQLite field', async () => {
  const before = Boolean((await data.player.get()).settings.enemy_escape_haptics_enabled);
  click('haptics'); await vi.waitFor(() => expect(dialog.hasAttribute('aria-busy')).toBe(false));
  expect(document.getElementById('haptics')!.getAttribute('aria-pressed')).toBe(String(!before));
  expect(actions.setting).toHaveBeenCalledWith('enemy_escape_haptics_enabled', !before);
  click('settings'); const input = document.querySelector<HTMLInputElement>('[data-setting="enemy_escape_haptics_enabled"]')!;
  expect(input.checked).toBe(!before); input.click();
  await vi.waitFor(() => expect(input.checked).toBe(before));
  click('settings-done'); expect(document.getElementById('haptics')!.getAttribute('aria-pressed')).toBe(String(before));
});
it('keeps failed writes unchanged, reports their error, and prevents navigation or concurrent toggles while saving', async () => {
  let reject!: (reason: Error) => void;
  actions.setting = vi.fn(() => new Promise<Awaited<ReturnType<MenuActions['setting']>>>((_, fail) => { reject = fail; })); click('settings');
  const one = document.querySelector<HTMLInputElement>('[data-setting="debug_mode"]')!;
  const two = document.querySelector<HTMLInputElement>('[data-setting="show_debug_info"]')!;
  const beforeOne = one.checked, beforeTwo = two.checked;
  one.click(); expect(one.disabled).toBe(true); expect(one.checked).toBe(beforeOne);
  two.click(); expect(two.checked).toBe(beforeTwo); expect(actions.setting).toHaveBeenCalledOnce();
  cancel(); click('settings-done'); expect(document.getElementById('title')!.textContent).toBe('SETTINGS');
  reject(new Error('Write rejected')); await vi.waitFor(() => expect(one.disabled).toBe(false));
  expect(one.checked).toBe(beforeOne); expect(document.getElementById('settings-error')!.textContent).toBe('Write rejected');
  expect(document.getElementById('settings-error')!.hidden).toBe(false); cancel(); cancel();
  expect(actions.resume).toHaveBeenCalledOnce(); expect(dialog.open).toBe(false);
});
it('keeps outcomes modal and connects retry and campaign actions', async () => {
  const player = await data.player.get();
  menu.show('victory', player); cancel(); expect(dialog.open).toBe(true); click('retry-level');
  await vi.waitFor(() => expect(dialog.hasAttribute('aria-busy')).toBe(false)); expect(actions.restart).toHaveBeenCalledOnce();
  menu.show('defeat', player); click('outcome-campaign'); expect(actions.campaign).toHaveBeenCalledOnce();
  expect(document.getElementById('title')!.textContent).toBe('MAIN CAMPAIGN'); cancel(); expect(dialog.open).toBe(true);
  menu.close(); expect(dialog.open).toBe(false); menu.close();
});
