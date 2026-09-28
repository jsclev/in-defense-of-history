import { beforeAll, expect, it, vi } from 'vitest';
import { authored, type Authored } from './fixtures';
import { SqliteGameData, loadSqliteData } from '../src/data/sqlite';
import { records, type Table } from '../src/data/records';
import type { GameDataAccess } from '../src/data/contracts';

let fixture: Authored;
beforeAll(async () => { fixture = await authored(); });

it('loads the complete game DAL from the shared seed and exposes every authored column', async () => {
  const db = fixture.open();
  const data = new SqliteGameData(db);
  try {
    await data.validate();
    for (const table of Object.keys(records) as Table[]) {
      const rows = db.read(table);
      expect(rows.length, table).toBeGreaterThan(0);
      const columns = db.rows(`PRAGMA table_info(${table})`).map(row => row.name).sort();
      expect(Object.keys(rows[0]!).sort(), table).toEqual(columns);
    }
    const campaigns = await data.campaigns.getAll();
    const levels = await data.levels.getAll();
    expect(await data.campaigns.get(campaigns[0]!.id.toUpperCase())).toEqual(campaigns[0]);
    expect(await data.levels.get(levels[0]!.id.toUpperCase())).toEqual(levels[0]);
    expect(await data.levels.getForCampaign(campaigns[0]!.id)).toEqual(levels.filter(l => l.campaign_id === campaigns[0]!.id));
    const towers = await data.towers.getAll();
    expect(towers.flatMap(t => t.tiers)).toHaveLength(db.read('tower').length);
    expect(towers.flatMap(t => t.tiers.flatMap(tier => tier.upgrades.flatMap(p => p.ranks)))).toHaveLength(db.read('tower_upgrade_rank').length);
    expect(await data.enemies.getAll()).toHaveLength(db.read('enemy_type').length);
    expect(await data.heroes.getAll()).toHaveLength(db.read('hero').length);
    const player = await data.player.get();
    expect(player.selectedHeroes.map(h => h.id)).toEqual(db.playerSeeds().heroes.map(h => h.hero_id));
    expect(player.heroControls).toHaveLength(db.read('hero').length);
    expect(player.unlockedHeroes).toEqual(db.read('player_unlocked_hero'));
    const meta = await data.metaUpgrades.get();
    expect(meta.upgrades).toHaveLength(db.read('meta_upgrade').length);
    expect((await data.player.getMetaUpgrades('level15')).available).toBeGreaterThanOrEqual(0);
    const config = await data.configuration.get();
    expect(config.canvas.path_width).toBe(db.read('virtual_canvas')[0]!.path_width);
    expect(Array.isArray(config.combat.grapeshot_spread_degrees)).toBe(true);
    for (const level of levels) {
      const waveRows = db.read('level_wave', 'WHERE level_info_id = ?', [level.id]);
      if (waveRows.length === level.num_waves) expect(await data.waves.getForLevel(level.id)).toHaveLength(level.num_waves);
      else await expect(data.waves.getForLevel(level.id)).rejects.toThrow('num_waves');
      expect((await data.paths.getForLevel(level.id)).flatMap(p => p.points)).toHaveLength(db.read('level_path_point', 'WHERE level_info_id = ?', [level.id]).length);
      expect(await data.unlocks.getForLevel(level.id)).toHaveLength(towers.length);
      expect(await data.levelHeroes.getForLevel(level.id)).toEqual(db.read('level_hero', 'WHERE level_info_id = ? ORDER BY enemy_path_index, hero_id', [level.id]));
    }
  } finally { data.close(); }
});

it('uses parameter binding and fails unknown IDs instead of returning replacement content', async () => {
  const data = new SqliteGameData(fixture.open());
  try {
    await expect(data.campaigns.get("' OR 1=1 --")).rejects.toThrow('campaign');
    for (const operation of [() => data.levels.get('unknown'), () => data.levels.getForCampaign('unknown'),
      () => data.paths.getForLevel('unknown'), () => data.waves.getForLevel('unknown'),
      () => data.unlocks.getForLevel('unknown'), () => data.levelHeroes.getForLevel('unknown')])
      await expect(operation()).rejects.toThrow();
  } finally { data.close(); }
  data.close();
  await expect(data.levels.getAll()).rejects.toThrow('closed');
});

