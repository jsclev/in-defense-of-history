import type { TowerTier } from '../data/contracts';
import type { Point } from '../hud/layout';
import type { BattleSession } from './session';
import { inRange, type PlacedTower } from './towers';
import type { TowerKind } from './tower-tuning';
import type { Ally, Enemy } from './units';
import { distance, lerp } from './navigation';
import { dt, ticksPerSecond } from './schedules';
import { clampAim, exitsBlast, hitFraction, moraleLoss, radians, rayRange, selectTarget, track, wrapped } from './combat-math';
import { obstacleContains, obstacleField, obstacleSlow, type ObstacleField } from './tower-effects';

export type Projectile = { id: number; slot: number; kind: TowerKind; position: Point; previous: Point; origin: Point;
  heading: number; target: number; tuning: TowerTier; damage: number; impact: Point | null; remaining: number;
  volley: number; hits: Set<number> };
export type Impact = { id: number; position: Point; radius: number; age: number; demolition: boolean };
type Gun = { heading: number; next: number; shots: number; prepared: number; quiet: number };
// BattleEngine.updateCombat/updateProjectiles. Content stays in the shared SQLite DAOs.
export class TowerCombat {
  projectiles: Projectile[] = []; impacts: Impact[] = [];
  readonly guns = new Map<number, Gun>();
  private nextID = 0; private volleys = new Map<number, Set<number>>();
  constructor(private readonly session: BattleSession, private readonly random: () => number) {}
  private get rules() { return this.session.content.config.combat; }
  private get towers() { return this.session.towers; }
  private get meta() { return this.towers.meta; }
  changed(tower: PlacedTower, old: TowerTier | null, rank: boolean) {
    if (!this.guns.has(tower.slot)) this.guns.set(tower.slot, { heading: wrapped(radians(this.rules.initial_heading_degrees)), next: 0, shots: 0,
      prepared: tower.kind === 'ranged' ? this.meta.value('twoGoodVolleys', 'shotCount') ?? 0 : 0, quiet: 0 });
    const gun = this.guns.get(tower.slot)!;
    if (rank && old && old.fire_interval > 0 && gun.next > this.session.clock.tick)
      gun.next = this.session.clock.tick + Math.ceil((gun.next - this.session.clock.tick) * this.towers.tuning(tower).fire_interval / old.fire_interval);
  }
  heading(tower: PlacedTower) { return this.guns.get(tower.slot)!.heading * 180 / Math.PI; }
  fields() { return this.towers.placed.filter(t => t.site !== null).map(t => obstacleField(t.site!, this.towers.tuning(t), this.session.content.routes)); }
  support(point: Point, field: 'support_attack_speed_multiplier' | 'support_heal_per_second') {
    return this.towers.placed.reduce((best, tower) => { const tuning = this.towers.tuning(tower);
      return inRange(point, tower.position, tuning.tower_range, this.rules.range_vertical_fraction) ? Math.max(best, tuning[field]) : best;
    }, field === 'support_attack_speed_multiplier' ? 1 : 0);
  }
  heal(unit: Ally) {
    if (unit.state !== 'dead' && unit.hp > 0 && unit.hp < unit.combat.hp)
      unit.hp = Math.min(unit.combat.hp, unit.hp + dt * this.support(unit.position, 'support_heal_per_second'));
  }
  advanceImpacts() {
    this.impacts = this.impacts.filter(impact => { impact.age += dt;
      return impact.age < (impact.demolition ? this.session.presentation.explosion.frameEnds.at(-1)! : .78); });
  }
  travel(enemy: Enemy, blocked: Set<number | null>, fields: ObstacleField[], commit: boolean) {
    return enemy.morale.advance(Math.min(dt, (this.session.clock.tick - enemy.spawnTick) * dt),
      enemy.type.speed * obstacleSlow(enemy.position, fields), enemy.type, blocked.has(enemy.id), commit);
  }
  detonate(blocked: Set<number | null>, fields: ObstacleField[]) {
    for (const tower of this.towers.placed) {
      if (tower.charge === null || tower.chargeRemaining > 0) continue;
      const tuning = this.towers.tuning(tower);
      if (!inRange(tower.charge, tower.position, tuning.tower_range, this.rules.range_vertical_fraction)) continue;
      if (!this.session.enemies.some(e => exitsBlast(this.session.content.routes[e.path]!, e.along, this.travel(e, blocked, fields, false),
        tower.charge!, tuning.aoe_radius, { x: this.rules.enemy_body_offset_x, y: this.rules.enemy_body_offset_y }))) continue;
      tower.chargeRemaining = tuning.demolition_prepare_seconds!;
      const projectile = this.shot(tower, tuning, 0, -1, 1); projectile.kind = 'areaOfEffect';
      this.impact(projectile, tower.charge, fields, true);
    }
  }
  update(blocked: Set<number | null>) {
    for (const tower of this.towers.placed) {
      const tuning = this.towers.tuning(tower), mode = tuning.attack_mode;
      if (!['direct', 'shell', 'grapeshot', 'solidShot'].includes(mode)) continue;
      const gun = this.guns.get(tower.slot)!;
      const target = selectTarget(this.session.enemies, this.session.content.routes, tower.position, tuning, this.rules.range_vertical_fraction);
      if (tower.kind === 'ranged') {
        const seconds = this.meta.value('twoGoodVolleys', 'preparationSeconds');
        if (seconds !== undefined) {
          gun.quiet = target ? 0 : Math.min(seconds, gun.quiet + dt);
          if (gun.quiet >= seconds) gun.prepared = this.meta.value('twoGoodVolleys', 'shotCount')!;
        }
      }
      if (!target) continue;
      const aim = mode === 'direct' ? this.body(target) : clampAim(this.body(target), tower.position, tuning.tower_range, this.rules.range_vertical_fraction);
      let heading = Math.atan2(aim.y - tower.position.y, aim.x - tower.position.x);
      if (mode !== 'direct') {
        const result = track(gun.heading, tower.position, aim, radians(tuning.turn_rate_degrees), dt, radians(this.rules.firing_tolerance_degrees));
        gun.heading = result.heading; heading = gun.heading; if (!result.aligned) continue;
      }
      if (this.session.clock.tick < gun.next) continue;
      const rate = this.support(tower.position, 'support_attack_speed_multiplier') / tuning.fire_interval;
      gun.next = this.session.clock.tick + Math.max(1, Math.round(ticksPerSecond / rate));
      gun.shots++; const prepared = gun.prepared > 0; gun.prepared = Math.max(0, gun.prepared - 1); gun.quiet = 0;
      const projectile = this.shot(tower, tuning, heading, target.id, this.meta.rangedDamage(tower.kind, blocked.has(target.id), prepared));
      if (mode === 'shell') projectile.impact = aim;
      if (mode === 'grapeshot') {
        this.volleys.set(projectile.id, new Set());
        this.rules.grapeshot_spread_degrees.forEach((offset, i) => {
          const direction = heading + radians(offset);
          this.projectiles.push({ ...projectile, id: i === 0 ? projectile.id : this.nextID++, heading: direction,
            remaining: rayRange(tuning.tower_range, this.rules.range_vertical_fraction, direction) });
        });
      } else this.projectiles.push(projectile);
    }
    this.advanceProjectiles(this.fields());
  }
  private shot(tower: PlacedTower, tuning: TowerTier, heading: number, target: number, multiplier: number): Projectile {
    const id = this.nextID++, minimum = tuning.shot_min_damage * multiplier, maximum = tuning.shot_max_damage * multiplier;
    return { id, slot: tower.slot, kind: tower.kind, position: tower.position, previous: tower.position, origin: tower.position,
      heading, target, tuning, damage: minimum + this.random() * (maximum - minimum),
      impact: null, remaining: rayRange(tuning.tower_range, this.rules.range_vertical_fraction, heading), volley: id, hits: new Set() };
  }
  private body(enemy: Enemy): Point { return { x: enemy.position.x + this.rules.enemy_body_offset_x, y: enemy.position.y + this.rules.enemy_body_offset_y }; }
  private shock(projectile: Projectile, enemy: Enemy, at: Point) {
    enemy.morale.apply(moraleLoss(projectile.tuning, distance(this.body(enemy), at), enemy.type.discipline), enemy.position.x < at.x ? -1 : 1);
  }
  private damage(enemy: Enemy, amount: number) {
    enemy.hp -= amount;
    if (enemy.hp <= 0) { this.session.creditKill(enemy); this.session.enemies = this.session.enemies.filter(e => e.id !== enemy.id); }
  }
  private lane(projectile: Projectile, enemy: Enemy, fields: ObstacleField[]) {
    return this.meta.fireLane(projectile.kind, fields.some(f => obstacleContains(enemy.position, f)));
  }
  private impact(projectile: Projectile, point: Point, fields: ObstacleField[], demolition = false) {
    const explosive = projectile.tuning.attack_mode !== 'direct';
    if (explosive) this.impacts.push({ id: projectile.id, position: point, radius: Math.max(24, projectile.tuning.aoe_radius), age: 0, demolition });
    for (const enemy of this.session.enemies.slice()) {
      if (!(explosive ? distance(this.body(enemy), point) <= projectile.tuning.aoe_radius : enemy.id === projectile.target)) continue;
      if (explosive) this.shock(projectile, enemy, point);
      const cover = explosive ? 1 - enemy.type.cover * (1 - projectile.tuning.splash_cover_pierce) : 1;
      this.damage(enemy, projectile.damage * cover * (demolition ? 1 : this.lane(projectile, enemy, fields)));
    }
  }
  private advanceProjectiles(fields: ObstacleField[]) {
    const survivors: Projectile[] = [];
    for (const p of this.projectiles) {
      p.previous = p.position;
      const mode = p.tuning.attack_mode, step = p.tuning.projectile_speed * dt;
      if (mode === 'solidShot' || mode === 'grapeshot') {
        const travel = Math.min(p.remaining, step), end = { x: p.position.x + Math.cos(p.heading) * travel, y: p.position.y + Math.sin(p.heading) * travel };
        const hitIDs = mode === 'solidShot' ? p.hits : this.volleys.get(p.volley)!;
        const hits = this.session.enemies.filter(e => !hitIDs.has(e.id) && inRange(e.position, p.origin, p.tuning.tower_range, this.rules.range_vertical_fraction))
          .map(enemy => ({ enemy, fraction: hitFraction(p.position, end, this.body(enemy), mode === 'solidShot' ? this.rules.solid_shot_hit_radius : this.rules.grapeshot_hit_radius) }))
          .filter(hit => hit.fraction !== null).sort((a, b) => a.fraction! - b.fraction! || (mode === 'solidShot' ? a.enemy.id - b.enemy.id : 0));
        for (const { enemy } of mode === 'solidShot' ? hits : hits.slice(0, 1)) {
          this.shock(p, enemy, this.body(enemy));
          if (mode === 'grapeshot' && hitIDs.size === 0) this.impacts.push({ id: p.volley,
            position: clampAim(this.body(enemy), p.origin, p.tuning.tower_range, this.rules.range_vertical_fraction), radius: 24, age: 0, demolition: false });
          const doctrine = this.meta.batteryDamage(mode, hitIDs.size, distance(enemy.position, p.origin) / rayRange(p.tuning.tower_range, this.rules.range_vertical_fraction, p.heading));
          hitIDs.add(enemy.id); this.damage(enemy, p.damage * doctrine * this.lane(p, enemy, fields));
        }
        p.remaining -= travel; p.position = end;
        if (p.remaining > 0 && (mode === 'solidShot' || hits.length === 0)) survivors.push(p);
        continue;
      }
      const target = this.session.enemies.find(e => e.id === p.target);
      const aim = p.impact ?? (target ? this.body(target) : null); if (!aim) continue;
      const gap = distance(p.position, aim);
      if (gap <= this.rules.projectile_hit_radius || gap <= step) { this.impact(p, aim, fields); continue; }
      p.heading = Math.atan2(aim.y - p.position.y, aim.x - p.position.x); p.position = lerp(p.position, aim, step / gap); survivors.push(p);
    }
    this.projectiles = survivors;
    const live = new Set(survivors.filter(p => p.tuning.attack_mode === 'grapeshot').map(p => p.volley));
    for (const id of this.volleys.keys()) if (!live.has(id)) this.volleys.delete(id);
  }
}
