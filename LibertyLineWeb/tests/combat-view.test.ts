import { beforeAll, expect, it } from 'vitest';
import { authored, battleSession, testManifest } from './fixtures';
import type { BattleSession } from '../src/game/session';
import type { Manifest } from '../src/content/schema';
import { hudCanvas } from '../src/hud/layout';
import { resolveHeight } from '../src/content/presentation';
import { projectilePlan, impactPlan, moralePlan } from '../src/game/combat-view';
import { EnemyMorale, radians } from '../src/game/combat-math';
import type { Projectile } from '../src/game/combat';
let session: BattleSession, art: Manifest;
beforeAll(async () => { const db = (await authored()).open(); try { session = await battleSession(db); art = testManifest(db, session.presentation); } finally { db.close(); } });
const view = (width = 800, height = 450) => hudCanvas(session.content.config.canvas, width, height, session.presentation.towerGeometry);
it('projects canonical shots with native height clamps, interpolation, rotation and pellet scale', () => {
  const p: Projectile = { id: 1, slot: 0, kind: 'areaOfEffect', tuning: session.towers.base('areaOfEffect'), position: { x: 200, y: 100 },
    previous: { x: 100, y: 50 }, origin: { x: 100, y: 50 }, heading: .5, target: 1, damage: 10, impact: null, remaining: 100, volley: 1, hits: new Set() };
  for (const [w, h] of [[605, 340], [800, 450], [390, 844], [1920, 1080]]) {
    const canvas = view(w, h), plan = projectilePlan(p, .5, canvas, art, session.presentation);
    expect(plan.x).toBe(canvas.point(150, 75).x); expect(plan.y).toBe(canvas.point(150, 75).y);
    expect(plan.height).toBe(resolveHeight(session.presentation.towers.areaOfEffect.projectile.height, canvas.playArea.height));
    expect(plan.key).toBe(session.presentation.towers.areaOfEffect.projectile.asset); expect(plan.rotation).toBe(.5);
    const pellet = projectilePlan({ ...p, tuning: { ...p.tuning, attack_mode: 'grapeshot' } }, .5, canvas, art, session.presentation);
    expect(pellet.height).toBe(plan.height * .45);
  }
  expect(() => projectilePlan({ ...p, kind: 'supply' }, 1, view(), art, session.presentation)).toThrow('Missing projectile art');
});
it('uses game-time burst expansion, native explosion timing/blending and ground anchoring', () => {
  const canvas = view(), impact = { id: 1, position: { x: 200, y: 200 }, radius: 100, age: .39, demolition: false };
  const ring = impactPlan(impact, canvas, session.presentation, false);
  expect(ring.shapes).toHaveLength(8); expect(ring.shapes[0]!.width).toBeCloseTo(2 * 100 * canvas.scale * (1 - .5 ** 3));
  expect(ring.shapes[0]!.alpha).toBe(.5); expect(impactPlan(impact, canvas, session.presentation, true).shapes).toHaveLength(0);
  expect(impactPlan({ ...impact, age: .78 }, canvas, session.presentation, false).shapes).toHaveLength(0);
  const explosion = { ...impact, demolition: true, age: .075 }, plan = impactPlan(explosion, canvas, session.presentation, false);
  expect(plan.frames[0]!.frame).toBe('1'); expect(plan.frames[1]!.frame).toBe('2');
  expect(plan.frames[0]!.alpha + plan.frames[1]!.alpha).toBe(1); expect(plan.shapes).toHaveLength(3);
  expect(plan.y).toBeCloseTo(canvas.point(200, 200).y + (.5 - session.presentation.explosion.anchor) * plan.side);
  for (const age of [.01, .2, .3, .5, .8, 1.29]) {
    const p = impactPlan({ ...explosion, age }, canvas, session.presentation, false);
    expect(p.frames.reduce((sum, f) => sum + f.alpha, 0)).toBeLessThanOrEqual(1);
    expect(p.frames.every(f => Number(f.frame) < 12)).toBe(true);
  }
  expect(impactPlan({ ...explosion, age: 1.3 }, canvas, session.presentation, false).frames).toHaveLength(0);
  expect(impactPlan({ ...explosion, age: -.1 }, canvas, session.presentation, false).frames).toHaveLength(0);
  expect(impactPlan(explosion, canvas, session.presentation, true).frames).toEqual([{ frame: '7', alpha: .5 * (1 - .075 / 1.3) }]);
});
it('keeps morale as one continuous remaining-value arc, with native flinch and reduced-motion behavior', () => {
  const morale = new EnemyMorale(session.content.config.combat), foot = { x: 100, y: 200 }, height = session.presentation.walker.minimum;
  expect(moralePlan(morale, foot, height, session.presentation, false).visible).toBe(false);
  morale.apply(morale.rules.morale_max / 2, -1); morale.age = .165;
  const p = moralePlan(morale, foot, height, session.presentation, false);
  expect(p.visible).toBe(true); expect(p.dx).toBe(-2); expect(p.dy).toBe(1); expect(p.rotation).toBeCloseTo(radians(-9));
  expect(p.start).toBe(radians(125)); expect(p.end).toBe(radians(235)); expect(p.fillEnd).toBeLessThan(p.end);
  expect(p.x).toBe(95); expect(p.y).toBe(184); expect(p.radius).toBe(10);
  const reduced = moralePlan(morale, foot, height, session.presentation, true);
  expect(reduced.fraction).toBe(.5); expect(reduced.rotation).toBeCloseTo(0);
  morale.apply(morale.rules.morale_max, 1); expect(moralePlan(morale, foot, height, session.presentation, true).fraction).toBe(0);
});
