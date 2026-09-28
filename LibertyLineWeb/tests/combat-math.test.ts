import { beforeAll, expect, it } from 'vitest';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { authored, battleSession, type Authored } from './fixtures';
import { native } from '../tools/paths';
import { clampAim, EnemyMorale, exitsBlast, hitFraction, moraleLoss, radians, rayRange, selectTarget, track, wrapped } from '../src/game/combat-math';
import { Route } from '../src/game/navigation';
import type { BattleSession } from '../src/game/session';
import type { Enemy } from '../src/game/units';
let fixture: Authored, session: BattleSession;
beforeAll(async () => { fixture = await authored(); const db = fixture.open(); try { session = await battleSession(db); } finally { db.close(); } });
function close(actual: unknown, expected: unknown) {
  if (typeof expected === 'number') expect(actual).toBeCloseTo(expected, 9);
  else if (Array.isArray(expected)) { expect(actual).toHaveLength(expected.length); expected.forEach((e, i) => close((actual as unknown[])[i], e)); }
  else if (expected !== null && typeof expected === 'object') for (const [key, value] of Object.entries(expected)) {
    const received = (actual as Record<string, unknown>)[key];
    // atan2 may choose either signed representation of the same west bearing.
    if (key === 'heading') expect(wrapped(Number(received) - Number(value))).toBeCloseTo(0, 9);
    else close(received, value);
  }
  else expect(actual).toEqual(expected);
}
it('matches the original Swift aiming, swept collision, blast exit, morale loss and recovery calculations', async () => {
  const temporary = await mkdtemp(join(tmpdir(), 'liberty-line-combat-parity-'));
  try {
    const rules = session.content.config.combat, tuning = session.towers.base('areaOfEffect'), enemy = session.content.enemies[0]!;
    const camel = (record: object) => Object.fromEntries(Object.entries(record).map(([k, v]) => [k.replace(/_([a-z])/g, (_, c: string) => c.toUpperCase()).replace(/Hp/g, 'HP'), v]));
    const response = { speedThreshold: enemy.morale_speed_threshold, attackThreshold: enemy.morale_attack_threshold,
      speedMultiplier: enemy.morale_speed_multiplier, attackMultiplier: enemy.morale_attack_multiplier };
    const nativeTuning = { ...camel(tuning), combatRules: camel(rules), range: tuning.tower_range,
      demolitionPreparationSeconds: null, engineerObstacles: null, meleeUnit: null,
      support: { incomePerWave: tuning.income_per_wave, attackSpeedMultiplier: tuning.support_attack_speed_multiplier, healPerSecond: tuning.support_heal_per_second }, upgradePaths: [] };
    const route = new Route([{ x: -100, y: -rules.enemy_body_offset_y }, { x: 200, y: 200 }, { x: -100, y: 0 }, { x: 100, y: 0 }]);
    const probes = Array.from({ length: 90 }, (_, i) => ({ origin: { x: 0, y: 0 }, target: { x: (i % 11 - 5) * 15, y: (i % 13 - 6) * 17 },
      end: { x: i % 3 === 0 ? 0 : 100, y: 0 }, heading: (i - 45) * .29, rate: i % 4 * .9, seconds: i % 10 === 0 ? -1 : i % 7 / 4,
      radius: i % 5 * 35, vertical: rules.range_vertical_fraction, along: i * 9, travel: i % 17 * 26,
      loss: i % 9 === 0 ? 20 : 0, discipline: i % 7 / 5, blocked: i % 4 === 0 }));
    const source = join(temporary, 'input.json'), output = join(temporary, 'output.json');
    await writeFile(source, JSON.stringify({ tuning: nativeTuning, response, path: route.points, probes }));
    const run = await promisify(execFile)('swift', ['test', '--scratch-path', join(temporary, 'build'), '--filter', 'WebCombatReferenceTests/testExport'], {
      cwd: native, env: { ...process.env, LIBERTY_LINE_WEB_COMBAT_INPUT: source, LIBERTY_LINE_WEB_COMBAT_OUTPUT: output }, maxBuffer: 16 * 1024 * 1024 });
    await writeFile(join(temporary, 'swift.log'), run.stdout + run.stderr);
    const morale = new EnemyMorale(rules);
    const actual = probes.map(p => {
      const aim = track(wrapped(p.heading), p.origin, p.target, p.rate, p.seconds, radians(rules.firing_tolerance_degrees));
      const applied = morale.apply(p.loss, p.target.x - p.origin.x), travel = morale.advance(p.seconds, 80, enemy, p.blocked);
      return { ...aim, clamped: clampAim(p.target, p.origin, p.radius, p.vertical), range: rayRange(p.radius, p.vertical, p.heading),
        hit: hitFraction(p.origin, p.end, p.target, rules.grapeshot_hit_radius), exits: exitsBlast(route, p.along, p.travel, p.origin, p.radius, { x: rules.enemy_body_offset_x, y: rules.enemy_body_offset_y }),
        loss: moraleLoss(tuning, p.travel, p.discipline), applied, value: morale.value, displayed: morale.displayed, fraction: morale.fraction,
        displayedFraction: morale.displayedFraction, visible: morale.visible, direction: morale.direction, travel, attack: morale.attackMultiplier(enemy) };
    });
    close(actual, JSON.parse(await readFile(output, 'utf8')));
  } finally { await rm(temporary, { recursive: true, force: true }); }
}, 240000);
it('respects target priorities across different path lengths and preserves array order on ties', () => {
  const origin = { x: 0, y: 0 }, tuning = structuredClone(session.towers.base('ranged')), type = session.content.enemies[0]!;
  const paths = [new Route([origin, { x: 100, y: 0 }]), new Route([origin, { x: 200, y: 0 }])];
  const enemies: Enemy[] = [0, 1, 2].map(id => ({ id, type, path: id % 2, along: id === 1 ? 150 : 20, position: origin, previous: origin,
    spawnTick: 0, hp: id === 2 ? 200 : 100, maximumHP: 200, morale: new EnemyMorale(session.content.config.combat) }));
  enemies[2]!.morale.apply(20, -1);
  for (const [targeting, id] of [['first', 1], ['last', 0], ['strongest', 2], ['shakiest', 2]] as const) {
    tuning.targeting = targeting; expect(selectTarget(enemies, paths, origin, tuning, .5)!.id).toBe(id);
  }
  tuning.targeting = 'first'; enemies[1]!.hp = 0; expect(selectTarget(enemies, paths, origin, tuning, .5)!.id).toBe(0);
  tuning.tower_range = 0; expect(selectTarget(enemies, paths, origin, tuning, .5)).toBeUndefined();
});
it('handles degenerate geometry, nonfinite inputs, delayed recovery and recovery threshold crossings', () => {
  const o = { x: 0, y: 0 }, rules = session.content.config.combat, tuning = session.towers.base('areaOfEffect');
  expect(track(1, o, o, 1, 1, .1)).toEqual({ heading: 1, aligned: false });
  expect(track(1, o, { x: 1, y: 0 }, -1, 1, .1).aligned).toBe(false);
  expect(clampAim({ x: NaN, y: 0 }, o, 30, .5)).toEqual(o); expect(rayRange(10, .5, Infinity)).toBe(0);
  expect(hitFraction(o, o, o, 1)).toBe(0); expect(moraleLoss(tuning, -1, 0)).toBe(0); expect(moraleLoss({ ...tuning, aoe_radius: 0 }, 100, 0)).toBe(tuning.terror_max);
  const morale = new EnemyMorale(rules), type = { ...session.content.enemies[0]!, morale_speed_threshold: .5, morale_speed_multiplier: .4 };
  expect(morale.apply(NaN, 1)).toBe(false); expect(morale.advance(NaN, 10, type, false)).toBe(0);
  morale.apply(rules.morale_max, -1); expect(morale.apply(1, 1)).toBe(false);
  const seconds = rules.morale_recovery_delay + rules.morale_max / rules.base_morale_regen_per_second;
  const slowed = rules.morale_recovery_delay + rules.morale_max * .5 / rules.base_morale_regen_per_second;
  expect(morale.advance(seconds, 10, type, false, false)).toBeCloseTo(10 * (slowed * .4 + seconds - slowed));
  expect(morale.value).toBe(0); morale.advance(seconds, 10, type, true); expect(morale.value).toBe(rules.morale_max);
  expect(morale.advance(1, 10, { ...type, morale_speed_threshold: 1 }, false)).toBeCloseTo(4);
  const route = new Route([o, { x: 100, y: 0 }, o]);
  expect(exitsBlast(route, 0, 200, o, 30, o)).toBe(true); expect(exitsBlast(route, 199, 1, o, 30, o)).toBe(true);
  expect(exitsBlast(route, 0, 1, o, 30, o)).toBe(false); expect(exitsBlast(route, 0, 1, o, NaN, o)).toBe(false);
});
