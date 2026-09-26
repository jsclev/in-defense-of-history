import { z } from 'zod';

export const positive = z.number().finite().positive();
const localPath = z.string().regex(/^(?:[a-zA-Z0-9_-]+\/)*[a-zA-Z0-9_.-]+$/)
  .refine(value => !value.split('/').some(part => part === '.' || part === '..'), 'Unsafe bundle path');
export const imageSchema = z.object({
  url: localPath, width: positive.int(), height: positive.int(),
  sha256: z.string().regex(/^[a-f0-9]{64}$/), source: z.string().min(1),
  sourceSha256: z.string().regex(/^[a-f0-9]{64}$/), density: z.union([z.literal(1), z.literal(2), z.literal(3)]),
});
export const manifestSchema = z.object({
  version: z.literal(1), name: z.string().trim().min(1), database: localPath,
  images: z.record(z.string(), imageSchema),
  maps: z.record(z.string(), z.object({ geometry: localPath, underlay: z.array(z.string()).min(1), occlusion: z.array(z.string()) })),
});
export type Manifest = z.infer<typeof manifestSchema>;
export type ImageAsset = z.infer<typeof imageSchema>;

export function contentError(record: string, error: unknown): Error {
  return new Error(`Content ${record}: ${error instanceof Error ? error.message : String(error)}`);
}

export function requireImage(manifest: Manifest, name: string): ImageAsset {
  const asset = manifest.images[name];
  if (!asset) throw contentError(`images[${name}]`, 'required image is missing');
  return asset;
}
