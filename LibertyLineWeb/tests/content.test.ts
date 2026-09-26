import { afterEach, expect, it, vi } from 'vitest';
import { mkdtemp, readFile, writeFile, mkdir, rm, readdir } from 'node:fs/promises';
import { join, basename, extname } from 'node:path';
import { tmpdir } from 'node:os';
import { art } from '../tools/paths';

vi.mock('../tools/assets', async importOriginal => {
  const original = await importOriginal<typeof import('../tools/assets')>();
  return { ...original,
    catalogSources: vi.fn(async (root: string) => [{ name: 'tower_slot_available',
      file: join(root, 'tower_slot_available.imageset/tower_slot_available.png'), density: 1 as const }]),
    // Codec is independently pixel-tested. This orchestration test still uses
    // the real original SQL builder and real authored GeoJSON/map discovery.
    emitImage: vi.fn(async (source: string, output: string) => {
      const bytes = new Uint8Array([1]); const hash = original.sha256(bytes);
      await mkdir(join(output, 'art'), { recursive: true }); await writeFile(join(output, 'art', `${hash}.png`), bytes);
      return { url: `art/${hash}.png`, sha256: hash, sourceSha256: hash, source,
        width: 2868, height: 2064, density: 1 as const };
    }),
  };
});
import { emitImage, catalogSources } from '../tools/assets';
import { prepareContent } from '../tools/content';

const cleanup: string[] = [];
afterEach(async () => { vi.clearAllMocks(); for (const dir of cleanup.splice(0)) await rm(dir, { recursive: true, force: true }); });
it('assembles portable content from existing sources with no parallel catalog', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'liberty-line-orchestration-')); cleanup.push(dir);
  const destination = join(dir, 'bundle');
  const manifest = await prepareContent(destination);
  expect(catalogSources).toHaveBeenCalledWith(join(art, 'LibertyLineAssets.xcassets'));
  expect(Object.keys(manifest.maps).length).toBeGreaterThan(1);
  for (const file of await readdir(join(art, 'Levels')))
    if (['.png', '.heic'].includes(extname(file))) expect(manifest.images[basename(file, extname(file))]).toBeDefined();
  expect(JSON.parse(await readFile(join(destination, 'content/manifest.json'), 'utf8'))).toEqual(manifest);
  expect((await readFile(join(destination, manifest.database))).subarray(0, 15).toString()).toBe('SQLite format 3');
  for (const map of Object.values(manifest.maps)) {
    expect(JSON.parse(await readFile(join(destination, map.geometry), 'utf8')).type).toBe('FeatureCollection');
    for (const key of [...map.underlay, ...map.occlusion]) expect(manifest.images[key]).toBeDefined();
  }
});
it('fails a missing source without replacing a prior successful output', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'liberty-line-failed-build-')); cleanup.push(dir);
  const destination = join(dir, 'bundle'); await mkdir(destination); await writeFile(join(destination, 'previous'), 'unchanged');
  vi.mocked(emitImage).mockRejectedValueOnce(new Error('missing canonical source'));
  await expect(prepareContent(destination)).rejects.toThrow('missing canonical source');
  expect(await readFile(join(destination, 'previous'), 'utf8')).toBe('unchanged');
});