it('fetches an independent bundled database on every launch and handles HTTP/SQL/validation failures', async () => {
  const fetch = vi.fn().mockImplementation(async () => new Response(new Uint8Array(fixture.bytes).buffer));
  const deps = { fetch, sql: async () => fixture.sql };
  const first = await loadSqliteData('content/game.sqlite', deps);
  const second = await loadSqliteData('content/game.sqlite', deps);
  expect(fetch).toHaveBeenCalledTimes(2);
  expect(fetch).toHaveBeenCalledWith('content/game.sqlite', { cache: 'no-store' });
  first.close(); expect((await second.levels.getAll()).length).toBeGreaterThan(0); second.close();
  fetch.mockResolvedValueOnce(new Response('', { status: 404 }));
  await expect(loadSqliteData('content/missing.sqlite', deps)).rejects.toThrow('HTTP 404');
  fetch.mockResolvedValueOnce(new Response(new Uint8Array([1, 2, 3]).buffer));
  await expect(loadSqliteData('content/broken.sqlite', deps)).rejects.toThrow();
  await expect(loadSqliteData('content/game.sqlite', { ...deps, sql: async () => { throw Error('WASM failed'); } })).rejects.toThrow('WASM failed');
  const db = fixture.open(); db.db.run('DELETE FROM hero_ai'); const bytes = db.db.export(); db.close();
  fetch.mockResolvedValueOnce(new Response(new Uint8Array(bytes).buffer));
  const close = vi.spyOn(SqliteGameData.prototype, 'close');
  await expect(loadSqliteData('content/missing-ai.sqlite', deps)).rejects.toThrow('hero_ai');
  expect(close).toHaveBeenCalledOnce(); close.mockRestore();
});

it('propagates authored edits through every content family and never caches mutable DTOs', async () => {
  const db = fixture.open(); const data = new SqliteGameData(db);
  try {
    const originalTowers = await data.towers.getAll();
    const tower = originalTowers[0]!.tiers[0]!;
    const enemy = (await data.enemies.getAll())[0]!;
    const hero = (await data.heroes.getAll())[0]!;
    const config = await data.configuration.get();
    const level = (await data.levels.getAll())[0]!;
    db.db.run('UPDATE tower SET cost = ?, tower_name = ? WHERE id = ?', [tower.cost + 7, 'Changed in SQL', tower.id]);
    db.db.run('UPDATE enemy_type SET bounty = ? WHERE id = ?', [enemy.bounty + 3, enemy.id]);
    db.db.run('UPDATE hero_combat SET hp = ? WHERE hero_id = ?', [hero.combat.hp + 20, hero.id]);
    db.db.run('UPDATE combat_rules SET morale_recovery_delay = ?', [config.combat.morale_recovery_delay + 2]);
    db.db.run('UPDATE level_info SET starting_money = ? WHERE id = ?', [level.starting_money + 17, level.id]);
    db.db.run('UPDATE player_settings SET debug_mode = 1 - debug_mode');
    db.db.run('UPDATE meta_upgrade SET title = ? WHERE upgrade_key = ?', ['Authored title edit', 'rangeEstimation']);
    const changed = (await data.towers.getAll()).flatMap(t => t.tiers).find(t => t.id === tower.id)!;
    expect(changed.cost).toBe(tower.cost + 7); expect(changed.tower_name).toBe('Changed in SQL');
    expect((await data.enemies.getAll()).find(e => e.id === enemy.id)!.bounty).toBe(enemy.bounty + 3);
    expect((await data.heroes.getAll()).find(h => h.id === hero.id)!.combat.hp).toBe(hero.combat.hp + 20);
    expect((await data.configuration.get()).combat.morale_recovery_delay).toBe(config.combat.morale_recovery_delay + 2);
    expect((await data.levels.get(level.id)).starting_money).toBe(level.starting_money + 17);
    expect((await data.metaUpgrades.get()).upgrades.find(u => u.upgrade_key === 'rangeEstimation')!.title).toBe('Authored title edit');
    changed.cost = -999; changed.history.source_title = 'Client mutation';
    expect((await data.towers.getAll()).flatMap(t => t.tiers).find(t => t.id === tower.id)!.cost).toBe(tower.cost + 7);
    const fresh = new SqliteGameData(fixture.open());
    try {
      expect(await fresh.towers.getAll()).toEqual(originalTowers);
      expect((await fresh.levels.get(level.id)).starting_money).toBe(level.starting_money);
      expect((await fresh.player.get()).settings.debug_mode).not.toBe((await data.player.get()).settings.debug_mode);
    } finally { fresh.close(); }
  } finally { data.close(); }
});

