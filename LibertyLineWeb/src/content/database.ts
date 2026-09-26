import type { Database, SqlJsStatic, SqlValue } from 'sql.js';
import { z } from 'zod';
import { contentError, positive } from './schema';

const levelSchema = z.object({
  id: z.uuid(), level_name: z.string().trim().min(1), campaign_name: z.string().trim().min(1),
  starting_money: positive.int(), num_starting_lives: positive.int(),
  num_waves: z.number().int().nonnegative(), map_image_name: z.string(), started_at: positive,
});
export type Level = z.infer<typeof levelSchema>;
const canvasSchema = z.object({
  canvas_width: positive, canvas_height: positive,
  play_area_x: z.number().nonnegative(), play_area_y: z.number().nonnegative(),
  play_area_width: positive, play_area_height: positive, slot_width: positive, slot_height: positive,
}).refine(c => c.play_area_x + c.play_area_width <= c.canvas_width && c.play_area_y + c.play_area_height <= c.canvas_height,
  'play_area must fit inside canvas');
export type Canvas = z.infer<typeof canvasSchema>;

// Each launch owns a fresh in-memory database from bundled bytes. No persistent
// browser or Facebook player state is imported over these authored seeds.
export class ContentDatabase {
  readonly db: Database;
  constructor(sql: SqlJsStatic, bytes: Uint8Array) {
    // sql.js may retain and mutate the provided buffer. Own the memory so a
    // later launch/test can always reopen the unchanged bundled seed bytes.
    this.db = new sql.Database(new Uint8Array(bytes));
    try {
      const integrity = this.db.exec('PRAGMA quick_check')[0]?.values[0]?.[0];
      if (integrity !== 'ok') throw new Error(`SQLite quick_check: ${integrity}`);
      if (this.db.exec('PRAGMA foreign_key_check').length) throw new Error('SQLite foreign_key_check failed');
      this.db.run('PRAGMA foreign_keys = ON');
      this.levels(); this.canvas(); this.playerSeeds();
    } catch (error) { this.db.close(); throw contentError('database', error); }
  }
  close(): void { this.db.close(); }

  rows(query: string, values: SqlValue[] = []): Record<string, SqlValue>[] {
    const stmt = this.db.prepare(query);
    try {
      stmt.bind(values);
      const rows: Record<string, SqlValue>[] = [];
      while (stmt.step()) rows.push(stmt.getAsObject());
      return rows;
    } finally { stmt.free(); }
  }

  private parse<T>(schema: z.ZodType<T>, row: unknown, record: string): T {
    try { return schema.parse(row); } catch (error) { throw contentError(record, error); }
  }

  private one(query: string, table: string): Record<string, SqlValue> {
    const rows = this.rows(query);
    if (rows.length !== 1) throw contentError(table, `expected one row; found ${rows.length}`);
    return rows[0]!;
  }

  levels(): Level[] {
    const rows = this.rows(`SELECT l.*, c.campaign_name FROM level_info l
      LEFT JOIN campaign c ON c.id = l.campaign_id ORDER BY l.started_at, l.id`);
    if (!rows.length) throw contentError('level_info', 'required rows missing');
    return rows.map(row => this.parse(levelSchema, row, `level_info[${row.id}]`));
  }

  canvas(): Canvas {
    return this.parse(canvasSchema, this.one('SELECT * FROM virtual_canvas', 'virtual_canvas'), 'virtual_canvas');
  }

  playerSeeds() {
    const boolean = z.union([z.literal(0), z.literal(1)]);
    const settings = this.parse(z.object({ id: z.literal(1), debug_mode: boolean, show_debug_info: boolean,
      show_debug_layout_guides: boolean, enemy_escape_haptics_enabled: boolean, show_ga_solution_button: boolean }),
    this.one('SELECT * FROM player_settings', 'player_settings'), 'player_settings[1]');
    const difficulty = this.parse(z.object({ difficulty_id: z.uuid(), difficulty_level: z.number().int().min(1).max(4),
      difficulty_name: z.string().trim().min(1), enemy_hp_multiplier: positive }),
    this.one(`SELECT s.difficulty_id, d.* FROM player_selected_difficulty s
      LEFT JOIN difficulty d ON d.id = s.difficulty_id WHERE s.selection_slot = 1`, 'player_selected_difficulty'), 'player_selected_difficulty[1]');
    const heroes = this.rows(`SELECT s.hero_id, h.ranking FROM player_selected_hero s
      LEFT JOIN hero h ON h.id = s.hero_id ORDER BY h.ranking DESC, h.id COLLATE NOCASE`)
      .map(row => this.parse(z.object({ hero_id: z.uuid(), ranking: z.number().int() }), row, `player_selected_hero[${row.hero_id}]`));
    if (heroes.length < 1 || heroes.length > 2) throw contentError('player_selected_hero', 'expected one or two heroes');
    const hud = this.rows('SELECT * FROM player_hud_layout').map(row => this.parse(z.object({
      hud_section_name: z.enum(['hero_bar', 'stats_view', 'misc_view', 'master_controls']),
      hud_location_name: z.enum(['north_west', 'north', 'north_east', 'west', 'east', 'south_west', 'south', 'south_east']),
    }), row, `player_hud_layout[${row.id}]`));
    if (new Set(hud.map(row => row.hud_section_name)).size !== 4 || new Set(hud.map(row => row.hud_location_name)).size !== 4)
      throw contentError('player_hud_layout', 'expected four distinct sections and locations');
    return { settings, difficulty, heroes, hud };
  }
}
