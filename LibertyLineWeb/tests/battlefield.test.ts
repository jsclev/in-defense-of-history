import { beforeAll, expect, it } from 'vitest';
import { battlefieldPlan, type Battlefield } from '../src/game/battlefield';
import { readSlots } from '../src/content/geometry';
import { authored, geometry, testManifest } from './fixtures';
import { projection } from '../src/game/projection';

let battle: Battlefield;
beforeAll(async () => {
  const fixture = await authored(); const db = fixture.open();
  try {
    const level = db.levels().find(l => l.map_image_name)!;
    battle = { level, canvas: db.canvas(), manifest: testManifest(db), slots: readSlots(await geometry(level.map_image_name), level.map_image_name) };
  } finally { db.close(); }
});

it.each([[360, 800], [800, 360], [1024, 768], [768, 1024], [900, 900], [1920, 1080], [2560, 1080]])(
  'fits the authored 16:9 play area into the entire %i × %i viewport', (width, height) => {
    const { playArea, safeRect, scale, point, inverse } = projection(battle.canvas, width, height);
    expect(playArea.width / playArea.height).toBeCloseTo(16 / 9);
    expect(playArea.width).toBeLessThanOrEqual(width);
    expect(playArea.height).toBeLessThanOrEqual(height);
    expect(playArea.x + playArea.width / 2).toBeCloseTo(width / 2);
    expect(playArea.y + playArea.height / 2).toBeCloseTo(height / 2);
    expect(Math.min(width - playArea.width, height - playArea.height)).toBeCloseTo(0);
    expect(safeRect).toEqual({ x: 0, y: 0, width, height });
    const plan = battlefieldPlan(battle, width, height);
    const art = plan[0]!;
    // Rendering, map input and SQL geometry all share one transform.
    battle.slots.forEach((slot, index) => {
      const sprite = plan[index + 1]!;
      expect(sprite.x).toBeCloseTo(art.x + slot.x * scale);
      expect(sprite.y).toBeCloseTo(art.y + (battle.canvas.canvas_height - slot.y) * scale);
      const screen = point(slot.x, slot.y);
      expect(inverse(screen.x, screen.y).x).toBeCloseTo(slot.x);
      expect(inverse(screen.x, screen.y).y).toBeCloseTo(slot.y);
    });
  });

it('keeps map art registered and slot placement proportional at phone and desktop sizes', () => {
  const small = battlefieldPlan(battle, 640, 360);
  const large = battlefieldPlan(battle, 1280, 720);
  expect(small.length).toBe(battle.slots.length + 1);
  expect(small[0]!.depth).toBeLessThan(small[1]!.depth);
  small.forEach((p, i) => {
    expect(large[i]!.width).toBeCloseTo(p.width * 2);
    expect(large[i]!.x).toBeCloseTo(p.x * 2);
    expect(large[i]!.y).toBeCloseTo(p.y * 2);
  });
});
it('puts authored occlusion above slots and fails missing art', () => {
  const modified = structuredClone(battle);
  modified.manifest.maps[modified.level.map_image_name]!.occlusion.push(modified.level.map_image_name);
  const plan = battlefieldPlan(modified, 640, 360);
  expect(plan.at(-1)!.depth).toBeGreaterThan(plan[1]!.depth);
  expect(plan.at(-1)!.width).toBe(plan[0]!.width);
  delete modified.manifest.images.tower_slot_available;
  expect(() => battlefieldPlan(modified, 640, 360)).toThrow('tower_slot_available');
  delete modified.manifest.maps[modified.level.map_image_name];
  expect(() => battlefieldPlan(modified, 640, 360)).toThrow(modified.level.id);
});
