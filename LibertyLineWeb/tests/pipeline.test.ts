import { afterEach, describe, expect, it, vi } from 'vitest';
import { mkdtemp, mkdir, readFile, writeFile, rm, readdir, symlink } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import sharp from 'sharp';
import { unzipSync } from 'fflate';
import { alphaBounds, catalogSources, emitImage, selectRendition, sha256 } from '../tools/assets';

it('exports precise alpha bounds without dropping faint pixels or inventing bounds for an empty image',()=>{
  const pixels=new Uint8Array(4*5*4);pixels[(1*5+2)*4+3]=1;pixels[(3*5+3)*4+3]=255;
  expect(alphaBounds(pixels,5,4)).toEqual({x:2,y:1,width:2,height:3});
  expect(alphaBounds(new Uint8Array(4*5*4),5,4)).toEqual({x:0,y:0,width:5,height:4});
});
import { packageDirectory } from '../tools/archive';
import { displayName } from '../tools/content';
import { webConfig } from '../tools/config';
import type { Manifest } from '../src/content/schema';
import type { Plugin } from 'vite';
import { presentation } from './fixtures';
import { art as artRoot } from '../tools/paths';

const cleanup: string[] = [];
async function scratch() { const dir = await mkdtemp(join(tmpdir(), 'liberty-line-test-')); cleanup.push(dir); return dir; }
afterEach(async () => { for (const dir of cleanup.splice(0)) await rm(dir, { recursive: true, force: true }); });

describe('single source art pipeline', () => {
  it.each([
    {name:'tower_slot_build_flag',logical:32,hotspot:[5,12]},
    {name:'tower_slot_upgrade',logical:43,hotspot:[22,4]},
  ])('keeps $name transparent at every canonical density with the hotspot on its artwork',async({name,logical,hotspot})=>{
    const folder=join(artRoot,`LibertyLineAssets.xcassets/${name}.imageset`);
    const catalog=JSON.parse(await readFile(join(folder,'Contents.json'),'utf8')) as {images:{filename:string;scale:string}[]};
    expect(catalog.images.map(i=>i.scale)).toEqual(['1x','2x','3x']);
    for(const entry of catalog.images){
      const side=logical*Number.parseInt(entry.scale),{data,info}=await sharp(join(folder,entry.filename)).ensureAlpha().raw().toBuffer({resolveWithObject:true});
      expect([info.width,info.height]).toEqual([side,side]);
      for(const index of [0,side-1,side*(side-1),side*side-1])expect(data[index*4+3]).toBe(0);
      // The cursor's click point stays on the visible hammer head or arrow tip.
      const density=Number.parseInt(entry.scale);
      expect(data[(hotspot[1]!*density*side+hotspot[0]!*density)*4+3]).toBeGreaterThan(128);
      const covered=Array.from(data).filter((_,i)=>i%4===3).filter(a=>a>0).length/(side*side);
      expect(covered).toBeGreaterThan(.2);expect(covered).toBeLessThan(.6);
    }
  });
  const image = (scale: string, filename = `sprite-${scale}.png`) => ({ scale, filename, idiom: 'universal' });
  it('uses one common density and keeps one-density images', () => {
    expect(selectRendition({ images: [image('1x'), image('2x'), image('3x')] }, 'sprite')).toEqual({ filename: 'sprite-2x.png', density: 2 });
    expect(selectRendition({ images: [image('1x')] }, 'sprite').density).toBe(1);
    expect(selectRendition({ images: [{ filename: 'sprite.png', idiom: 'universal' }] }, 'sprite').density).toBe(1);
  });
  it('fails ambiguous, missing, per-device, and unsafe artwork', () => {
    for (const images of [[], [image('1x'), image('3x')], [image('2x'), image('2x')],
      [{ ...image('1x'), idiom: 'iphone' }], [image('1x', '../escape.png')]])
      expect(() => selectRendition({ images }, 'canonical')).toThrow();
  });
  it('discovers image sets instead of maintaining a parallel asset list', async () => {
    const dir = await scratch(); const set = join(dir, 'group', 'canonical.imageset');
    await mkdir(set, { recursive: true });
    await writeFile(join(set, 'Contents.json'), JSON.stringify({ images: [image('1x')] }));
    await mkdir(join(dir, 'AppIcon.appiconset'));
    expect(await catalogSources(dir)).toEqual([{ name: 'canonical', density: 1, file: join(set, 'sprite-1x.png') }]);
    await mkdir(join(dir, 'canonical.imageset'));
    await writeFile(join(dir, 'canonical.imageset/Contents.json'), JSON.stringify({ images: [image('1x')] }));
    await expect(catalogSources(dir)).rejects.toThrow('Duplicate');
  });
  it('deduplicates by bytes, preserves pixels and records source hashes', async () => {
    const dir = await scratch(); const file = join(dir, 'source.png'); const output = join(dir, 'output');
    const pixels = Buffer.from([255, 0, 0, 255, 0, 255, 0, 255]);
    await sharp(pixels, { raw: { width: 2, height: 1, channels: 4 } }).png().toFile(file);
    const before = await readFile(file);
    const first = await emitImage(file, output, dir, dir);
    const second = await emitImage(file, output, dir, dir);
    expect(first).toEqual(second); expect(await readdir(join(output, 'art'))).toHaveLength(1);
    expect(await sharp(join(output, first.url)).ensureAlpha().raw().toBuffer()).toEqual(pixels);
    expect(await readFile(file)).toEqual(before); expect(first.sourceSha256).toBe(sha256(before));
    expect((await readFile(join(output, first.url))).length).toBeLessThanOrEqual(before.length);
    await expect(emitImage(join(dir, 'missing.png'), output, dir, dir)).rejects.toThrow();
  });
});

