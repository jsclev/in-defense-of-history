import { afterAll, beforeAll, expect, it } from 'vitest';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { authored, battleSession, navigation, type Authored } from './fixtures';
import { MovementArea, Route, closest, distance, lerp, navigationSchema, swiftRound } from '../src/game/navigation';
import { compileNative } from '../tools/native';
import { native, project } from '../tools/paths';
import { WaveSchedule, ReinforcementSchedule } from '../src/game/schedules';
import type { Point } from '../src/hud/layout';
let fixture: Authored, temporary: string;
beforeAll(async () => { fixture = await authored(); temporary = await mkdtemp(join(tmpdir(), 'liberty-line-runtime-parity-')); });
afterAll(async () => { await rm(temporary, { recursive: true, force: true }); });
function close(actual: unknown, expected: unknown) {
  if (typeof expected === 'number') expect(actual).toBeCloseTo(expected, 7);
  else if (Array.isArray(expected)) { expect(actual).toHaveLength(expected.length); expected.forEach((e, i) => close((actual as unknown[])[i], e)); }
  else if (expected !== null && typeof expected === 'object') for (const key of Object.keys(expected)) close((actual as Record<string, unknown>)[key], (expected as Record<string, unknown>)[key]);
  else expect(actual).toEqual(expected);
}
it('matches native navigation boundaries/routes and native wave/reinforcement schedules', async () => {
  const db = fixture.open();
  try {
    const session = await battleSession(db), nav = await navigation(db), canvas = db.canvas();
    const names = ['level_01_battle_road', 'level_15_charleston'];
    const probes = names.map(name => {
      const area = new MovementArea(nav[name]!);
      const points = Array.from({ length: 200 }, (_, i) => ({ x: 400 + i % 20 * 100, y: 480 + Math.floor(i / 20) * 110 }));
      const inside = points.filter(p => area.contains(p));
      const pairs = inside.slice(0, 5).map((a, i) => ({ a, b: inside.at(-1 - i)! }));
      pairs.push({ a: { x: 0, y: 0 }, b: inside[0]! }, { a: inside[0]!, b: inside[0]! });
      return { file: join(native, 'Db', `${name}.geojson`), width: canvas.path_width, points, pairs };
    });
    const operations = [
      ['waveTap', 0, 1, -1], ['waveTap', 9999, 2, -1], ['waveTap', 10000, 2, -1],
      ['deploy', 10000, 0, -1], ['deploy', 10001, 0, -2], ['waveTap', 10002, 1, -1],
      ...Array.from({ length: 20 }, (_, i) => ['auto', 10003 + i * 150, 0, -1]),
      ['deploy', 15000, 0, -2], ['deploy', 15000, 0, -3], ['observe', 20000, 0, -1],
    ].map(([kind, tick, x, slot]) => ({ kind, tick, point: { x, y: 4 }, slot })) as { kind: string; tick: number; point: Point; slot: number }[];
    const config = session.content.config.reinforcement;
    const input = join(temporary, 'input.json'), executable = join(temporary, 'reference');
    await writeFile(input, JSON.stringify({ navigation: probes, waves: session.content.waves.map(w => ({ startTime: w.spawn_time, spawns: [],
      callButtonDelay: w.call_button_delay, autoStartCountdown: w.auto_start_countdown, earlyCallBonus: w.early_call_bonus })),
      reinforcement: { timeToLiveSeconds: config.time_to_live_seconds, cooldownSeconds: config.cooldown_seconds }, operations }));
    await compileNative(join(project, 'tests/game-reference.swift'), executable, ['Models/Core', 'Models/HeroMovementArea', 'Models/Wave',
      'Models/SpawnEntry', 'Models/WaveStartSchedule', 'Models/CallWaveButtonSelection', 'Models/ReinforcementSchedule', 'Models/ReinforcementConfig', 'Persistence/DbError']);
    const expected = JSON.parse((await promisify(execFile)(executable, [input])).stdout);
    probes.forEach((probe, i) => {
      const area = new MovementArea(nav[names[i]!]!);
      expect(probe.points.map(p => area.contains(p))).toEqual(expected.navigation[i].contains);
      expect(probe.pairs.map(p => area.segment(p.a, p.b))).toEqual(expected.navigation[i].segments);
      close(probe.pairs.map(p => area.route(p.a, p.b)), expected.navigation[i].routes);
    });
    const waves = new WaveSchedule(session.content.waves), reinforcements = new ReinforcementSchedule(config);
    const actual = operations.map(op => {
      const event: Record<string, unknown> = {};
      const start = op.kind === 'waveTap' ? waves.tap(op.point, op.tick) : op.kind === 'auto' ? waves.start(op.tick, false) : null;
      if (start) { event.wave = waves.next - 1; event.bonus = start.bonus; }
      if (op.kind === 'deploy') event.deployed = reinforcements.deploy(op.slot, op.tick);
      Object.assign(event, { expired: reinforcements.expire(op.tick), ...reinforcements.cooldown(op.tick), next: waves.next, canCall: waves.canCall(op.tick), kind: waves.state(op.tick).kind });
      if (waves.state(op.tick).seconds !== null) event.countdown = waves.state(op.tick).seconds;
      return event;
    });
    close(actual, expected.events);
  } finally { db.close(); }
}, 90000);
it('respects holes, boundary travel, disconnected ground and sub-grid passages without snapping destinations', () => {
  const outer = [[0,0],[100,0],[100,100],[0,100],[0,0]], hole = [[40,40],[60,40],[60,60],[40,60],[40,40]];
  const area = new MovementArea([outer, hole]);
  expect(area.contains({ x: NaN, y: 0 })).toBe(false);
  expect(area.contains({ x: 50, y: 50 })).toBe(false); expect(area.contains({ x: 40, y: 50 })).toBe(true);
  expect(area.segment({ x: 20, y: 50 }, { x: 80, y: 50 })).toBe(false);
  expect(area.segment({ x: 0, y: 0 }, { x: 100, y: 0 })).toBe(true);
  expect(area.segment({ x: 0, y: 0 }, { x: 0, y: 0 })).toBe(true);
  expect(area.nearest({ x: NaN, y: 0 })).toBeNull(); expect(area.nearest({ x: 50, y: 50 })).toEqual({ x: 50, y: 40 });
  expect(area.nearest({ x: 20, y: 20 })).toEqual({ x: 20, y: 20 });
  const road = new MovementArea([[[1,1],[101,1],[101,4],[4,4],[4,101],[1,101],[1,1]]]);
  const route = road.route({ x: 100, y: 2 }, { x: 2, y: 100 })!;
  expect(route.at(-1)).toEqual({ x: 2, y: 100 }); expect(route.length).toBeGreaterThan(1);
  expect(road.route({ x: 0, y: 0 }, { x: 2, y: 100 })).toBeNull();
  expect(new MovementArea([outer, outer.map(([x, y]) => [x! + 200, y!])]).route({ x: 10, y: 10 }, { x: 210, y: 10 })).toBeNull();
  expect(navigationSchema.safeParse({ bad: [[[0,0],[1,0],[1,1],[2,2]]] }).success).toBe(false);
  expect(new MovementArea([[[0,0],[0,0],[1,0],[1,1],[0,0]]]).contains({ x: .9, y: .1 })).toBe(true);
});
it('projects distance onto complete paths with endpoint clamps, repeated vertices and stable ties', () => {
  const route = new Route([{ x: 0, y: 0 }, { x: 0, y: 0 }, { x: 100, y: 0 }, { x: 100, y: 100 }]);
  expect(route.total).toBe(200); expect(route.point(-1)).toEqual({ x: 0, y: 0 }); expect(route.point(300)).toEqual({ x: 100, y: 100 });
  expect(route.point(150)).toEqual({ x: 100, y: 50 }); expect(route.nearest({ x: 50, y: 50 })).toEqual({ point: { x: 50, y: 0 }, along: 50, gap: 50 });
  expect(closest({ x: 1, y: 1 }, { x: 0, y: 0 }, { x: 0, y: 0 })).toEqual({ x: 0, y: 0 });
  expect(swiftRound(-.5)).toBe(-1); expect(distance(lerp({ x: 0, y: 0 }, { x: 6, y: 8 }, .5), { x: 0, y: 0 })).toBe(5);
  for (const points of [[], [{ x: NaN, y: 0 }, { x: 1, y: 0 }], [{ x: 1, y: 1 }, { x: 1, y: 1 }]]) expect(() => new Route(points)).toThrow();
});
