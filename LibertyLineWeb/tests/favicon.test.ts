import { afterEach, expect, it } from 'vitest';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import sharp from 'sharp';
import { emitFavicons } from '../tools/favicon';
import { art, project } from '../tools/paths';

const cleanup: string[] = [];
afterEach(async () => { for (const path of cleanup.splice(0)) await rm(path, { recursive: true, force: true }); });
async function scratch() {
  const path = await mkdtemp(join(tmpdir(), 'liberty-line-favicon-test-'));
  cleanup.push(path);
  return path;
}

it('ships the canonical portrait at every linked tab density, including the ICO frames', async () => {
  const output = await scratch(), source = join(art, 'Web/favicon.png');
  const original = await readFile(source);
  await emitFavicons(source, output);
  const html = await readFile(join(project, 'index.html'), 'utf8');
  const ico = await readFile(join(output, 'favicon.ico'));
  expect([...ico.subarray(0, 6)]).toEqual([0, 0, 1, 0, 3, 0]);
  expect(html).toContain('href="./favicon.ico?');
  for (const [index, size] of [16, 32, 48].entries()) {
    const png = await readFile(join(output, `favicon-${size}.png`));
    expect(html).toContain(`sizes="${size}x${size}" href="./favicon-${size}.png?`);
    expect(await sharp(png).metadata()).toMatchObject({ width: size, height: size, format: 'png' });
    const alpha = await sharp(png).extractChannel('alpha').raw().toBuffer();
    expect(Math.min(...alpha)).toBe(0);
    expect(Math.max(...alpha)).toBe(255);
    expect(await sharp(png).raw().toBuffer()).toEqual(await sharp(original).resize(size, size).ensureAlpha().raw().toBuffer());
    const entry = 6 + index * 16;
    expect([...ico.subarray(entry, entry + 8)]).toEqual([size, size, 0, 0, 1, 0, 32, 0]);
    const offset = ico.readUInt32LE(entry + 12), length = ico.readUInt32LE(entry + 8);
    expect(ico.subarray(offset, offset + length)).toEqual(png);
  }
  expect(await readFile(source)).toEqual(original);
});

it('propagates source changes and fails missing, malformed or undersized artwork', async () => {
  const dir = await scratch(), source = join(dir, 'source.png'), output = join(dir, 'output');
  await expect(emitFavicons(source, output)).rejects.toThrow();
  for (const [width, height] of [[64, 32], [16, 16]]) {
    await sharp({ create: { width: width!, height: height!, channels: 4, background: '#123456' } }).png().toFile(source);
    await expect(emitFavicons(source, output)).rejects.toThrow('square and at least 48 pixels');
  }
  const results: Buffer[] = [];
  for (const color of ['#123456', '#abcdef']) {
    await sharp({ create: { width: 64, height: 64, channels: 4, background: color } }).png().toFile(source);
    await emitFavicons(source, output);
    results.push(await readFile(join(output, 'favicon-16.png')));
  }
  expect(results[0]).not.toEqual(results[1]);
});
