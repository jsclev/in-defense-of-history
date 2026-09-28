import type { Canvas, Level } from '../content/database';
import type { Slot } from '../content/geometry';
import { requireImage, type Manifest } from '../content/schema';
import { projection, type Insets } from './projection';

export type Battlefield = { canvas: Canvas; level: Level; manifest: Manifest; slots: Slot[] };
export type Placement = { key: string; x: number; y: number; width: number; height: number; origin: 0 | 0.5; depth: number };

// A renderer-independent display plan keeps all positioning testable without a
// GPU. Phaser only loads textures and renders this plan.
export function battlefieldPlan(battle: Battlefield, width: number, height: number, insets?: Insets, occupied = new Set<number>()): Placement[] {
  const map = battle.manifest.maps[battle.level.map_image_name];
  if (!map) throw new Error(`level_info[${battle.level.id}].map_image_name: missing map ${battle.level.map_image_name}`);
  const view = projection(battle.canvas, width, height, insets);
  const layer = (key: string, depth: number): Placement => {
    requireImage(battle.manifest, key);
    return { key, ...view.image, depth, origin: 0 };
  };
  return [
    ...map.underlay.map((key, i) => layer(key, i)),
    ...battle.slots.map(slot => {
      const key = occupied.has(slot.index) ? 'tower_slot_field' : 'tower_slot_available', image = requireImage(battle.manifest, key);
      const scale = Math.min(battle.canvas.slot_width / image.width, battle.canvas.slot_height / image.height) * view.scale;
      return { key, ...view.point(slot.x, slot.y), width: image.width * scale, height: image.height * scale, origin: 0.5 as const, depth: 10 };
    }),
    ...map.occlusion.map((key, i) => layer(key, 20 + i)),
  ];
}
