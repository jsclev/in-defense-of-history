import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { createRequire } from 'node:module';
import initSqlJs, { type SqlJsStatic } from 'sql.js';
import { ContentDatabase } from '../src/content/database';
import type { Manifest } from '../src/content/schema';
import { native } from '../tools/paths';
import { seedDatabase } from '../tools/seed';

export async function authored() {
  const wasmBinary = await readFile(createRequire(import.meta.url).resolve('sql.js/dist/sql-wasm.wasm'));
  const [sql, bytes] = await Promise.all([initSqlJs({ wasmBinary: new Uint8Array(wasmBinary).buffer }), seedDatabase()]);
  return { sql, bytes, open: () => new ContentDatabase(sql, bytes) };
}
export function testManifest(database: ContentDatabase): Manifest {
  const images: Manifest['images'] = {};
  const maps: Manifest['maps'] = {};
  for (const level of database.levels().filter(l => l.map_image_name)) {
    images[level.map_image_name] = { url: `art/${level.map_image_name}.webp`, width: 2868, height: 2064,
      source: 'test-only', sha256: '0'.repeat(64), sourceSha256: '0'.repeat(64), density: 1 };
    maps[level.map_image_name] = { geometry: `content/${level.map_image_name}.geojson`, underlay: [level.map_image_name], occlusion: [] };
  }
  images.tower_slot_available = { url: 'art/slot.webp', width: 180, height: 100, source: 'test-only',
    sha256: '0'.repeat(64), sourceSha256: '0'.repeat(64), density: 2 };
  return { version: 1, name: 'Test only', database: 'content/test.sqlite', images, maps };
}
export async function geometry(name: string): Promise<unknown> {
  return JSON.parse(await readFile(join(native, 'Db', `${name}.geojson`), 'utf8'));
}
export type Authored = { sql: SqlJsStatic; bytes: Uint8Array; open: () => ContentDatabase };
