import { z } from 'zod';
import { contentError } from './schema';

const point = z.tuple([z.number().finite(), z.number().finite()]);
const collection = z.object({ type: z.literal('FeatureCollection'), features: z.array(z.object({
  id: z.string().optional(),
  properties: z.object({ kind: z.string() }).passthrough(), geometry: z.unknown(),
})) });
const slot = z.object({ properties: z.object({ slotIndex: z.number().int().nonnegative() }),
  geometry: z.object({ type: z.literal('Point'), coordinates: point }),
});
export type Slot = { index: number; x: number; y: number };
export type WaveMarker = { x: number; y: number; pathIndices: number[] | null };
const waveMarker = z.object({
  properties: z.object({ pathIndices: z.array(z.number().int().nonnegative()).nonempty()
    .refine(paths => new Set(paths).size === paths.length).nullish() }),
  geometry: z.object({ type: z.literal('Point'), coordinates: point }),
});
// LevelGeoJSONDAO / CallWaveButtonPosition: absent routes mean a level-wide marker.
export function readWaveMarkers(value: unknown, mapName: string): WaveMarker[] {
  try {
    const markers = collection.parse(value).features.filter(f => f.properties.kind === 'call_wave_button').map(f => waveMarker.parse(f));
    if (!markers.length) throw new Error('Missing required call_wave_button');
    return markers.map(f => ({ x: f.geometry.coordinates[0], y: f.geometry.coordinates[1], pathIndices: f.properties.pathIndices ?? null }));
  } catch (error) { throw contentError(`${mapName}.geojson call_wave_button`, error); }
}
export function visibleWaveMarkers(markers: WaveMarker[], paths: number[]): WaveMarker[] {
  const seen = new Set<string>();
  return markers.filter(marker => {
    const key = `${marker.x}:${marker.y}`;
    if (marker.pathIndices !== null && !marker.pathIndices.some(path => paths.includes(path)) || seen.has(key)) return false;
    seen.add(key); return true;
  });
}
export function readSlots(value: unknown, mapName: string): Slot[] {
  try {
    const slots = collection.parse(value).features.filter(f => f.properties.kind === 'tower_slot')
      .map(f => slot.parse(f)).map(f => ({ index: f.properties.slotIndex, x: f.geometry.coordinates[0], y: f.geometry.coordinates[1] }))
      .sort((a, b) => a.index - b.index);
    if (!slots.length || slots.some((s, i) => s.index !== i)) throw new Error('tower_slot.slotIndex must be contiguous from zero');
    return slots;
  } catch (error) { throw contentError(`${mapName}.geojson tower_slot`, error); }
}
export function readHeroSpawns(value: unknown, mapName: string): { x: number; y: number }[] {
  try {
    const count = z.object({ heroCount: z.number().int().min(0).max(2) }).parse(value).heroCount;
    const features = collection.parse(value).features;
    for (const feature of features) if (feature.properties.kind !== 'hero_spawn' &&
      feature.properties.heroRoles !== undefined && JSON.stringify(feature.properties.heroRoles) !== '[]')
      throw Error('Hero roles require hero_spawn points');
    const spawns = features.filter(f => f.properties.kind === 'hero_spawn').map(f => z.object({
      id: z.string().min(1), properties: z.object({ heroRoles: z.tuple([z.enum(['primary', 'secondary'])]) }),
      geometry: z.object({ type: z.literal('Point'), coordinates: point }),
    }).parse(f)).sort((a, b) => a.properties.heroRoles[0].localeCompare(b.properties.heroRoles[0]));
    if (spawns.length !== count || new Set(spawns.map(s => s.id)).size !== count ||
      spawns.some((s, i) => s.properties.heroRoles[0] !== ['primary', 'secondary'][i])) throw Error('heroCount requires matching unique primary/secondary starts');
    return spawns.map(s => ({ x: s.geometry.coordinates[0], y: s.geometry.coordinates[1] }));
  } catch (error) { throw contentError(`${mapName}.geojson hero_spawn`, error); }
}
// Explicit GeoJSON routes supersede legacy SQL paths; malformed exports never fall back.
export function readEnemyRoutes(value: unknown, mapName: string): { index: number; points: { x: number; y: number }[] }[] | null {
  try {
    const features = collection.parse(value).features;
    const routes = features.filter(f => f.properties.kind === 'enemy_route').map(f => z.object({
      properties: z.object({ category: z.literal('gameplay'), pathIndex: z.number().int().nonnegative(), name: z.string(), entranceID: z.string(), exitID: z.string() }),
      geometry: z.object({ type: z.literal('LineString'), coordinates: z.array(point).min(2) }),
    }).parse(f)).sort((a, b) => a.properties.pathIndex - b.properties.pathIndex);
    if (!routes.length) return null;
    return routes.map((r, index) => {
      if (r.properties.pathIndex !== index) throw Error('Enemy route indices must be contiguous');
      for (const [id, kind, expected] of [[r.properties.entranceID, 'spawn_point', r.geometry.coordinates[0]],
        [r.properties.exitID, 'goal_point', r.geometry.coordinates.at(-1)]] as const) {
        const matches = features.filter(f => f.id === id);
        if (matches.length !== 1 || matches[0]!.properties.kind !== kind ||
          JSON.stringify(z.object({ type: z.literal('Point'), coordinates: point }).parse(matches[0]!.geometry).coordinates) !== JSON.stringify(expected))
          throw Error(`Enemy route ${index} requires its authored ${kind}`);
      }
      return { index, points: r.geometry.coordinates.map(([x, y]) => ({ x, y })) };
    });
  } catch (error) { throw contentError(`${mapName}.geojson enemy_route`, error); }
}
