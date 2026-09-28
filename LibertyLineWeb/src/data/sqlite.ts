import type { SqlJsStatic } from 'sql.js';
import { ContentDatabase } from '../content/database';
import { contentError } from '../content/schema';
import { enemyKind, metaRequirements, metaTrack, profileKey, records, towerKind, type Row, type Table } from './records';
import type { Configuration, EnemyDefinition, GameDataAccess, HeroDefinition, MetaCatalog, MetaState,
  Path, PlayerState, PlayerSetting, TowerDefinition, Wave } from './contracts';

function requireContent(condition: unknown, record: string, field: string, message: string): asserts condition {
  if (!condition) throw contentError(`${record}.${field}`, message);
}
function exactlyOne<T>(rows: T[], record: string, field: string): T {
  requireContent(rows.length === 1, record, field, `expected one required row; found ${rows.length}`);
  return rows[0]!;
}
function complete(actual: (string | number)[], expected: (string | number)[], record: string, field: string) {
  requireContent(actual.length === expected.length && new Set(actual).size === actual.length && expected.every(key => actual.includes(key)),
    record, field, 'missing, duplicate or unknown entries');
}

// Implements the read side of the native DAOs. All queries read fresh content;
// returned records are detached from SQLite and cannot mutate subsequent reads.
export class SqliteGameData implements GameDataAccess {
  constructor(private readonly database: ContentDatabase) {}
  close() { this.database.close(); }
  readonly campaigns = {
    getAll: async () => this.database.read('campaign', 'ORDER BY campaign_name, id'),
    get: async (id: string) => this.database.one('campaign', 'WHERE id = ?', [id.toLowerCase()]),
  };
  readonly levels = {
    getAll: async () => this.database.levels(),
    get: async (id: string) => this.level(id),
    getForCampaign: async (id: string) => {
      const campaign = await this.campaigns.get(id);
      return this.database.levels().filter(level => level.campaign_id === campaign.id);
    },
  };
  private level(id: string) {
    return exactlyOne(this.database.levels().filter(level => level.id === id.toLowerCase()), `level_info[${id}]`, 'id');
  }
  readonly towers = { getAll: async () => this.readTowers() };
  readonly enemies = { getAll: async () => this.readEnemies() };
  readonly heroes = { getAll: async () => this.readHeroes() };
  readonly waves = {
    getForLevel: async (id: string) => this.readWaves(id),
    // Inspect one authored wave without claiming the entire campaign is playable.
    get: async (id: string, number: number) => {
      const level = this.level(id);
      return this.readWave(this.database.one('level_wave', 'WHERE level_info_id = ? AND wave_index = ?', [level.id, number]));
    },
  };
  readonly paths = { getForLevel: async (id: string) => this.readPaths(id) };
  readonly unlocks = { getForLevel: async (id: string) => this.readUnlocks(id) };
  readonly levelHeroes = { getForLevel: async (id: string) => {
    const level = this.level(id);
    return this.database.read('level_hero', 'WHERE level_info_id = ? ORDER BY enemy_path_index, hero_id', [level.id]);
  } };
  readonly configuration = { get: async () => this.readConfiguration() };
  readonly metaUpgrades = { get: async () => this.readMetaCatalog() };
  readonly player = {
    get: async () => this.readPlayer(), getMetaUpgrades: async (profile: MetaState['profile']) => this.readMetaState(profile),
    setSetting: async (key: PlayerSetting, enabled: boolean) => {
      requireContent(key !== ('id' as string) && Object.hasOwn(records.player_settings.shape, key), 'player_settings', key, 'Unknown setting');
      requireContent(typeof enabled === 'boolean', 'player_settings', key, 'Expected boolean');
      this.database.one('player_settings');
      return this.editPlayer(() => this.database.db.run(`UPDATE player_settings SET ${key} = ? WHERE id = 1`, [Number(enabled)]));
    },
    setHeroAI: async (id: string, enabled: boolean) => {
      requireContent(typeof enabled === 'boolean', `player_hero_control[${id}]`, 'ai_enabled', 'Expected boolean');
      const control = this.database.one('player_hero_control', 'WHERE hero_id = ?', [id.toLowerCase()]);
      return this.editPlayer(() => this.database.db.run('UPDATE player_hero_control SET ai_enabled = ? WHERE hero_id = ?', [Number(enabled), control.hero_id]));
    },
  };
  private editPlayer(edit: () => void): PlayerState {
    this.database.db.run('BEGIN');
    try { edit(); const player = this.readPlayer(); this.database.db.run('COMMIT'); return player; }
    catch (error) { this.database.db.run('ROLLBACK'); throw error; }
  }

