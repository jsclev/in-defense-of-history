import type { EnemyDefinition, HeroDefinition } from '../data/contracts';
import type { Row } from '../data/records';
import type { Point } from '../hud/layout';
import { distance, equal, lerp, MovementArea, Route, swiftRound } from './navigation';
import type { MetaEffects } from './tower-tuning';
import { EnemyMorale } from './combat-math';
import { dt, fireTicks } from './schedules';

export type Enemy = { id: number; type: EnemyDefinition; path: number; along: number; spawnTick: number;
  position: Point; previous: Point; hp: number; maximumHP: number; morale: EnemyMorale };
export type Combat = Pick<Row<'hero_combat'>, 'hp' | 'attack_rating' | 'defense_rating' | 'attack_interval' | 'respawn_seconds' | 'heal_per_second' | 'move_speed'>;
export class Ally {
  position: Point; previous: Point; station: Point; rally: Point; hp: number;
  state: 'dead' | 'returning' | 'holding' | 'engaging' | 'fighting' = 'returning';
  target = -1; swing = 0; enemySwing = 0; respawn = 0; side = 1;
  facing = 4; phase = 0; moved = 0; walking = false;
  aiEnabled = false; recovering = false; nextDecision = 0;
  private route: Point[] = []; private routeTarget: Point | null = null;
  constructor(readonly id: string, readonly spawn: Point, readonly combat: Combat, readonly hero: HeroDefinition | null,
    readonly slot: number | null, readonly area: MovementArea, public scan: number, public leash: number) {
    this.position = this.previous = this.station = this.rally = spawn; this.hp = combat.hp;
    if (hero) this.aiEnabled = Boolean(hero.control.ai_enabled);
  }
  command(point: Point): boolean {
    if (this.state === 'dead') return false;
    const route = this.area.route(this.position, point); if (!route) return false;
    this.station = point; this.routeTarget = point; this.route = route;
    this.state = 'returning'; this.target = -1; this.enemySwing = 0; return true;
  }
  private move(point: Point, budget: number): boolean {
    if (!this.hero) { const gap = distance(this.position, point); this.position = gap <= budget ? point : lerp(this.position, point, budget / gap); return true; }
    if (!this.routeTarget || !equal(this.routeTarget, point)) {
      const planned = this.area.route(this.position, point); if (!planned) return false;
      this.route = planned; this.routeTarget = point;
    }
    while (this.route.length) {
      const goal = this.route[0]!, gap = distance(this.position, goal);
      if (gap <= budget) { this.position = goal; this.route.shift(); budget -= gap; }
      else { if (budget > 0) this.position = lerp(this.position, goal, budget / gap); break; }
    }
    return true;
  }
  decide(tick: number, enemies: Enemy[], claimed: Set<number>, routes: Route[]) {
    const hero = this.hero;
    if (!hero || !this.aiEnabled) return;
    if (this.state === 'dead') { this.recovering = false; this.nextDecision = 0; return; }
    if (tick < this.nextDecision) return;
    this.nextDecision = tick + fireTicks(hero.ai.decision_interval);
    const fraction = this.hp / this.combat.hp;
    if (fraction <= hero.ai.retreat_health_fraction) this.recovering = true;
    if (this.recovering && fraction < hero.ai.resume_health_fraction) {
      if (!equal(this.station, this.spawn) || ['engaging', 'fighting'].includes(this.state)) this.command(this.spawn);
      return;
    }
    this.recovering = false;
    if (['engaging', 'fighting'].includes(this.state)) return;
    const threats = enemies.filter(e => e.hp > 0 && !immune(e) && !claimed.has(e.id)).slice().sort((a, b) =>
      (routes[a.path]!.total - a.along) / a.type.speed - (routes[b.path]!.total - b.along) / b.type.speed ||
      distance(this.position, a.position) - distance(this.position, b.position) || a.id - b.id);
    for (const threat of threats) {
      if (this.area.route(this.position, threat.position) === null) continue;
      if (distance(this.position, threat.position) <= this.scan) {
        if (!equal(this.station, this.position)) this.command(this.position);
      } else if (distance(this.station, threat.position) > this.scan) this.command(threat.position);
      return;
    }
    if (!equal(this.station, this.spawn)) this.command(this.spawn);
  }
  step(enemies: Enemy[], claimed: Set<number>, rules: Row<'combat_rules'>, routes: Route[], random: () => number, kill: (enemy: Enemy) => void, meta?: MetaEffects) {
    this.previous = this.position;
    if (this.swing > 0) this.swing--;
    if (this.state === 'dead') {
      if (this.respawn > 0) { this.respawn--; return; }
      this.hp = this.combat.hp; this.position = this.previous = this.spawn; this.state = 'returning';
      if (this.hero) { this.station = this.spawn; this.phase = 0; this.facing = 4; }
      this.route = []; this.routeTarget = null; return;
    }
    const target = enemies.find(e => e.id === this.target && e.hp > 0);
    let toward: Point | null = null, strike = false;
    switch (this.state) {
      case 'returning':
        if (distance(this.position, this.station) <= rules.arrival_radius && !this.hero) this.state = 'holding';
        else toward = this.station;
        break;
      case 'holding': {
        let best: Enemy | undefined, gap = this.scan;
        for (const enemy of enemies) if (!this.recovering && enemy.hp > 0 && !immune(enemy) && !claimed.has(enemy.id)) {
          const d = distance(enemy.position, this.station); if (d <= gap) { gap = d; best = enemy; }
        }
        if (best) { this.target = best.id; this.state = 'engaging'; claimed.add(best.id); }
        else if (distance(this.position, this.station) > rules.arrival_radius) toward = this.station;
        else this.hp = Math.min(this.combat.hp, this.hp + this.combat.heal_per_second * dt);
        break;
      }
      case 'engaging': case 'fighting': {
        if (!target || distance(target.position, this.station) > this.leash) { this.disengage(claimed); break; }
        if (this.state === 'engaging') {
          if (distance(this.position, target.position) <= rules.melee_reach) {
            this.side = this.position.x < target.position.x ? -1 : 1; this.state = 'fighting';
            this.enemySwing = fireTicks(rules.enemy_swing_interval); strike = true;
          } else toward = target.position;
        } else {
          let preferred = { x: target.position.x + this.side * rules.melee_combat_spacing, y: target.position.y };
          if (this.hero && !this.area.contains(preferred)) {
            const opposite = { x: target.position.x - this.side * rules.melee_combat_spacing, y: target.position.y };
            if (this.area.contains(opposite)) { this.side *= -1; preferred = opposite; }
            preferred = this.area.nearest(preferred)!;
          }
          if (distance(this.position, preferred) > rules.arrival_radius) toward = preferred;
          else strike = this.swing === 0;
        }
        break;
      }
    }
    if (toward) {
      const point = !this.hero && !['engaging', 'fighting'].includes(this.state) ? marchWaypoint(this.position, toward, this.rally, routes, rules.melee_post_spread) : toward;
      if (!this.move(point, this.combat.move_speed * dt) && this.state === 'engaging') this.disengage(claimed);
      if (this.hero && this.state === 'returning' && equal(this.position, this.station)) this.state = 'holding';
    }
    if (strike && target) {
      const spread = rules.melee_attack_spread;
      target.hp -= this.combat.attack_rating * (1 - spread + 2 * spread * random()) * (1 - target.type.cover)
        * (!this.hero && meta ? meta.meleeDamage(target.morale.fraction) : 1);
      if (target.hp <= 0) { kill(target); this.state = 'holding'; this.target = -1; this.enemySwing = 0; }
      this.swing = fireTicks(this.combat.attack_interval);
    }
    if (this.state === 'fighting' && target && target.hp > 0) {
      this.enemySwing--;
      if (this.enemySwing <= 0) {
        this.hp -= (target.type.damage_min + random() * (target.type.damage_max - target.type.damage_min)) * (1 - this.combat.defense_rating) * target.morale.attackMultiplier(target.type);
        this.enemySwing = fireTicks(rules.enemy_swing_interval);
        if (this.hp <= 0) { claimed.delete(this.target); this.state = 'dead'; this.target = -1; this.respawn = fireTicks(this.combat.respawn_seconds); }
      }
    }
  }
  pose(cycle: number, threshold: number, enemies: Enemy[]) {
    this.moved = distance(this.previous, this.position); this.walking = this.moved > threshold;
    const target = enemies.find(e => e.id === this.target);
    const facing = this.walking ? this.position : target?.position;
    const origin = this.walking ? this.previous : this.position;
    if (facing && !equal(facing, origin)) this.facing = (swiftRound(Math.atan2(facing.x - origin.x, facing.y - origin.y) / (Math.PI / 4)) % 8 + 8) % 8;
    if (this.walking) this.phase = (this.phase + this.moved) % cycle;
  }
  private disengage(claimed: Set<number>) { claimed.delete(this.target); this.target = -1; this.enemySwing = 0; this.state = 'returning'; }
}
export function immune(enemy: Enemy) { return enemy.type.traits.some(t => t.type === 'rideDown'); }
export function ringPoint(index: number, count: number, center: Point, radius: number): Point {
  return count > 1 && radius > 0 ? { x: center.x + radius * Math.cos(2 * Math.PI * index / count),
    y: center.y + radius * Math.sin(2 * Math.PI * index / count) } : center;
}
function marchWaypoint(current: Point, target: Point, rally: Point, routes: Route[], radius: number) {
  const path = routes.reduce((best, p) => p.nearest(rally).gap < best.nearest(rally).gap ? p : best);
  if (distance(current, target) <= radius) return target;
  const along = path.nearest(current).along, remaining = path.nearest(rally).along - along;
  return Math.abs(remaining) <= radius ? target : path.point(along + Math.sign(remaining) * radius);
}
