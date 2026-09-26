import { createHash } from 'node:crypto';
import { readdir, readFile, mkdir, writeFile } from 'node:fs/promises';
import { basename, dirname, extname, join, relative, resolve, sep } from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import sharp from 'sharp';
import { z } from 'zod';
import type { ImageAsset } from '../src/content/schema';

export const sha256 = (bytes: Uint8Array): string => createHash('sha256').update(bytes).digest('hex');
const contentsSchema = z.object({ images: z.array(z.object({ filename: z.string().optional(),
  idiom: z.string(), scale: z.enum(['1x', '2x', '3x']).optional() })) });

export function selectRendition(contents: unknown, name: string): { filename: string; density: 1 | 2 } {
  const images = contentsSchema.parse(contents).images.filter(i => i.filename);
  if (images.some(i => i.idiom !== 'universal')) throw new Error(`${name}: unexpected device-specific artwork`);
  // One-density assets are preserved. Multi-density assets must have the common
  // web density; never silently substitute a different artwork or resolution.
  const density = images.length === 1 ? 1 : 2;
  const matches = images.filter(i => i.scale === `${density}x` || (images.length === 1 && !i.scale));
  if (matches.length !== 1) throw new Error(`${name}: expected exactly one ${density}x rendition`);
  const filename = matches[0]!.filename!;
  if (basename(filename) !== filename || filename === '.' || filename === '..') throw new Error(`${name}: unsafe filename`);
  return { filename, density };
}

export async function catalogSources(catalog: string): Promise<{ name: string; file: string; density: 1 | 2 }[]> {
  const found: { name: string; file: string; density: 1 | 2 }[] = [];
  async function visit(folder: string): Promise<void> {
    for (const entry of (await readdir(folder, { withFileTypes: true })).sort((a,b) => a.name.localeCompare(b.name))) {
      if (!entry.isDirectory()) continue;
      const child = join(folder, entry.name);
      if (entry.name.endsWith('.imageset')) {
        const name = basename(child, '.imageset');
        const rendition = selectRendition(JSON.parse(await readFile(join(child, 'Contents.json'), 'utf8')), name);
        found.push({ name, file: join(child, rendition.filename), density: rendition.density });
      } else if (!entry.name.endsWith('.appiconset') && !entry.name.endsWith('.colorset')) await visit(child);
    }
  }
  await visit(catalog);
  if (!found.length) throw new Error(`No image sets in ${catalog}`);
  if (new Set(found.map(i => i.name)).size !== found.length) throw new Error('Duplicate canonical image names');
  return found;
}

export async function emitImage(source: string, output: string, workspace: string, scratch: string, density: 1 | 2 = 1): Promise<ImageAsset> {
  const sourceBytes = await readFile(source);
  let input: Buffer | string = sourceBytes;
  if (extname(source).toLowerCase() === '.heic') {
    // Native macOS image conversion, not a replacement source asset. Sharp's
    // portable prebuilt decoder does not include HEVC.
    input = join(scratch, `${sha256(sourceBytes)}.png`);
    await promisify(execFile)('/usr/bin/sips', ['-s', 'format', 'png', source, '--out', input]);
  }
  const { data, info } = await sharp(input).webp({ lossless: true, effort: 1 }).toBuffer({ resolveWithObject: true });
  // Optimized PNGs can already be smaller than lossless WebP. Keep the smaller
  // lossless representation without changing pixels, density, or composition.
  const keepPng = extname(source).toLowerCase() === '.png' && sourceBytes.length <= data.length;
  const encoded = keepPng ? sourceBytes : data;
  const digest = sha256(encoded);
  const url = `art/${digest}.${keepPng ? 'png' : 'webp'}`;
  await mkdir(dirname(join(output, url)), { recursive: true });
  await writeFile(join(output, url), encoded); // identical bytes share one file
  const rel = relative(workspace, resolve(source));
  if (rel.startsWith(`..${sep}`)) throw new Error('Art source outside shared workspace');
  return { url, width: info.width, height: info.height, density, sha256: digest,
    source: rel.split(sep).join('/'), sourceSha256: sha256(sourceBytes) };
}