  private readTowers(): TowerDefinition[] {
    const db = this.database;
    const types = db.read('tower_type', 'ORDER BY tower_type_key');
    complete(types.map(t => t.tower_type_key), towerKind.options, 'tower_type', 'tower_type_key');
    const tiers = db.read('tower', 'ORDER BY tower_level, branch');
    const history = db.read('tower_history');
    const melee = db.read('melee_unit');
    const paths = db.read('tower_upgrade_path', 'ORDER BY slot');
    const ranks = db.read('tower_upgrade_rank', 'ORDER BY rank');
    return types.map(type => {
      const selected = tiers.filter(t => t.tower_type_id === type.id);
      complete(selected.map(t => `${t.tower_level}:${t.branch}`), type.level_layout.flatMap((branches, index) => branches.map(b => `${index + 1}:${b}`)),
        `tower_type[${type.id}]`, 'level_layout');
      return { ...type, tiers: selected.map(tier => {
        const record = `tower[${tier.id}]`;
        const soldiers = melee.filter(m => m.tower_id === tier.id);
        requireContent(soldiers.length === tier.has_melee_unit, record, 'has_melee_unit', 'Requires exactly its authored melee capability rows');
        const guide = exactlyOne(history.filter(h => h.tower_id === tier.id), record, 'tower_history');
        requireContent(guide.presentation_kind !== 'mortarStudy' || tier.attack_mode === 'shell', record, 'attack_mode', 'mortarStudy requires shell');
        requireContent(guide.presentation_kind !== 'siegeStudy' || tier.attack_mode === 'solidShot', record, 'attack_mode', 'siegeStudy requires solidShot');
        const upgrades = paths.filter(p => p.tower_id === tier.id);
        requireContent(tier.upgrade_path_count === (tier.tower_level === 4 ? 2 : 0), record, 'upgrade_path_count', 'Expected two specialization paths at level 4, zero before');
        complete(upgrades.map(p => p.slot), Array.from({ length: tier.upgrade_path_count }, (_, i) => i + 1), record, 'upgrade_path_count');
        return { ...tier, history: guide, melee: soldiers.length ? soldiers[0]! : null,
          upgrades: upgrades.map(path => {
            const selectedRanks = ranks.filter(r => r.path_id === path.id);
            complete(selectedRanks.map(r => r.rank), Array.from({ length: path.rank_count }, (_, i) => i + 1), `tower_upgrade_path[${path.id}]`, 'rank_count');
            return { ...path, ranks: selectedRanks };
          }) };
      }) };
    });
  }
  private readEnemies(): EnemyDefinition[] {
    const enemies = this.database.read('enemy_type', 'ORDER BY enemy_type_name, id');
    complete(enemies.map(e => e.enemy_type_key), enemyKind.options, 'enemy_type', 'enemy_type_key');
    const entries = this.database.read('enemy_encyclopedia');
    return enemies.map(enemy => ({ ...enemy, encyclopedia: exactlyOne(entries.filter(e => e.enemy_type_id === enemy.id),
      `enemy_type[${enemy.id}]`, 'enemy_encyclopedia') }));
  }
  private readHeroes(): HeroDefinition[] {
    const db = this.database;
    const heroes = db.read('hero', 'ORDER BY ranking DESC, id');
    requireContent(heroes.length, 'hero', 'id', 'Missing authored roster');
    const combat = db.read('hero_combat'), ai = db.read('hero_ai'), controls = db.read('player_hero_control');
    const unlocked = db.read('player_unlocked_hero'), waves = db.read('level_wave');
    return heroes.map(hero => ({ ...hero,
      combat: exactlyOne(combat.filter(c => c.hero_id === hero.id), `hero[${hero.id}]`, 'hero_combat'),
      ai: exactlyOne(ai.filter(c => c.hero_id === hero.id), `hero[${hero.id}]`, 'hero_ai'),
      control: exactlyOne(controls.filter(c => c.hero_id === hero.id), `hero[${hero.id}]`, 'player_hero_control'),
      unlocked: unlocked.some(u => u.hero_id === hero.id),
      unlockWave: exactlyOne(waves.filter(w => w.id === hero.unlocked_at_level_wave_id), `hero[${hero.id}]`, 'unlocked_at_level_wave_id'),
    }));
  }
  private readPaths(id: string): Path[] {
    const level = this.level(id);
    const points = this.database.read('level_path_point', 'WHERE level_info_id = ? ORDER BY path_index, point_index', [level.id]);
    const indices = [...new Set(points.map(p => p.path_index))];
    complete(indices, indices.map((_, index) => index), `level_path_point[${id}]`, 'path_index');
    return indices.map(index => {
      const path = points.filter(p => p.path_index === index);
      requireContent(path.length >= 2, `level_path_point[${id}:${index}]`, 'point_index', 'Path requires at least two points');
      complete(path.map(p => p.point_index), path.map((_, i) => i), `level_path_point[${id}:${index}]`, 'point_index');
      return { index, points: path.map(p => ({ x: p.map_position_x, y: p.map_position_y })) };
    });
  }
  private readWaves(id: string): Wave[] {
    const level = this.level(id);
    const waves = this.database.read('level_wave', 'WHERE level_info_id = ? ORDER BY wave_index', [level.id]);
    complete(waves.map(w => w.wave_index), Array.from({ length: level.num_waves }, (_, i) => i + 1), `level_info[${id}]`, 'num_waves');
    return waves.map(wave => this.readWave(wave));
  }
  private readWave(wave: Row<'level_wave'>): Wave {
    const spawns = this.database.read('level_wave_enemy_spawn', 'WHERE level_wave_id = ? ORDER BY spawn_index, id', [wave.id]);
    let delay = 0;
    const groups = new Map<number, number>();
    return { ...wave, spawns: spawns.map(spawn => {
      const previous = groups.get(spawn.spawn_index);
      if (previous === undefined) { groups.set(spawn.spawn_index, spawn.spawn_time_since_previous_spawn); delay += spawn.spawn_time_since_previous_spawn; }
      else requireContent(previous === spawn.spawn_time_since_previous_spawn, `level_wave_enemy_spawn[${spawn.id}]`, 'spawn_time_since_previous_spawn', 'Simultaneous spawn group has inconsistent gap');
      return { ...spawn, delay };
    }) };
  }
  private readUnlocks(id: string): Row<'level_tower_unlock'>[] {
    const level = this.level(id);
    const unlocks = this.database.read('level_tower_unlock', 'WHERE level_info_id = ? ORDER BY tower_kind', [level.id]);
    const types = this.database.read('tower_type');
    complete(unlocks.map(u => u.tower_kind), towerKind.options, `level_tower_unlock[${id}]`, 'tower_kind');
    for (const unlock of unlocks) {
      const type = exactlyOne(types.filter(t => t.tower_type_key === unlock.tower_kind), 'tower_type', 'tower_type_key');
      requireContent(unlock.max_tower_level <= type.level_layout.length, `level_tower_unlock[${id}:${unlock.tower_kind}]`, 'max_tower_level', 'Exceeds authored levels');
    }
    return unlocks;
  }
  private readConfiguration(): Configuration {
    const db = this.database;
    const playSpeeds = db.read('play_speed', 'ORDER BY source');
    complete(playSpeeds.map(p => p.source), ['player', 'simulator', 'editor'], 'play_speed', 'source');
    const difficulties = db.read('difficulty', 'ORDER BY difficulty_level');
    complete(difficulties.map(d => d.difficulty_level), [1, 2, 3, 4], 'difficulty', 'difficulty_level');
    const encyclopediaDemo = db.one('encyclopedia_demo');
    this.level(encyclopediaDemo.context_level_id);
    return { canvas: db.canvas(), combat: db.one('combat_rules'), reinforcement: db.one('reinforcement_config'), playSpeeds, difficulties, encyclopediaDemo };
  }
  private readMetaCatalog(): MetaCatalog {
    const db = this.database;
    const tracks = db.read('meta_upgrade_track', 'ORDER BY display_order');
    complete(tracks.map(t => t.track_key), metaTrack.options, 'meta_upgrade_track', 'track_key');
    const upgrades = db.read('meta_upgrade', 'ORDER BY track_key, display_order');
    complete(upgrades.map(u => u.upgrade_key), Object.keys(metaRequirements), 'meta_upgrade', 'upgrade_key');
    const effects = db.read('meta_upgrade_effect', 'ORDER BY parameter');
    for (const track of tracks) {
      const nodes = upgrades.filter(u => u.track_key === track.track_key);
      requireContent(nodes.length, `meta_upgrade_track[${track.track_key}]`, 'upgrade_key', 'Missing authored upgrades');
      complete(nodes.map(n => n.display_order), nodes.map((_, i) => i + 1), `meta_upgrade_track[${track.track_key}]`, 'display_order');
      for (const node of nodes) if (node.prerequisite_key !== null) {
        requireContent(nodes.some(n => n.upgrade_key === node.prerequisite_key && n.display_order < node.display_order),
          `meta_upgrade[${node.upgrade_key}]`, 'prerequisite_key', 'Must identify an earlier upgrade in the same track');
      }
    }
    return { tracks, upgrades: upgrades.map(upgrade => {
      const amounts = effects.filter(e => e.upgrade_key === upgrade.upgrade_key);
      complete(amounts.map(e => e.parameter), [...metaRequirements[upgrade.upgrade_key]], `meta_upgrade[${upgrade.upgrade_key}]`, 'effects');
      return { ...upgrade, effects: amounts };
    }) };
  }
  private readMetaState(profile: MetaState['profile']): MetaState {
    profileKey.parse(profile);
    const db = this.database;
    complete(db.read('player_meta_upgrade_profile').map(p => p.profile_key), profileKey.options, 'player_meta_upgrade_profile', 'profile_key');
    const catalog = this.readMetaCatalog();
    const selections = db.read('player_meta_upgrade_selection', 'WHERE profile_key = ? ORDER BY upgrade_key', [profile]);
    const stars = db.read('player_meta_upgrade_level_stars', 'WHERE profile_key = ? ORDER BY level_info_id', [profile]);
    complete(selections.map(s => s.upgrade_key), catalog.upgrades.map(u => u.upgrade_key), `player_meta_upgrade_selection[${profile}]`, 'upgrade_key');
    complete(stars.map(s => s.level_info_id), db.levels().map(l => l.id), `player_meta_upgrade_level_stars[${profile}]`, 'level_info_id');
    const selected = new Set(selections.filter(s => s.is_selected).map(s => s.upgrade_key));
    let spent = 0;
    for (const upgrade of catalog.upgrades) if (selected.has(upgrade.upgrade_key)) {
      requireContent(upgrade.prerequisite_key === null || selected.has(upgrade.prerequisite_key),
        `player_meta_upgrade_selection[${profile}:${upgrade.upgrade_key}]`, 'is_selected', 'Missing selected prerequisite');
      spent += upgrade.star_cost;
    }
    const earned = stars.reduce((sum, row) => sum + row.best_stars, 0);
    requireContent(spent <= earned, `player_meta_upgrade_selection[${profile}]`, 'is_selected', 'Spent stars exceed earned stars');
    return { profile, selections, stars, earned, spent, available: earned - spent };
  }
  private readPlayer(): PlayerState {
    const seeds = this.database.playerSeeds();
    const heroes = this.readHeroes();
    return { settings: seeds.settings, difficulty: seeds.difficulty, hud: seeds.hud,
      selectedHeroes: seeds.heroes.map(h => exactlyOne(heroes.filter(hero => hero.id === h.hero_id), 'player_selected_hero', 'hero_id')),
      unlockedHeroes: this.database.read('player_unlocked_hero'), heroControls: heroes.map(h => h.control), meta: this.readMetaState('active') };
  }

