import { afterAll, beforeAll, expect, it } from 'vitest';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawn } from 'node:child_process';
import { authored, hudBattle, presentation } from './fixtures';
import { project } from '../tools/paths';
import { compileNative, layoutSources } from '../tools/native';
import { centered, labelPlacement, menuSeat, slotTarget } from '../src/hud/tower-layout';
import type { Presentation } from '../src/content/presentation';
import { buttonRow, corners, hudCanvas, location, statsLayout, waveLayout, type Canvas, type Corner, type Rect } from '../src/hud/layout';
import { inRegion, regionPath } from '../src/hud/regions';

let canvas: Canvas; let temporary: string;let nativePresentation:Presentation;
beforeAll(async () => { const battle=await hudBattle(await authored());canvas=battle.canvas;nativePresentation=battle.presentation; });
afterAll(async () => { if (temporary) await rm(temporary, { recursive: true, force: true }); });
const noInsets = { top: 0, right: 0, bottom: 0, left: 0 };
function close(actual: unknown, expected: unknown) {
  if (typeof expected === 'number') expect(actual).toBeCloseTo(expected, 8);
  else if (typeof expected === 'object' && expected !== null)
    for (const key of Object.keys(expected)) close((actual as Record<string, unknown>)[key], (expected as Record<string, unknown>)[key]);
  else expect(actual).toEqual(expected);
}
it('matches the actual Swift corner, button, wave and guide geometry across viewports and SQL changes', async () => {
  temporary = await mkdtemp(join(tmpdir(), 'liberty-line-hud-parity-'));
  const executable = join(temporary, 'reference');
  await compileNative(join(project, 'tests/hud-reference.swift'), executable, [...layoutSources,'Layout/TowerLabelPlacement']);
  const art=await presentation();
  const sizes = [
    { width: 360, height: 800, insets: noInsets },
    { width: 604.4444444444, height: 340, insets: noInsets },
    { width: 874, height: 402, insets: { top: 0, left: 62, right: 62, bottom: 20 } },
    { width: 1024, height: 768, insets: { top: 24, left: 0, right: 0, bottom: 20 } },
    { width: 1600, height: 900, insets: noInsets },
    { width: 2560, height: 1080, insets: { top: 7, left: 32, right: 0, bottom: 11 } },
  ];
  const scenarios = [canvas, { ...canvas, play_area_x: 411, play_area_y: 340, hero_bar_width_fraction: .31, stats_view_height_fraction: .24 }]
    .flatMap(canvas => sizes.map(size => ({ canvas, ...size, positions: [{ x: 1434, y: 1032 }, { x: 543.125, y: 789.875 }],
      points: Array.from({ length: 700 }, (_, i) => ({ x: (i % 35 + .413) * size.width / 35, y: (Math.floor(i / 35) + .387) * size.height / 20 })) })));
  const result = await new Promise<string>((resolve, reject) => {
    const child = spawn(executable); let output = '', error = '';
    child.stdout.on('data', data => { output += data; }); child.stderr.on('data', data => { error += data; });
    child.on('error', reject); child.on('close', code => code === 0 ? resolve(output) : reject(Error(error)));
    child.stdin.end(JSON.stringify(scenarios));
  });
  const references = JSON.parse(result) as { bounds: Rect; corners: Record<Corner, Rect>; rows: { corner: Corner; count: number; frame: Rect; side: number; gap: number }[]; waves: unknown[]; masks: boolean[][];
    menus:{center:{x:number;y:number};side:number;background:{width:number;height:number};target:Rect;buttons:Record<string,unknown>;seats:unknown[][];upgrades:unknown[][];labels:unknown[]}[] }[];
  scenarios.forEach((scenario, index) => {
    const view = hudCanvas(scenario.canvas, scenario.width, scenario.height,art.towerGeometry, scenario.insets), reference = references[index]!;
    close(view.bounds, reference.bounds); close(view.corners, reference.corners);
    reference.rows.forEach(row => close(buttonRow(view, row.corner, row.count), { frame: row.frame, side: row.side, gap: row.gap }));
    scenario.positions.forEach((p, i) => close(waveLayout(view, p), reference.waves[i]));
    [view.path, view.tap, view.slot].forEach((region, i) => expect(scenario.points.map(p => inRegion(region, p))).toEqual(reference.masks[i]));
    scenario.positions.forEach((p,i)=>{
      const m=reference.menus[i]!,g=art.towerGeometry,h=view.playArea.height,center=view.point(p.x,p.y);
      close(center,m.center);close(h*g.button,m.side);close({width:h*g.backgroundWidth,height:h*g.backgroundHeight},m.background);
      close(slotTarget(p,view,art,{width:scenario.canvas.slot_width,height:scenario.canvas.slot_height}),m.target);
      for(const [kind,native] of Object.entries(m.buttons)) {
        const offset=art.towers[kind as keyof typeof art.towers].buildCenter;
        close({x:center.x+offset.x*h,y:center.y+offset.y*h},native);
      }
      m.seats.forEach((seats,count)=>seats.forEach((p,i)=>close(menuSeat(i,count,center,h*g.seat),p)));
      m.upgrades.forEach((seats,index)=>seats.forEach((p,i)=>close(menuSeat(index===0?0:index===1?(i===0?3:1):[3,0,1][i]!,4,center,h*g.ring),p)));
      const anchor={...centered(center,m.side),height:m.side*1.15};
      [20,200,1000,6000].forEach((amount,j)=>close(labelPlacement(anchor,view.safeRect,Object.values(view.corners),width=>Math.ceil(amount/width)*24+56),m.labels[j]));
    });
  });
}, 90000);
it('fits every HUD section into each configured corner and keeps stats stable as values change', () => {
  const view = hudCanvas(canvas, 874, 402,nativePresentation.towerGeometry, { top: 0, left: 62, right: 62, bottom: 20 });
  for (const corner of corners) {
    for (const frame of [buttonRow(view, corner, 3).frame, buttonRow(view, corner, 2).frame, statsLayout(view, corner, 1.3, 1.1).frame]) {
      expect(frame.x + 1e-8).toBeGreaterThanOrEqual(view.corners[corner].x);
      expect(frame.y + 1e-8).toBeGreaterThanOrEqual(view.corners[corner].y);
      expect(frame.x + frame.width).toBeLessThanOrEqual(view.corners[corner].x + view.corners[corner].width + 1e-8);
      expect(frame.y + frame.height).toBeLessThanOrEqual(view.corners[corner].y + view.corners[corner].height + 1e-8);
    }
  }
  expect(() => buttonRow(view, 'north_west', 0)).toThrow('positive');
  expect(() => location([], 'hero_bar')).toThrow('hero_bar');
  const empty = hudCanvas({ ...canvas, hero_bar_width_fraction: 0, hero_bar_height_fraction: 0 }, 800, 450,nativePresentation.towerGeometry);
  expect(buttonRow(empty, 'south_west', 3).side).toBe(0);
});
it('uses the same minimum and maximum call-wave size independently of map scale', () => {
  for (const [height, side] of [[200, 44], [680.625, 70], [1080, 84]])
    expect(waveLayout(hudCanvas(canvas, height! * 16 / 9, height!,nativePresentation.towerGeometry), { x: 1434, y: 1032 }).frame.width).toBeCloseTo(side!);
});
it('subtracts overlapping, interior, exterior and completely covering cuts without stray edges', () => {
  const bounds = { x: 0, y: 0, width: 100, height: 100 };
  expect(regionPath({ bounds, cuts: [] })).toBe('M0,0L100,0L100,100L0,100L0,0Z');
  expect(regionPath({ bounds, cuts: [bounds] })).toBe('');
  expect(regionPath({ bounds: { ...bounds, width: 0 }, cuts: [] })).toBe('');
  const cut = { x: 20, y: 20, width: 60, height: 60 };
  expect(regionPath({ bounds, cuts: [cut] }).match(/M/g)).toHaveLength(2);
  const region = { bounds, cuts: [cut, { x: 40, y: -10, width: 60, height: 110 }] };
  expect(regionPath(region).match(/M/g)).toHaveLength(1);
  expect(inRegion(region, { x: 10, y: 50 })).toBe(true);
  expect(inRegion(region, { x: 30, y: 50 })).toBe(false);
  expect(inRegion(region, { x: 101, y: 50 })).toBe(false);
});
