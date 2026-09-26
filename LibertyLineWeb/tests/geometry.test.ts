import { describe, expect, it } from 'vitest';
import { readSlots } from '../src/content/geometry';
import { projection } from '../src/game/projection';
import { manifestSchema, requireImage } from '../src/content/schema';

const canvas = { canvas_width: 3000, canvas_height: 2200, play_area_x: 300, play_area_y: 500,
  play_area_width: 1800, play_area_height: 1000, slot_width: 170, slot_height: 100 };
const slot = (index: number, xy = [100, 200]) => ({ properties: { kind: 'tower_slot', slotIndex: index }, geometry: { type: 'Point', coordinates: xy } });

describe('map projection', () => {
  it('flips Y exactly once and centers an off-center play area', () => {
    const view = projection(canvas, 900, 500);
    expect(view.point(300, 1500)).toEqual({ x: 0, y: 0 });
    expect(view.point(2100, 500)).toEqual({ x: 900, y: 500 });
    expect(view.image).toEqual({ x: -150, y: -350, width: 1500, height: 1100 });
    expect(view.inverse(...Object.values(view.point(812, 920)) as [number, number])).toEqual({ x: 812, y: 920 });
  });
  it('letterboxes without distorting and refuses invalid dimensions', () => {
    const view = projection(canvas, 1200, 500);
    expect(view.scale).toBe(0.5); expect(view.point(300, 1500).x).toBe(150);
    expect(() => projection(canvas, 0, 50)).toThrow();
    expect(() => projection(canvas, Infinity, 50)).toThrow();
  });
  it('centers in asymmetric safe bounds and keeps artwork outside the play rectangle', () => {
    const view = projection(canvas, 1100, 600, { left: 120, right: 80, top: 20, bottom: 80 });
    expect(view.physicalRect).toEqual({ x: 0, y: 0, width: 1100, height: 600 });
    expect(view.safeRect).toEqual({ x: 120, y: 20, width: 900, height: 500 });
    expect(view.playArea).toEqual(view.safeRect);
    expect(view.point(300, 1500)).toEqual({ x: 120, y: 20 });
    expect(view.point(2100, 500)).toEqual({ x: 1020, y: 520 });
    expect(view.inverse(120, 20)).toEqual({ x: 300, y: 1500 });
    expect(view.image).toEqual({ x: -30, y: -330, width: 1500, height: 1100 });
  });
  it.each([
    { top: -1, right: 0, bottom: 0, left: 0 },
    { top: 0, right: NaN, bottom: 0, left: 0 },
    { top: 0, right: 0, bottom: Infinity, left: 0 },
    { top: 0, right: 100, bottom: 0, left: 0 },
    { top: 50, right: 0, bottom: 50, left: 0 },
  ])('rejects invalid safe bounds %#', insets => {
    expect(() => projection(canvas, 100, 100, insets)).toThrow('Invalid viewport safe insets');
  });
});
describe('GeoJSON', () => {
  it('uses explicit slot indices rather than feature order', () => {
    expect(readSlots({ type: 'FeatureCollection', features: [slot(1), slot(0)] }, 'example').map(s => s.index)).toEqual([0,1]);
  });
  it.each([[], [slot(1)], [slot(0), slot(0)], [slot(0, [NaN, 0])], [slot(0, [1,2,3])]].map(features => ({ features })))('fails invalid slots %#', ({ features }) => {
    expect(() => readSlots({ type: 'FeatureCollection', features }, 'bad-map')).toThrow('bad-map.geojson tower_slot');
  });
});
describe('asset contract', () => {
  it('does not accept remote or traversing paths', () => {
    for (const database of ['../db', 'https://example.com/db', '/db', 'content/../db'])
      expect(() => manifestSchema.parse({ version: 1, name: 'Test', database, images: {}, maps: {} })).toThrow();
  });
  it('fails a missing image by its canonical name', () => {
    expect(() => requireImage({ version: 1, name: 'Test', database: 'db', images: {}, maps: {} }, 'missing')).toThrow('images[missing]');
  });
});