  // Validate before publishing the DAL to a caller. A failed load owns no live
  // connection. Future reads still validate, rather than relying on this check.
  async validate(): Promise<void> {
    // Decode all supplied rows, including content for unfinished levels. Wave
    // completeness is checked by the level-specific DAO when that level is
    // requested; metadata browsing must not start an unfinished battle.
    for (const table of Object.keys(records) as Table[]) this.database.read(table);
    this.readTowers(); this.readEnemies(); this.readHeroes(); this.readConfiguration(); this.readPlayer(); this.readMetaState('level15');
    for (const level of this.database.levels()) {
      this.readPaths(level.id); this.readUnlocks(level.id);
      await this.levelHeroes.getForLevel(level.id);
    }
  }
}

export async function loadSqliteData(url: string, deps: { fetch: typeof fetch; sql: () => Promise<SqlJsStatic> }): Promise<GameDataAccess> {
  const response = await deps.fetch(url, { cache: 'no-store' });
  if (!response.ok) throw contentError('database', `${url}: HTTP ${response.status}`);
  const [sql, bytes] = await Promise.all([deps.sql(), response.arrayBuffer()]);
  const data = new SqliteGameData(new ContentDatabase(sql, new Uint8Array(bytes)));
  try { await data.validate(); return data; }
  catch (error) { data.close(); throw error; }
}
