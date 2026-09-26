import { beforeAll, describe, expect, it } from 'vitest';
import { ContentDatabase } from '../src/content/database';
import { authored, type Authored } from './fixtures';

let fixture: Authored;
beforeAll(async () => { fixture = await authored(); });

describe('authored SQLite content', () => {
  it('loads the real existing SQL through the original builder', () => {
    const db = fixture.open();
    try {
      expect(db.levels().length).toBeGreaterThan(1);
      expect(db.canvas().canvas_width).toBeGreaterThan(0);
      expect(db.playerSeeds().heroes.length).toBeGreaterThan(0);
      expect(db.rows('SELECT COUNT(*) AS count FROM simulator_run')[0]!.count).toBe(0);
    } finally { db.close(); }
  });
  it('propagates edits through DAOs, and a new launch resets player state', () => {
    const db = fixture.open();
    const initial = db.levels()[0]!;
    const settings = db.playerSeeds().settings;
    db.db.run('UPDATE level_info SET starting_money = ? WHERE id = ?', [initial.starting_money + 73, initial.id]);
    db.db.run('UPDATE player_settings SET debug_mode = ?', [1 - settings.debug_mode]);
    expect(db.levels()[0]!.starting_money).toBe(initial.starting_money + 73);
    expect(db.playerSeeds().settings.debug_mode).not.toBe(settings.debug_mode);
    db.close();
    const fresh = fixture.open();
    expect(fresh.levels()[0]!.starting_money).toBe(initial.starting_money);
    expect(fresh.playerSeeds().settings).toEqual(settings);
    fresh.close();
  });
  it.each(['player_settings', 'virtual_canvas', 'player_selected_difficulty', 'player_selected_hero', 'player_hud_layout'])(
    'rejects a missing required %s seed', table => {
      const db = fixture.open();
      db.db.run(`DELETE FROM ${table}`);
      const corrupted = db.db.export(); db.close();
      expect(() => new ContentDatabase(fixture.sql, corrupted)).toThrow(table);
    });
  it('reports record and field for malformed level content', () => {
    const db = fixture.open(); const level = db.levels()[0]!;
    db.db.run('PRAGMA ignore_check_constraints = ON');
    db.db.run('UPDATE level_info SET starting_money = -1 WHERE id = ?', [level.id]);
    expect(() => db.levels()).toThrow(level.id);
    expect(() => db.levels()).toThrow('starting_money');
    db.close();
  });
  it('refuses NULL required content rather than supplying defaults', () => {
    const db = fixture.open();
    expect(() => db.db.run('UPDATE level_info SET starting_money = NULL')).toThrow('NOT NULL');
    db.close();
  });
  it('rejects unknown foreign identifiers and corrupt SQLite', () => {
    const db = fixture.open();
    db.db.run('PRAGMA foreign_keys = OFF');
    db.db.run("UPDATE player_selected_difficulty SET difficulty_id = 'unknown'");
    const corrupted = db.db.export(); db.close();
    expect(() => new ContentDatabase(fixture.sql, corrupted)).toThrow('foreign_key_check');
    expect(() => new ContentDatabase(fixture.sql, new Uint8Array([1,2,3,4]))).toThrow();
  });
  it('rejects wrong SQLite field types and empty names', () => {
    const db = fixture.open();
    db.db.run("UPDATE level_info SET level_name = ''");
    expect(() => db.levels()).toThrow('level_name'); db.close();
  });
});
