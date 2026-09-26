import type { Canvas, Level } from '../content/database';
import type { Slot } from '../content/geometry';
import { requireImage, type Manifest } from '../content/schema';
import { projection, type Insets } from './projection';

export type Battlefield = { canvas: Canvas; level: Level; manifest: Manifest; slots: Slot[] };
export type Placement = { key: string; x: number; y: number; width: number; height: number; origin: 0 | 0.5; depth: number };

// A renderer-independent display plan keeps all positioning testable without a
// GPU. Phaser only loads textures and renders this plan.
export function battlefieldPlan(battle: Battlefield, width: number, height: number, insets?: Insets): Placement[] {
  const map = battle.manifest.maps[battle.level.map_image_name];
  if (!map) throw new Error(`level_info[${battle.level.id}].map_image_name: missing map ${battle.level.map_image_name}`);
  const view = projection(battle.canvas, width, height, insets);
  const layer = (key: string, depth: number): Placement => {
    requireImage(battle.manifest, key);
    return { key, ...view.image, depth, origin: 0 };
  };
  const asset = requireImage(battle.manifest, 'tower_slot_available');
  const slotScale = Math.min(battle.canvas.slot_width / asset.width, battle.canvas.slot_height / asset.height) * view.scale;
  return [
    ...map.underlay.map((key, i) => layer(key, i)),
    ...battle.slots.map(slot => ({ key: 'tower_slot_available', ...view.point(slot.x, slot.y),
      width: asset.width * slotScale, height: asset.height * slotScale, origin: 0.5 as const, depth: 10 })),
    ...map.occlusion.map((key, i) => layer(key, 20 + i)),
  ];
}
