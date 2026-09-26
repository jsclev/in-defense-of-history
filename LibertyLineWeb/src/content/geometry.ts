import { z } from 'zod';
import { contentError } from './schema';

const point = z.tuple([z.number().finite(), z.number().finite()]);
const collection = z.object({ type: z.literal('FeatureCollection'), features: z.array(z.object({
  properties: z.object({ kind: z.string() }).passthrough(), geometry: z.unknown(),
})) });
const slot = z.object({ properties: z.object({ slotIndex: z.number().int().nonnegative() }),
  geometry: z.object({ type: z.literal('Point'), coordinates: point }),
});
export type Slot = { index: number; x: number; y: number };
export function readSlots(value: unknown, mapName: string): Slot[] {
  try {
    const slots = collection.parse(value).features.filter(f => f.properties.kind === 'tower_slot')
      .map(f => slot.parse(f)).map(f => ({ index: f.properties.slotIndex, x: f.geometry.coordinates[0], y: f.geometry.coordinates[1] }))
      .sort((a, b) => a.index - b.index);
    if (!slots.length || slots.some((s, i) => s.index !== i)) throw new Error('tower_slot.slotIndex must be contiguous from zero');
    return slots;
  } catch (error) { throw contentError(`${mapName}.geojson tower_slot`, error); }
}
