import { beforeAll, beforeEach, expect, it, vi } from 'vitest';
import { authored, battleSession, type Authored } from './fixtures';
import { BattleStore } from '../src/game/store';
import { ticks, ticksPerSecond } from '../src/game/schedules';
let fixture: Authored, store: BattleStore, now: number;
beforeAll(async () => { fixture = await authored(); });
beforeEach(async () => {
  now = 0;
  const db = fixture.open();
  db.db.run('UPDATE level_tower_unlock SET max_tower_level=4');
  db.db.run('UPDATE reinforcement_config SET cooldown_seconds=1');
  try { store = new BattleStore(await battleSession(db, undefined, () => now)); } finally { db.close(); }
});
it('publishes the exact readiness transition from the authored game clock, and never queues premature clicks', () => {
  const s = store.session, changes: boolean[] = [];
  const stop = store.subscribe(() => changes.push(s.canReinforce));
  store.hudInput.activate!.reinforcements!();
  expect(s.placing).toBe(true);
  store.dispatch({ type: 'mapTap', point: s.content.routes[0]!.point(200) });
  expect(s.placing).toBe(false); expect(changes.at(-1)).toBe(false);
  const readyAt = ticks(s.content.config.reinforcement.cooldown_seconds);
  for (let tick = 1; tick < readyAt; tick++) { now = (tick + .01) * 1000 / ticksPerSecond; store.frame(); }
  expect(s.clock.tick).toBe(readyAt - 1); expect(s.canReinforce).toBe(false);
  store.hudInput.activate!.reinforcements!(); expect(s.placing).toBe(false);
  const count = changes.length;
  store.frame(); expect(changes).toHaveLength(count); // No phantom tick or render-driven notification.
  now = (readyAt + .01) * 1000 / ticksPerSecond; store.frame();
  expect(changes).toHaveLength(count + 1); expect(changes.at(-1)).toBe(true);
  expect(s.placing).toBe(false); // The earlier unavailable click is not replayed.
  store.hudInput.activate!.reinforcements!(); expect(s.placing).toBe(true);
  stop(); store.dispatch({ type: 'pause' }); expect(changes.at(-1)).toBe(true);
});
it('publishes complete commands synchronously without changing time; pause and resume use the same authority', () => {
  const s = store.session, changed = vi.fn(() => [s.paused, s.placing, s.selectedHero]); store.subscribe(changed);
  now = 500;
  store.hudInput.activate!.primaryHero!(); expect(s.selectedHero).toBe(0); expect(s.clock.tick).toBe(0);
  store.dispatch({ type: 'selectHero', index: 0 }); expect(s.selectedHero).toBeNull();
  store.dispatch({ type: 'activate', control: 'reinforcements' }); expect(changed.mock.results.at(-1)!.value).toEqual([false, true, null]);
  store.dispatch({ type: 'pause' }); store.frame(); expect(s.clock.tick).toBe(0);
  store.dispatch({ type: 'activate', control: 'reinforcements' }); expect(s.placing).toBe(true); expect(s.canReinforce).toBe(false);
  now = 5000; store.dispatch({ type: 'resume' }); store.frame(); expect(s.clock.tick).toBe(0); expect(s.canReinforce).toBe(true);
  const player = { ...s.player, settings: { ...s.player.settings, debug_mode: 1 as const } };
  store.dispatch({ type: 'setPlayer', player }); expect(s.player).toBe(player);
  const point = s.hud.callWavePositions[0]!;
  store.hudInput.callWave!(point); expect(s.waves.next).toBe(0);
  store.hudInput.callWave!(point); expect(s.waves.next).toBe(1);
});
it('routes tower selection, purchases, upgrades and placement through one observable transaction', () => {
  const s = store.session, slot = s.content.slots[0]!.index; s.money = 100000;
  const changed = vi.fn(); store.subscribe(changed);
  store.dispatch({ type: 'activate', control: 'reinforcements' });
  store.dispatch({ type: 'selectTower', slot }); expect(s.placing).toBe(false);
  for (let i = 0; i < 2; i++) store.dispatch({ type: 'buildTower', kind: 'melee' });
  const tower = s.towers.placed[0]!; expect(tower.level).toBe(1);
  expect(changed).toHaveBeenCalledTimes(4); expect(s.towers.selected).toBeNull();
  for (let level = 2; level <= 4; level++) {
    store.dispatch({ type: 'selectTower', slot });
    const branch = s.towers.offers[0]!.branch;
    store.dispatch({ type: 'upgradeTower', branch }); store.dispatch({ type: 'upgradeTower', branch });
    expect(tower.level).toBe(level);
  }
  store.dispatch({ type: 'selectTower', slot });
  const id = s.towers.paths[0]!.id;
  store.dispatch({ type: 'upgradePath', id }); store.dispatch({ type: 'upgradePath', id }); expect(tower.ranks[id]).toBe(1);
  store.dispatch({ type: 'placeTower' }); expect(s.towers.placement).toBe('rally');
  store.dispatch({ type: 'mapTap', point: tower.position }); expect(s.towers.placement).toBeNull();
});