it('orders SQL paths and counts simultaneous spawn gaps once, matching WaveDAO', async () => {
  const db = fixture.open(); const data = new SqliteGameData(db);
  try {
    const level = db.levels()[0]!;
    const waves = await data.waves.getForLevel(level.id);
    let sharedGroup = false;
    for (const wave of waves) for (const spawn of wave.spawns) {
      const expected = db.rows(`SELECT SUM(gap) AS delay FROM (SELECT MIN(spawn_time_since_previous_spawn) AS gap
        FROM level_wave_enemy_spawn WHERE level_wave_id = ? AND spawn_index <= ? GROUP BY spawn_index)`, [wave.id, spawn.spawn_index])[0]!.delay;
      expect(spawn.delay).toBe(expected);
      sharedGroup ||= wave.spawns.filter(s => s.spawn_index === spawn.spawn_index).length > 1;
    }
    expect(sharedGroup).toBe(true);
    const paths = await data.paths.getForLevel(level.id);
    const rows = db.read('level_path_point', 'WHERE level_info_id = ? ORDER BY path_index, point_index', [level.id]);
    expect(paths.flatMap(p => p.points)).toEqual(rows.map(p => ({ x: p.map_position_x, y: p.map_position_y })));
    // Raw SQLite paths are not an alternate source of GeoJSON routes. The
    // gameplay loader will keep the native GeoJSON precedence separately.
  } finally { data.close(); }
});

const groups = {
  towers: (data: GameDataAccess) => data.towers.getAll(), enemies: (data: GameDataAccess) => data.enemies.getAll(),
  heroes: (data: GameDataAccess) => data.heroes.getAll(), config: (data: GameDataAccess) => data.configuration.get(),
  meta: (data: GameDataAccess) => data.metaUpgrades.get(), player: (data: GameDataAccess) => data.player.get(),
};
it.each([
  ['tower_type', 'towers'], ['tower', 'towers'], ['tower_history', 'towers'], ['melee_unit', 'towers'],
  ['tower_upgrade_path', 'towers'], ['tower_upgrade_rank', 'towers'], ['enemy_type', 'enemies'], ['enemy_encyclopedia', 'enemies'],
  ['hero', 'heroes'], ['hero_combat', 'heroes'], ['hero_ai', 'heroes'], ['player_hero_control', 'heroes'],
  ['combat_rules', 'config'], ['reinforcement_config', 'config'], ['play_speed', 'config'], ['difficulty', 'config'],
  ['encyclopedia_demo', 'config'], ['meta_upgrade_track', 'meta'], ['meta_upgrade', 'meta'], ['meta_upgrade_effect', 'meta'],
  ['player_meta_upgrade_profile', 'player'], ['player_meta_upgrade_selection', 'player'], ['player_meta_upgrade_level_stars', 'player'],
] as const)('fails missing required %s data through the %s DAO', async (table, group) => {
  const db = fixture.open(); const data = new SqliteGameData(db);
  try {
    db.db.run('PRAGMA foreign_keys = OFF'); db.db.run(`DELETE FROM ${table}`);
    await expect(groups[group](data)).rejects.toThrow();
  } finally { data.close(); }
});

it('requires every SQL NOT NULL field at the decoding boundary, including all tuning', () => {
  const db = fixture.open();
  try {
    for (const table of Object.keys(records) as Table[]) {
      const row = db.rows(`SELECT * FROM ${table} LIMIT 1`)[0]!;
      for (const column of db.rows(`PRAGMA table_info(${table})`).filter(c => c.notnull === 1)) {
        const field = String(column.name);
        const result = records[table].safeParse({ ...row, [field]: null });
        expect(result.success, `${table}.${field}`).toBe(false);
        if (!result.success) expect(result.error.issues.some(issue => issue.path.includes(field)), `${table}.${field}`).toBe(true);
      }
    }
  } finally { db.close(); }
});

