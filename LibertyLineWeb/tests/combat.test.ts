import { beforeAll, beforeEach, afterEach, expect, it } from 'vitest';
import { authored, battleSession, type Authored } from './fixtures';
import type { ContentDatabase } from '../src/content/database';
import type { BattleSession } from '../src/game/session';
import type { TowerKind } from '../src/game/tower-tuning';
import type { Enemy } from '../src/game/units';
import { EnemyMorale, radians, rayRange } from '../src/game/combat-math';
import { dt, fireTicks } from '../src/game/schedules';
import { Route } from '../src/game/navigation';
import type { Point } from '../src/hud/layout';
let fixture: Authored, db: ContentDatabase, session: BattleSession;
beforeAll(async () => { fixture = await authored(); });
beforeEach(async () => {
  db = fixture.open(); db.db.run('UPDATE level_tower_unlock SET max_tower_level=4');
  db.db.run('UPDATE level_info SET starting_money=100000');
  session = await battleSession(db);
  session.heroes.forEach(h => { h.state = 'dead'; h.respawn = 100000; });
});
afterEach(() => db.close());
function build(kind: TowerKind, level = 1, branch = 1) {
  const t = session.towers, slot = session.content.slots[t.placed.length]!.index;
  t.select(slot); t.tapBuild(kind); expect(t.tapBuild(kind)).toBe('ok');
  for (let rank = 2; rank <= level; rank++) { const b = rank === 4 ? branch : 1; t.select(slot); t.tapUpgrade(b); expect(t.tapUpgrade(b)).toBe('ok'); }
  return t.placed.at(-1)!;
}
function enemy(id: number, point: Point, hp = 10000): Enemy {
  const type = structuredClone(session.content.enemies[0]!);
  return { id, type, path: 0, along: 0, spawnTick: 0, position: point, previous: point, hp, maximumHP: hp, morale: new EnemyMorale(session.content.config.combat) };
}
function bodyAt(id: number, point: Point, hp = 10000) {
  const r = session.content.config.combat;
  return enemy(id, { x: point.x - r.enemy_body_offset_x, y: point.y - r.enemy_body_offset_y }, hp);
}
function ticks(count: number, blocked = new Set<number>()) { for (let i = 0; i < count; i++) { session.clock.tick++; session.combat.update(blocked); } }
function selectMeta(...keys: string[]) {
  for (const selection of session.player.meta.selections) selection.is_selected = keys.includes(selection.upgrade_key) ? 1 : 0;
}
it('fires direct shots on native ticks, homes on the original target, ignores cover and credits a kill once', () => {
  selectMeta(); const tower = build('ranged'), tuning = session.towers.tuning(tower), p = tower.position;
  const e = bodyAt(1, { x: p.x + 100, y: p.y }); e.type.cover = 1; session.enemies = [e];
  ticks(1); const shot = session.combat.projectiles[0]!;
  expect(shot.previous).toEqual(p); expect(shot.position.x).toBeCloseTo(p.x + tuning.projectile_speed * dt);
  expect(session.combat.guns.get(tower.slot)!.next).toBe(1 + fireTicks(tuning.fire_interval));
  e.position.y += 4; const damage = (tuning.shot_min_damage + tuning.shot_max_damage) / 2;
  ticks(10); expect(e.hp).toBe(10000 - damage); expect(session.combat.projectiles).toHaveLength(0);
  e.hp = 1; const money = session.money; ticks(fireTicks(tuning.fire_interval));
  expect(session.enemies).toHaveLength(0); expect(session.money).toBe(money + Math.round(e.type.bounty * session.content.config.combat.kill_bounty_multiplier));
  ticks(100); expect(session.money).toBe(money + Math.round(e.type.bounty * session.content.config.combat.kill_bounty_multiplier));
});
it('drops a direct shot when its target dies and preserves launch tuning across tower upgrades', () => {
  selectMeta(); const t = build('ranged'), p = t.position;
  session.enemies = [bodyAt(1, { x: p.x + 130, y: p.y })]; ticks(1);
  const shot = session.combat.projectiles[0]!, damage = shot.damage, interval = shot.tuning.fire_interval;
  session.towers.select(t.slot); session.towers.tapUpgrade(1); session.towers.tapUpgrade(1);
  expect(shot.tuning.fire_interval).toBe(interval); expect(shot.damage).toBe(damage);
  session.enemies = []; ticks(1); expect(session.combat.projectiles).toHaveLength(0);
});
it('tracks artillery during reload, fires only within tolerance, and snapshots the shell destination', () => {
  selectMeta(); const t = build('areaOfEffect'), tuning = session.towers.tuning(t), p = t.position;
  const e = bodyAt(1, { x: p.x - 150, y: p.y }); session.enemies = [e];
  ticks(1); expect(session.combat.projectiles).toHaveLength(0);
  expect(session.combat.heading(t)).not.toBe(session.content.config.combat.initial_heading_degrees);
  ticks(100); expect(session.combat.guns.get(t.slot)!.shots).toBeGreaterThan(0);
  const gun = session.combat.guns.get(t.slot)!; gun.next = session.clock.tick + 10000;
  const heading = gun.heading; e.position = { x: p.x, y: p.y + 120 }; ticks(1);
  expect(gun.heading).not.toBe(heading); expect(tuning.turn_rate_degrees).toBeGreaterThan(0);
});
it('shells hit circular body positions with cover piercing and morale falloff, without HP falloff', () => {
  selectMeta(); const t = build('areaOfEffect'), p = t.position, tuning = session.towers.tuning(t), r = tuning.aoe_radius;
  session.combat.guns.get(t.slot)!.heading = 0;
  const at = { x: p.x + 70, y: p.y }, a = bodyAt(1, at), b = bodyAt(2, { x: at.x, y: at.y + r * .5 }), c = bodyAt(3, { x: at.x, y: at.y - r * 1.01 });
  a.along = 1000; a.type.cover = b.type.cover = .5; a.type.discipline = b.type.discipline = 0;
  session.enemies = [a, b, c]; ticks(1); const shot = session.combat.projectiles[0]!;
  expect(shot.impact).toEqual(at); const original = shot.impact;
  // A dead original target does not erase an already launched shell.
  session.enemies = [b, c]; ticks(20);
  expect(shot.impact).toEqual(original); expect(b.hp).toBeCloseTo(10000 - shot.damage * (1 - .5 * (1 - tuning.splash_cover_pierce)));
  expect(c.hp).toBe(10000); expect(b.morale.value).toBeLessThan(b.morale.rules.morale_max);
  expect(session.combat.impacts).toHaveLength(1);
});
it.each(['grapeshot', 'solidShot'] as const)('sweeps %s collisions, limits travel to the launch ellipse and never hits an enemy twice', mode => {
  selectMeta(); const tier = session.content.towers.find(k => k.tower_type_key === 'areaOfEffect')!.tiers.find(t => t.attack_mode === mode)!;
  const t = build('areaOfEffect', tier.tower_level, tier.branch), p = t.position;
  session.combat.guns.get(t.slot)!.heading = 0;
  const a = bodyAt(5, { x: p.x + 40, y: p.y }), b = bodyAt(3, { x: p.x + 60, y: p.y }), outside = bodyAt(9, { x: p.x + tier.tower_range + 100, y: p.y });
  session.enemies = [a, b, outside]; ticks(1);
  const damage = session.combat.projectiles[0]?.damage ?? (tier.shot_min_damage + tier.shot_max_damage) / 2;
  const gun = session.combat.guns.get(t.slot)!; gun.next = 100000;
  ticks(100); expect(a.hp).toBeCloseTo(10000 - damage); expect(outside.hp).toBe(10000);
  if (mode === 'solidShot') { expect(b.hp).toBeCloseTo(10000 - damage); expect(session.combat.impacts).toHaveLength(0); }
  else { expect(b.hp).toBeGreaterThanOrEqual(10000 - damage); expect(session.combat.impacts).toHaveLength(1); }
  expect(session.combat.projectiles).toHaveLength(0);
});
it('uses the same damage roll and per-pellet ray range for every pellet in a volley', () => {
  selectMeta(); const tier = session.content.towers.find(k => k.tower_type_key === 'areaOfEffect')!.tiers.find(t => t.attack_mode === 'grapeshot')!;
  const t = build('areaOfEffect', 4, tier.branch), p = t.position; session.combat.guns.get(t.slot)!.heading = 0;
  session.enemies = [bodyAt(1, { x: p.x + 150, y: p.y })]; ticks(1);
  const pellets = session.combat.projectiles, rules = session.content.config.combat;
  expect(pellets).toHaveLength(rules.grapeshot_spread_degrees.length);
  expect(new Set(pellets.map(p => p.damage)).size).toBe(1); expect(new Set(pellets.map(p => p.id)).size).toBe(pellets.length);
  pellets.forEach((p, i) => { expect(p.heading).toBeCloseTo(radians(rules.grapeshot_spread_degrees[i]!));
    expect(p.remaining).toBeCloseTo(rayRange(tier.tower_range, rules.range_vertical_fraction, p.heading) - tier.projectile_speed * dt); });
});
it('applies crossfire, prepared volleys, quiet preparation, fire lanes and battery doctrine only when selected', () => {
  selectMeta('crossfire', 'twoGoodVolleys', 'preparedFireLanes', 'batteryDoctrine', 'bayonetCounterstroke');
  const t = build('ranged'), p = t.position, meta = session.towers.meta, gun = session.combat.guns.get(t.slot)!;
  session.enemies = [bodyAt(1, { x: p.x + 150, y: p.y })]; ticks(1, new Set([1]));
  const tuning = session.towers.tuning(t), base = (tuning.shot_min_damage + tuning.shot_max_damage) / 2;
  expect(session.combat.projectiles[0]!.damage).toBeCloseTo(base * meta.value('crossfire', 'damageMultiplier')! * meta.value('twoGoodVolleys', 'damageMultiplier')!);
  expect(gun.prepared).toBe(meta.value('twoGoodVolleys', 'shotCount')! - 1);
  ticks(200); expect(gun.prepared).toBe(0); session.enemies = []; ticks(Math.ceil(meta.value('twoGoodVolleys', 'preparationSeconds')! / dt) + 1);
  expect(gun.prepared).toBe(meta.value('twoGoodVolleys', 'shotCount'));
  expect(meta.rangedDamage('special', true, true)).toBe(1); expect(meta.fireLane('special', true)).toBe(1);
  expect(meta.fireLane('ranged', true)).toBe(meta.value('preparedFireLanes', 'damageMultiplier'));
  expect(meta.batteryDamage('solidShot', 1, 0)).toBe(meta.value('batteryDoctrine', 'secondaryHitMultiplier'));
  expect(meta.batteryDamage('grapeshot', 0, 0)).toBe(meta.value('batteryDoctrine', 'closeRangeMultiplier'));
  expect(meta.meleeDamage(0)).toBe(meta.value('bayonetCounterstroke', 'damageMultiplier')); expect(meta.meleeDamage(1)).toBe(1);
});
it('uses the strongest supply aura for reload and healing, never stacking or reviving dead units', () => {
  selectMeta(); const t = build('ranged'), p = t.position;
  const supply = session.content.towers.find(k => k.tower_type_key === 'supply')!;
  const speed = supply.tiers.find(l => l.support_attack_speed_multiplier > 1)!, heal = supply.tiers.find(l => l.support_heal_per_second > 0)!;
  const a = build('supply', speed.tower_level, speed.branch), b = build('supply', speed.tower_level, speed.branch);
  a.position = b.position = p; expect(session.combat.support(p, 'support_attack_speed_multiplier')).toBe(speed.support_attack_speed_multiplier);
  session.enemies = [bodyAt(1, { x: p.x + 100, y: p.y })]; ticks(1);
  expect(session.combat.guns.get(t.slot)!.next).toBe(1 + fireTicks(session.towers.tuning(t).fire_interval / speed.support_attack_speed_multiplier));
  a.level = heal.tower_level; a.branch = heal.branch;
  const unit = session.heroes[0]!; unit.position = p; unit.hp = unit.combat.hp / 2;
  session.combat.heal(unit); expect(unit.hp).toBe(unit.combat.hp / 2); unit.state = 'fighting'; session.combat.heal(unit);
  expect(unit.hp).toBeCloseTo(unit.combat.hp / 2 + heal.support_heal_per_second * dt);
  unit.position = { x: 0, y: 0 }; expect(session.combat.support(unit.position, 'support_heal_per_second')).toBe(0);
});
it('preserves reload fraction on specialty rank purchases and aim on tier purchases', () => {
  selectMeta();
  const candidates = session.content.towers.flatMap(kind => kind.tiers.map(tier => ({ kind, tier })));
  const { kind, tier } = candidates.find(({ tier }) => tier.upgrades.some(p => p.ranks.some(r => r.effects_json.some(e => e.attribute === 'fireInterval'))))!;
  const t = build(kind.tower_type_key, 4, tier.branch), gun = session.combat.guns.get(t.slot)!;
  const path = tier.upgrades.find(p => p.ranks.some(r => r.effects_json.some(e => e.attribute === 'fireInterval')))!;
  const old = session.towers.tuning(t); gun.next = session.clock.tick + 100;
  session.towers.select(t.slot); session.towers.tapPath(path.id); expect(session.towers.tapPath(path.id)).toBe('ok');
  expect(gun.next).toBe(session.clock.tick + Math.ceil(100 * session.towers.tuning(t).fire_interval / old.fire_interval));
});
it('detonates a planted charge before an outgoing enemy moves, applies blast damage once and restarts preparation', () => {
  selectMeta(); const tier = session.content.towers.find(k => k.tower_type_key === 'special')!.tiers.find(t => t.has_demolition_charge)!;
  const t = build('special', 4, tier.branch), p = t.position, r = tier.aoe_radius;
  const offset = session.content.config.combat.enemy_body_offset_y;
  session.content.routes = [new Route([{ x: p.x - r, y: p.y - offset }, { x: p.x + r + 200, y: p.y - offset }])];
  const e = bodyAt(1, { x: p.x + r - .1, y: p.y }); e.along = r * 2 - .1; e.type.speed = 100; e.type.discipline = 0;
  session.enemies = [e]; expect(t.charge).toBeNull(); session.advance(1); expect(session.combat.impacts).toHaveLength(0);
  e.along = r * 2 - .1; e.position = session.content.routes[0]!.point(e.along); t.charge = p;
  session.advance(1); expect(t.chargeRemaining).toBe(tier.demolition_prepare_seconds);
  expect(session.combat.impacts[0]!.demolition).toBe(true); expect(e.hp).toBeLessThan(10000);
  const hp = e.hp; session.advance(1); expect(e.hp).toBe(hp); expect(t.chargeRemaining).toBeCloseTo(tier.demolition_prepare_seconds! - dt);
  t.chargeRemaining = 0; t.charge = { x: 0, y: 0 }; session.advance(1); expect(t.chargeRemaining).toBe(0);
});
it('keeps pause, speed, catch-up batches, outcomes and effect expiry on the shared fixed clock', async () => {
  selectMeta(); const t = build('ranged'), p = t.position;
  const route = new Route([{ x: p.x - 100, y: p.y }, { x: p.x + 100, y: p.y }]); session.content.routes = [route];
  const e = enemy(1, route.point(0), 1); e.type.speed = 1; session.enemies = [e];
  session.pause(); session.advance(20); expect(session.clock.tick).toBe(0); session.resume();
  session.clock.setSpeed(8); session.advance(20); expect(session.enemies).toHaveLength(0);
  session.waves.next = session.content.waves.length;
  session.combat.impacts = [{ id: 2, position: p, radius: 50, age: 0, demolition: false }, { id: 3, position: p, radius: 50, age: 0, demolition: true }];
  session.advance(1); expect(session.outcome).toBe('victory'); session.advance(60); expect(session.combat.impacts).toHaveLength(0);
});
it('propagates SQL damage edits and rejects missing combat rules instead of inventing values', async () => {
  db.db.run("UPDATE tower SET shot_min_damage=123,shot_max_damage=123 WHERE attack_mode='direct'");
  session = await battleSession(db); selectMeta(); const t = build('ranged'), p = t.position;
  session.enemies = [bodyAt(1, { x: p.x + 100, y: p.y })]; ticks(1); expect(session.combat.projectiles[0]!.damage).toBe(123);
  db.db.run('DELETE FROM combat_rules'); await expect(battleSession(db)).rejects.toThrow('combat_rules');
});
it('produces identical firing, damage, morale and rewards for catch-up batches and individual ticks', async () => {
  const run = async (batch: boolean) => {
    session = await battleSession(db); selectMeta();
    session.heroes.forEach(h => { h.state = 'dead'; h.respawn = 100000; });
    const a = build('ranged'), b = build('areaOfEffect'); b.position = { x: a.position.x, y: a.position.y + 50 };
    const p = a.position, route = new Route([{ x: p.x - 100, y: p.y }, { x: p.x + 1000, y: p.y }]); session.content.routes = [route];
    session.enemies = [0, 1, 2].map(i => { const e = enemy(i, route.point(i * 10), 90); e.along = i * 10; e.type.speed = 30; return e; });
    if (batch) session.advance(150); else for (let i = 0; i < 150; i++) session.advance(1);
    return { money: session.money, lives: session.lives, enemies: session.enemies.map(e => ({ id: e.id, hp: e.hp, along: e.along, morale: e.morale.value })),
      guns: [...session.combat.guns], projectiles: session.combat.projectiles, impacts: session.combat.impacts };
  };
  expect(await run(true)).toEqual(await run(false));
});
