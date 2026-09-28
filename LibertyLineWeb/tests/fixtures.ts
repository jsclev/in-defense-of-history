import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { createRequire } from 'node:module';
import initSqlJs, { type SqlJsStatic } from 'sql.js';
import { ContentDatabase } from '../src/content/database';
import type { Manifest } from '../src/content/schema';
import { native } from '../tools/paths';
import { seedDatabase } from '../tools/seed';
import { hudArt } from '../src/hud/view';
import { readSlots } from '../src/content/geometry';
import { SqliteGameData } from '../src/data/sqlite';
import { exportPresentation, exportNavigation } from '../tools/native';
import type { Presentation } from '../src/content/presentation';
import { loadBattleContent } from '../src/game/content';
import { BattleSession } from '../src/game/session';

export async function authored() {
  const wasmBinary = await readFile(createRequire(import.meta.url).resolve('sql.js/dist/sql-wasm.wasm'));
  const [sql, bytes] = await Promise.all([initSqlJs({ wasmBinary: new Uint8Array(wasmBinary).buffer }), seedDatabase()]);
  return { sql, bytes, open: () => new ContentDatabase(sql, bytes) };
}
export function testManifest(database: ContentDatabase, presentation?: Presentation): Manifest {
  const images: Manifest['images'] = {};
  const maps: Manifest['maps'] = {};
  for (const level of database.levels().filter(l => l.map_image_name)) {
    images[level.map_image_name] = { url: `art/${level.map_image_name}.webp`, width: 2868, height: 2064,
      source: 'test-only', sha256: '0'.repeat(64), sourceSha256: '0'.repeat(64), density: 1 };
    maps[level.map_image_name] = { geometry: `content/${level.map_image_name}.geojson`, underlay: [level.map_image_name], occlusion: [] };
  }
  images.tower_slot_available = { url: 'art/slot.webp', width: 180, height: 100, source: 'test-only',
    sha256: '0'.repeat(64), sourceSha256: '0'.repeat(64), density: 2 };
  const profiles = presentation ? [...Object.values(presentation.heroes), presentation.militia] : [];
  for (const key of [...Object.values(hudArt), ...database.read('hero').map(h => h.icon_image_name), ...database.read('enemy_type').map(e => e.image_name),
    ...profiles.flatMap(p => [...p.idle, ...p.walking.flat()]),
    ...presentation ? [presentation.explosion.asset, ...Object.values(presentation.towers).flatMap(t => t.projectile.asset === null ? [] : [t.projectile.asset])] : [],
    'tower_menu_bg', 'tower_menu_square_frame', 'tower_build_confirm', 'tower_locked_icon', 'rally_point_icon', 'tower_slot_field', 'tower_slot_build_flag', 'tower_slot_upgrade', 'engineer_rough_ground',
    ...database.read('tower_upgrade_path').map(p => p.icon_name),
    ...Object.values(presentation?.towers ?? {}).flatMap(t => [t.icon, t.frame, ...Object.values(t.tiers).flatMap(s => [s.art, s.icon, s.atlas].filter((v): v is string => v !== null))])])
    images[key] = { ...images.tower_slot_available, width: 128, height: 128, bounds: { x: 0, y: 0, width: 128, height: 128 }, url: `art/${key}.webp` };
  if(presentation)Object.assign(images[presentation.explosion.asset]!,{width:120,height:90});
  return { version: 1, name: 'Test only', database: 'content/test.sqlite', images, maps };
}
export async function hudBattle(fixture: Authored) {
  const db = fixture.open(), data = new SqliteGameData(db);
  const level = db.levels().find(l => l.map_image_name)!;
  const map = await geometry(level.map_image_name);
  const session = await battleSession(db);
  const result = { level, canvas: db.canvas(), presentation:session.presentation, manifest: testManifest(db, session.presentation), slots: readSlots(map, level.map_image_name),
    hud: { player: session.player, state: session.hud } };
  data.close(); return result;
}
let presentationPromise: ReturnType<typeof exportPresentation> | undefined;
let navigationPromise: ReturnType<typeof exportNavigation> | undefined;
export function presentation() { return presentationPromise ??= authored().then(async fixture => {
  const db = fixture.open(); try { return await exportPresentation(db); } finally { db.close(); }
}); }
export function navigation(db: ContentDatabase) {
  return navigationPromise ??= exportNavigation(db.levels().filter(l => l.map_image_name).map(l => l.map_image_name), db.canvas().path_width);
}
export async function battleSession(db: ContentDatabase, id = db.levels().find(l => l.map_image_name)!.id, now = () => 0) {
  const data = new SqliteGameData(db), level = await data.levels.get(id);
  const [map, nav, art] = await Promise.all([geometry(level.map_image_name), navigation(db), presentation()]);
  return new BattleSession(await loadBattleContent(data, level, map, nav[level.map_image_name]!), art, now,
    { pause() {}, outcome() {}, lifeLost() {} }, () => .5);
}
export async function geometry(name: string): Promise<unknown> {
  return JSON.parse(await readFile(join(native, 'Db', `${name}.geojson`), 'utf8'));
}
export type Authored = { sql: SqlJsStatic; bytes: Uint8Array; open: () => ContentDatabase };
