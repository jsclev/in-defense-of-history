import type { Point } from '../hud/layout';
import type { Row } from '../data/records';
import type { TowerTier } from '../data/contracts';
import { distance, lerp, type Route } from './navigation';
import type { Enemy } from './units';
import { inRange } from './towers';

export const radians = (degrees: number) => degrees * Math.PI / 180;
export const wrapped = (angle: number) => Math.atan2(Math.sin(angle), Math.cos(angle));
// ArtilleryAim tracks continuously, including while reloading.
export function track(heading: number, origin: Point, target: Point, rate: number, seconds: number, tolerance: number) {
  const dx = target.x - origin.x, dy = target.y - origin.y;
  if (!Number.isFinite(dx + dy + rate + seconds) || Math.hypot(dx, dy) <= .000001 || rate < 0 || seconds < 0)
    return { heading, aligned: false };
  const desired = Math.atan2(dy, dx), difference = wrapped(desired - heading);
  heading = wrapped(heading + Math.sign(difference) * Math.min(Math.abs(difference), rate * seconds));
  return { heading, aligned: Math.abs(wrapped(desired - heading)) <= tolerance };
}
export function clampAim(point: Point, origin: Point, radius: number, vertical: number): Point {
  const gap = Math.hypot(point.x - origin.x, (point.y - origin.y) / vertical);
  return radius <= 0 || !Number.isFinite(gap) ? origin : gap <= radius ? point : lerp(origin, point, radius / gap);
}
export function rayRange(radius: number, vertical: number, heading: number) {
  return Number.isFinite(heading) ? radius / Math.hypot(Math.cos(heading), Math.sin(heading) / vertical) : 0;
}
// GrapeshotFlight orders swept contacts by closest projection, not circle entry.
export function hitFraction(start: Point, end: Point, target: Point, radius: number): number | null {
  const dx = end.x - start.x, dy = end.y - start.y, squared = dx * dx + dy * dy;
  const t = squared > 0 ? Math.max(0, Math.min(1, ((target.x - start.x) * dx + (target.y - start.y) * dy) / squared)) : 0;
  return distance(target, lerp(start, end, t)) <= radius ? t : null;
}
export function selectTarget(enemies: Enemy[], routes: Route[], origin: Point, tuning: TowerTier, vertical: number) {
  let best: Enemy | undefined, priority = -Infinity;
  for (const enemy of enemies) if (enemy.hp > 0 && inRange(enemy.position, origin, tuning.tower_range, vertical)) {
    const remaining = routes[enemy.path]!.total - enemy.along;
    const key = tuning.targeting === 'first' ? -remaining : tuning.targeting === 'last' ? remaining :
      tuning.targeting === 'strongest' ? enemy.hp : -enemy.morale.value;
    if (key > priority) { best = enemy; priority = key; }
  }
  return best;
}
export function exitsBlast(route: Route, along: number, travel: number, point: Point, radius: number, offset: Point) {
  if (!Number.isFinite(radius + along + travel) || radius <= 0 || travel <= 0 || along < 0 || along >= route.total) return false;
  const outside = (at: number) => { const p = route.point(at); return Math.hypot(p.x + offset.x - point.x, p.y + offset.y - point.y) > radius; };
  if (outside(along)) return false;
  const end = Math.min(route.total, along + travel);
  for (const at of route.lengths.slice(1)) if (at > along) {
    const next = Math.min(end, at); if (outside(next)) return true; if (next >= end) break;
  }
  return end === route.total;
}
export function moraleLoss(tuning: TowerTier, gap: number, discipline: number) {
  if (!Number.isFinite(gap) || gap < 0 || (tuning.aoe_radius !== 0 && gap > tuning.aoe_radius)) return 0;
  const fraction = tuning.aoe_radius > 0 ? (gap / tuning.aoe_radius) ** tuning.aoe_falloff_exponent : 0;
  return (tuning.terror_max - (tuning.terror_max - tuning.terror_min) * fraction) * (1 - Math.min(1, Math.max(0, discipline)));
}
export class EnemyMorale {
  value: number; before: number; age = Infinity; direction = 1;
  constructor(readonly rules: Row<'combat_rules'>) { this.value = this.before = rules.morale_max; }
  get visible() { return this.value < this.rules.morale_visibility_threshold; }
  get fraction() { return Math.min(1, Math.max(0, this.value / this.rules.morale_max)); }
  get displayed() { const ease = 1 - (1 - Math.min(1, this.age / this.rules.morale_display_duration)) ** 3; return this.before + (this.value - this.before) * ease; }
  get displayedFraction() { return Math.min(1, Math.max(0, this.displayed / this.rules.morale_max)); }
  apply(loss: number, direction: number) {
    if (!Number.isFinite(loss) || loss <= 0 || this.value <= 0) return false;
    this.before = this.displayed; this.value = Math.max(0, this.value - loss); this.age = 0; this.direction = direction < 0 ? -1 : 1; return true;
  }
  advance(seconds: number, speed: number, enemy: Row<'enemy_type'>, blocked: boolean, commit = true) {
    if (!Number.isFinite(seconds) || seconds <= 0) return 0;
    const threshold = enemy.morale_speed_threshold * this.rules.morale_max;
    const slowed = threshold >= this.rules.morale_max ? seconds : this.value <= threshold ? Math.min(seconds,
      Math.max(0, this.rules.morale_recovery_delay - this.age) + (threshold - this.value) / this.rules.base_morale_regen_per_second) : 0;
    if (commit) {
      const recovery = this.age === Infinity ? seconds : Math.max(0, this.age + seconds - Math.max(this.age, this.rules.morale_recovery_delay));
      this.age += seconds; this.value = Math.min(this.rules.morale_max, this.value + this.rules.base_morale_regen_per_second * recovery);
    }
    return blocked ? 0 : speed * (slowed * enemy.morale_speed_multiplier + seconds - slowed);
  }
  attackMultiplier(enemy: Row<'enemy_type'>) {
    return this.value <= enemy.morale_attack_threshold * this.rules.morale_max ? enemy.morale_attack_multiplier : 1;
  }
}
