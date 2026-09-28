import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import sharp from 'sharp';

// One authored portrait, sampled at browser-tab densities without changing its crop.
export async function emitFavicons(source: string, output: string): Promise<void> {
  const image = sharp(source);
  const metadata = await image.metadata();
  if (!metadata.width || metadata.width !== metadata.height || metadata.width < 48)
    throw new Error('Favicon source must be square and at least 48 pixels');
  await mkdir(output, { recursive: true });
  const sizes = [16, 32, 48];
  const frames: Buffer[] = [];
  const directory = Buffer.alloc(6 + sizes.length * 16);
  directory.writeUInt16LE(1, 2); // ICO image type
  directory.writeUInt16LE(sizes.length, 4);
  let offset = directory.length;
  for (const [index, size] of sizes.entries()) {
    const png = await image.clone().resize(size, size).ensureAlpha().png().toBuffer();
    await writeFile(join(output, `favicon-${size}.png`), png);
    const entry = 6 + index * 16;
    directory[entry] = size;
    directory[entry + 1] = size;
    directory.writeUInt16LE(1, entry + 4);
    directory.writeUInt16LE(32, entry + 6);
    directory.writeUInt32LE(png.length, entry + 8);
    directory.writeUInt32LE(offset, entry + 12);
    frames.push(png);
    offset += png.length;
  }
  await writeFile(join(output, 'favicon.ico'), Buffer.concat([directory, ...frames]));
}