it.each([
  ['tower', 'cost', -1, 'towers'], ['tower', 'attack_mode', 'unknown', 'towers'],
  ['tower', 'shot_max_damage', -1, 'towers'], ['tower', 'terror_max', -1, 'towers'],
  ['tower_type', 'level_layout', 'not json', 'towers'], ['tower_type', 'tower_type_key', 'unknown', 'towers'],
  ['enemy_type', 'traits', '[{"type":"unknown"}]', 'enemies'], ['enemy_type', 'enemy_type_key', 'unknown', 'enemies'],
  ['enemy_type', 'damage_min', 99999, 'enemies'], ['enemy_type', 'break_band_lo', 1, 'enemies'],
  ['hero_combat', 'hp', 'wrong type', 'heroes'], ['hero_ai', 'controller', 'unknown', 'heroes'],
  ['hero_ai', 'resume_health_fraction', 0.01, 'heroes'], ['combat_rules', 'grapeshot_spread_degrees', '[1,1]', 'config'],
  ['combat_rules', 'morale_visibility_threshold', 99999, 'config'], ['meta_upgrade', 'upgrade_key', 'unknown', 'meta'],
  ['meta_upgrade_effect', 'parameter', 'unknown', 'meta'], ['meta_upgrade_effect', 'value', 0, 'meta'],
] as const)('diagnoses invalid %s.%s', async (table, field, value, group) => {
  const db = fixture.open(); const data = new SqliteGameData(db);
  try {
    db.db.run('PRAGMA foreign_keys = OFF'); db.db.run('PRAGMA ignore_check_constraints = ON');
    db.db.run(`UPDATE ${table} SET ${field} = ? WHERE rowid = (SELECT rowid FROM ${table} LIMIT 1)`, [value]);
    await expect(groups[group](data)).rejects.toThrow(table);
  } finally { data.close(); }
});

it('rejects gaps, mismatched counts, and missing unlocks with level identity', async () => {
  const db = fixture.open(); const data = new SqliteGameData(db); const level = db.levels()[0]!;
  try {
    db.db.run('PRAGMA foreign_keys = OFF');
    db.db.run('DELETE FROM level_path_point WHERE level_info_id = ? AND point_index = 1', [level.id]);
    await expect(data.paths.getForLevel(level.id)).rejects.toThrow('point_index');
    db.db.run('DELETE FROM level_wave WHERE level_info_id = ? AND wave_index = 1', [level.id]);
    await expect(data.waves.getForLevel(level.id)).rejects.toThrow(level.id);
    db.db.run('DELETE FROM level_tower_unlock WHERE level_info_id = ?', [level.id]);
    await expect(data.unlocks.getForLevel(level.id)).rejects.toThrow(level.id);
  } finally { data.close(); }
});

it('refuses a partially missing enemy roster instead of silently reducing it', async () => {
  const db = fixture.open(); const data = new SqliteGameData(db);
  try {
    db.db.run('PRAGMA foreign_keys = OFF');
    db.db.run('DELETE FROM enemy_type WHERE id = (SELECT id FROM enemy_type LIMIT 1)');
    await expect(data.enemies.getAll()).rejects.toThrow('enemy_type_key');
  } finally { data.close(); }
});

it('writes settings and hero controls to the session SQLite database, validates edits, and refreshes from the seed on relaunch', async () => {
  const db = fixture.open(), data = new SqliteGameData(db), other = new SqliteGameData(fixture.open());
  try {
    const before = await data.player.get();
    for (const key of ['debug_mode', 'show_debug_info', 'show_debug_layout_guides', 'enemy_escape_haptics_enabled', 'show_ga_solution_button'] as const) {
      const next = await data.player.setSetting(key, !before.settings[key]); expect(next.settings[key]).toBe(Number(!before.settings[key]));
      expect((await other.player.get()).settings[key]).toBe(before.settings[key]);
    }
    const hero = before.heroControls[0]!;
    expect((await data.player.setHeroAI(hero.hero_id.toUpperCase(), !hero.ai_enabled)).heroControls.find(h => h.hero_id === hero.hero_id)!.ai_enabled).toBe(Number(!hero.ai_enabled));
    await expect(data.player.setHeroAI('missing', true)).rejects.toThrow('player_hero_control');
    await expect(data.player.setSetting('id' as never, true)).rejects.toThrow('Unknown setting');
    await expect(data.player.setSetting('constructor' as never, true)).rejects.toThrow();
    await expect(data.player.setSetting('debug_mode', 1 as never)).rejects.toThrow('Expected boolean');
    await expect(data.player.setHeroAI(hero.hero_id, 1 as never)).rejects.toThrow('Expected boolean');
    db.db.run('DELETE FROM player_hud_layout');
    const previous = db.one('player_settings').debug_mode;
    await expect(data.player.setSetting('debug_mode', !previous)).rejects.toThrow('player_hud_layout');
    expect(db.one('player_settings').debug_mode).toBe(previous); // failed edit is atomic
  } finally { data.close(); other.close(); }
});