describe('portable ZIP', () => {
  async function bundle() {
    const dir = await scratch(); const output = join(dir, 'bundle');
    await mkdir(join(output, 'content'), { recursive: true });
    await mkdir(join(output, 'art')); const data = new Uint8Array([1,2,3]);
    const manifest: Manifest = { version: 1, name: 'Fixture', database: 'content/seed.sqlite', maps: {}, images: {
      a: { url: 'art/a.png', width: 1, height: 1, density: 1, source: 'fixture', sha256: sha256(data), sourceSha256: sha256(data) },
    } };
    for (const [name, bytes] of Object.entries({ 'index.html': '<html></html>', 'content/manifest.json': JSON.stringify(manifest),
      'content/presentation.json': JSON.stringify(await presentation()), 'content/navigation.json': '{}',
      'content/seed.sqlite': data, 'art/a.png': data })) await writeFile(join(output, name), bytes);
    return { dir, output, destination: join(dir, 'releases/game.zip') };
  }
  it('places entry HTML at root, includes assets, and produces repeatable bytes', async () => {
    const { output, destination } = await bundle();
    await packageDirectory(output, destination);
    const one = await readFile(destination);
    expect(Object.keys(unzipSync(one)).sort()).toEqual(['art/a.png', 'content/manifest.json', 'content/navigation.json', 'content/presentation.json', 'content/seed.sqlite', 'index.html']);
    await packageDirectory(output, destination); expect(await readFile(destination)).toEqual(one);
  }, 90000); // The first bundle compiles the actual native presentation exporter.
  it('rejects missing assets and symlinks', async () => {
    const { output, destination } = await bundle();
    await rm(join(output, 'art/a.png'));
    await expect(packageDirectory(output, destination)).rejects.toThrow('Missing or corrupt');
    await symlink(join(output, 'index.html'), join(output, 'link.html'));
    await expect(packageDirectory(output, destination)).rejects.toThrow('symlinks');
  });
  it('rejects omitted or malformed native presentation/navigation exports', async () => {
    const { output, destination } = await bundle();
    await rm(join(output, 'content/presentation.json'));
    await expect(packageDirectory(output, destination)).rejects.toThrow('presentation.json');
    await writeFile(join(output, 'content/presentation.json'), '{}');
    await expect(packageDirectory(output, destination)).rejects.toThrow();
    await writeFile(join(output, 'content/presentation.json'), JSON.stringify(await presentation()));
    const file = join(output, 'content/manifest.json'), manifest = JSON.parse(await readFile(file, 'utf8')) as Manifest;
    manifest.maps.fixture = { geometry: 'content/map.geojson', underlay: ['a'], occlusion: [] };
    await writeFile(file, JSON.stringify(manifest)); await writeFile(join(output, 'content/map.geojson'), '{}');
    await expect(packageDirectory(output, destination)).rejects.toThrow('Missing ZIP navigation: fixture');
  });
});

describe('shared build configuration', () => {
  it('reads the existing title authority and refuses missing/ambiguous values', () => {
    expect(displayName('// comment\nGAME_DISPLAY_NAME = Original Title\n')).toBe('Original Title');
    expect(() => displayName('')).toThrow('GAME_DISPLAY_NAME');
    expect(() => displayName('GAME_DISPLAY_NAME = A\nGAME_DISPLAY_NAME = B')).toThrow();
  });
  it('uses relative URLs and adds the external SDK/config only to Facebook', () => {
    for (const target of ['website', 'facebook']) {
      const config = webConfig(target);
      expect(config.base).toBe('./'); expect(config.define!.__PLATFORM__).toBe(JSON.stringify(target));
      const plugin = (config.plugins as Plugin[])[0]!;
      const html = plugin.transformIndexHtml;
      if (typeof html !== 'function' || typeof plugin.generateBundle !== 'function') throw new Error('Missing build hooks');
      const tags = html('', {} as never);
      expect(tags).toEqual(target === 'facebook' ? [expect.objectContaining({ attrs: { src: 'https://connect.facebook.net/en_US/fbinstant.8.0.js' } })] : []);
      const emitFile = vi.fn(); plugin.generateBundle.call({ emitFile } as never, {} as never, {}, false);
      expect(emitFile).toHaveBeenCalledTimes(target === 'facebook' ? 1 : 0);
    }
    expect(() => webConfig('typo')).toThrow();
  });
});
