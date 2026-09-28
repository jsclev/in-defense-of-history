import type { Database, SqlJsStatic, SqlValue } from 'sql.js';
import { z } from 'zod';
import { contentError } from './schema';
import { records, type Row, type Table, type Level } from '../data/records';
export type { Canvas, Level } from '../data/records';

const levelSchema = records.level_info.extend({ campaign_name: z.string().trim().min(1) });

// Each launch owns a fresh in-memory database from bundled bytes. No persistent
// browser or Facebook player state is imported over these authored seeds.
export class ContentDatabase {
  readonly db: Database;
  private closed = false;
  constructor(sql: SqlJsStatic, bytes: Uint8Array) {
    // sql.js may retain and mutate the provided buffer. Own the memory so a
    // later launch/test can always reopen the unchanged bundled seed bytes.
    this.db = new sql.Database(new Uint8Array(bytes));
    try {
      const integrity = this.db.exec('PRAGMA quick_check')[0]?.values[0]?.[0];
      if (integrity !== 'ok') throw new Error(`SQLite quick_check: ${integrity}`);
      const foreignKey = this.rows('PRAGMA foreign_key_check')[0];
      if (foreignKey) {
        const columns = this.rows('SELECT "from" AS field FROM pragma_foreign_key_list(?) WHERE id = ?', [foreignKey.table!, foreignKey.fkid!]);
        throw contentError(`${foreignKey.table}[rowid=${foreignKey.rowid}].${columns.map(c => c.field).join(',')}`,
          `SQLite foreign_key_check: missing referenced ${foreignKey.parent} row`);
      }
      this.db.run('PRAGMA foreign_keys = ON');
      this.levels(); this.canvas(); this.playerSeeds();
    } catch (error) { this.db.close(); throw contentError('database', error); }
  }
  close(): void { if (!this.closed) { this.db.close(); this.closed = true; } }

  rows(query: string, values: SqlValue[] = []): Record<string, SqlValue>[] {
    if (this.closed) throw contentError('database', 'connection is closed');
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

  read<K extends Table>(table: K, clause = '', values: SqlValue[] = []): Row<K>[] {
    return this.rows(`SELECT * FROM ${table} ${clause}`, values).map((row, index) => {
      const keys = Object.entries(row).filter(([key]) => key === 'id' || key.endsWith('_id') || key.endsWith('_key') || key === 'source');
      return this.parse(records[table] as unknown as z.ZodType<Row<K>>, row, `${table}[${keys.map(([, value]) => value).join(':') || index}]`);
    });
  }

  one<K extends Table>(table: K, clause = '', values: SqlValue[] = []): Row<K> {
    const rows = this.read(table, clause, values);
    if (rows.length !== 1) throw contentError(table, `expected one row; found ${rows.length}`);
    return rows[0]!;
  }

  levels(): Level[] {
    const rows = this.rows(`SELECT l.*, c.campaign_name FROM level_info l
      LEFT JOIN campaign c ON c.id = l.campaign_id ORDER BY l.started_at, l.id`);
    if (!rows.length) throw contentError('level_info', 'required rows missing');
    return rows.map(row => this.parse(levelSchema, row, `level_info[${row.id}]`));
  }

  canvas(): Row<'virtual_canvas'> {
    return this.one('virtual_canvas');
  }

  playerSeeds() {
    const settings = this.one('player_settings');
    const selectedDifficulty = this.one('player_selected_difficulty');
    const difficulty = this.one('difficulty', 'WHERE id = ?', [selectedDifficulty.difficulty_id]);
    const selected = this.read('player_selected_hero', 'ORDER BY selection_slot');
    const heroes = selected.map(s => ({ hero_id: s.hero_id, ranking: this.one('hero', 'WHERE id = ?', [s.hero_id]).ranking }))
      .sort((a, b) => b.ranking - a.ranking || a.hero_id.localeCompare(b.hero_id));
    if (heroes.length < 1 || heroes.length > 2) throw contentError('player_selected_hero', 'expected one or two heroes');
    if (selected.some((s, index) => s.selection_slot !== index + 1) || new Set(selected.map(s => s.hero_id)).size !== selected.length)
      throw contentError('player_selected_hero', 'missing or duplicate selection_slot or hero_id');
    const hud = this.read('player_hud_layout');
    if (new Set(hud.map(row => row.hud_section_name)).size !== 4 || new Set(hud.map(row => row.hud_location_name)).size !== 4)
      throw contentError('player_hud_layout', 'expected four distinct sections and locations');
    return { settings, difficulty, heroes, hud };
  }
}
