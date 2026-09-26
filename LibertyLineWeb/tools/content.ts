import { readFile, writeFile, mkdir, mkdtemp, rm, rename, readdir } from 'node:fs/promises';
import { join, dirname, basename, extname } from 'node:path';
import { tmpdir } from 'node:os';
import initSqlJs from 'sql.js';
import { ContentDatabase } from '../src/content/database';
import { manifestSchema, type Manifest } from '../src/content/schema';
import { readSlots } from '../src/content/geometry';
import { seedDatabase } from './seed';
import { art, native, generated } from './paths';
import { catalogSources, emitImage } from './assets';

export function displayName(config: string): string {
  const matches = [...config.matchAll(/^GAME_DISPLAY_NAME\s*=\s*(.+)$/gm)];
  if (matches.length !== 1) throw new Error('GameName.xcconfig: expected one GAME_DISPLAY_NAME');
  return matches[0]![1]!.trim();
}

export async function prepareContent(destination = generated): Promise<Manifest> {
  const scratch = await mkdtemp(join(tmpdir(), 'liberty-line-content-'));
  const output = join(scratch, 'bundle');
  await mkdir(output);
  let database: ContentDatabase | undefined;
  try {
    const bytes = await seedDatabase();
    database = new ContentDatabase(await initSqlJs(), bytes);
    const manifest: Manifest = { version: 1,
      name: displayName(await readFile(join(native, 'GameName.xcconfig'), 'utf8')),
      database: 'content/in_defense_of_history.sqlite', images: {}, maps: {} };
    await mkdir(join(output, 'content'));
    await writeFile(join(output, manifest.database), bytes);
    const sources = await catalogSources(join(art, 'LibertyLineAssets.xcassets'));
    for (let i = 0; i < sources.length; i++) {
      const source = sources[i]!;
      manifest.images[source.name] = await emitImage(source.file, output, dirname(native), scratch, source.density);
      if (i % 400 === 0) console.log(`Art: ${i}/${sources.length} canonical image sets`);
    }
    const mapFiles = await readdir(join(art, 'Levels'));
    const packedMapFiles = new Set<string>();
    for (const level of database.levels()) {
      const name = level.map_image_name;
      // The native campaign explicitly authors blank map names for unfinished
      // levels. They stay in SQLite, but have no battlefield to preview yet.
      if (name === '') continue;
      if (!/^[a-zA-Z0-9_-]+$/.test(name)) throw new Error(`level_info[${level.id}].map_image_name: unsafe name`);
      if (manifest.maps[name]) continue;
      const geometry = `content/${name}.geojson`;
      const geometryBytes = await readFile(join(native, 'Db', `${name}.geojson`));
      readSlots(JSON.parse(geometryBytes.toString()), name);
      await writeFile(join(output, geometry), geometryBytes);
      const layers = { geometry, underlay: [] as string[], occlusion: [] as string[] };
      for (const suffix of ['', '_path', '_overlay', '_forest_occlusion', '_occlusion']) {
        const key = name + suffix;
        const candidates = mapFiles.filter(file => basename(file, extname(file)) === key && ['.png', '.heic'].includes(extname(file)));
        if (candidates.length === 0 && suffix !== '') continue;
        if (candidates.length !== 1) throw new Error(`${key}: expected one canonical map image, found ${candidates.length}`);
        if (manifest.images[key]) throw new Error(`${key}: duplicate map and catalog asset`);
        manifest.images[key] = await emitImage(join(art, 'Levels', candidates[0]!), output, dirname(native), scratch);
        packedMapFiles.add(candidates[0]!);
        (suffix.includes('occlusion') ? layers.occlusion : layers.underlay).push(key);
      }
      manifest.maps[name] = layers;
    }
    // Mirror the native Levels resource directory as well as the maps used by
    // this milestone. This includes shared terrain (such as the grass texture)
    // without maintaining another list of runtime art names.
    for (const file of mapFiles.sort()) {
      if (!['.png', '.heic'].includes(extname(file)) || packedMapFiles.has(file)) continue;
      const key = basename(file, extname(file));
      if (manifest.images[key]) throw new Error(`${key}: duplicate canonical image in Levels`);
      manifest.images[key] = await emitImage(join(art, 'Levels', file), output, dirname(native), scratch);
    }
    manifestSchema.parse(manifest);
    await writeFile(join(output, 'content/manifest.json'), JSON.stringify(manifest));
    // Only generated output is replaced. Failed preparation preserves the last
    // build and fails the command, so it can never be packaged as a new build.
    await rm(destination, { recursive: true, force: true });
    await rename(output, destination);
    console.log(`${sources.length} image sets, ${Object.keys(manifest.maps).length} maps, ${bytes.length} database bytes`);
    return manifest;
  } finally { database?.close(); await rm(scratch, { recursive: true, force: true }); }
}
