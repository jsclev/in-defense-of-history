import { readFile, readdir, mkdir, writeFile } from 'node:fs/promises';
import { join, dirname } from 'node:path';
import { zipSync, unzipSync, type Zippable } from 'fflate';
import { manifestSchema } from '../src/content/schema';
import { sha256 } from './assets';

export async function packageDirectory(directory: string, destination: string): Promise<number> {
  const files: Record<string, Uint8Array> = {};
  async function visit(path: string): Promise<void> {
    for (const entry of (await readdir(join(directory, path), { withFileTypes: true })).sort((a,b) => a.name.localeCompare(b.name))) {
      const name = path ? `${path}/${entry.name}` : entry.name;
      if (entry.isSymbolicLink()) throw new Error(`ZIP cannot contain symlinks: ${name}`);
      if (entry.isDirectory()) await visit(name);
      else if (entry.isFile()) files[name] = await readFile(join(directory, name));
    }
  }
  await visit('');
  if (!files['index.html']) throw new Error('ZIP requires index.html at its root');
  const manifest = manifestSchema.parse(JSON.parse(Buffer.from(files['content/manifest.json'] ?? []).toString()));
  for (const asset of Object.values(manifest.images)) {
    const bytes = files[asset.url];
    if (!bytes || sha256(bytes) !== asset.sha256) throw new Error(`Missing or corrupt ZIP asset: ${asset.url}`);
  }
  for (const path of [manifest.database, ...Object.values(manifest.maps).map(m => m.geometry)])
    if (!files[path]) throw new Error(`Missing ZIP content: ${path}`);
  const entries: Zippable = Object.fromEntries(Object.entries(files).map(([name, bytes]) =>
    [name, [bytes, { level: /\.(png|webp|jpg|jpeg)$/.test(name) ? 0 : 6 }]]));
  const zip = zipSync(entries, { mtime: new Date(2020, 0, 1) });
  // Artwork is already compressed; compress code, SQLite and GeoJSON normally.
  // Verify the actual archive bytes, not just a directory listing.
  const extracted = unzipSync(zip);
  for (const [name, bytes] of Object.entries(files))
    if (!extracted[name] || sha256(extracted[name]!) !== sha256(bytes)) throw new Error(`ZIP verification failed: ${name}`);
  await mkdir(dirname(destination), { recursive: true });
  await writeFile(destination, zip);
  return zip.length;
}
