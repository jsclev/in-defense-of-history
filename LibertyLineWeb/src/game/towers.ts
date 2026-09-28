import type { TowerTier, UpgradePath } from '../data/contracts';
import type { BattleContent } from './content';
import type { Point } from '../hud/layout';
import { contentError } from '../content/schema';
import { closest, distance, equal, lerp, type Route } from './navigation';
import { MetaEffects, upgraded, type TowerKind } from './tower-tuning';

export type PurchaseResult = 'ok' | 'invalid' | 'needGold' | null;
export type PlacedTower = { slot: number; kind: TowerKind; position: Point; level: number; branch: number;
  ranks: Record<string, number>; rally: Point | null; site: Point | null; charge: Point | null; chargeRemaining: number };
export type TowerActions = { acceptsInput(): boolean; money(): number; spend(amount: number): void; cancelOther(): void;
  changed(tower: PlacedTower, previous: TowerTier | null, rank: boolean): void };
export type TowerOffer = { branch: number; tier: TowerTier; cost: number };

export class TowerPlacement {
  readonly placed: PlacedTower[] = [];
  selected: number | null = null;
  armed: string | null = null;
  placement: 'rally' | 'charge' | 'obstacles' | null = null;
  flash: Point | null = null;
  flashRemaining = 0;
  private trained = new Set<string>(); private specialized = false;
  private readonly tuningCache = new WeakMap<PlacedTower, { base: TowerTier; kind: TowerKind; meta: string;
    ranks: Record<string, number>; value: TowerTier }>();
  readonly meta: MetaEffects;
  constructor(readonly content: BattleContent, private readonly actions: TowerActions) {
    this.meta = new MetaEffects(content.player, content.catalog);
    // Validate all combined ranks before purchases can mutate the live battle.
    for (const kind of content.towers) for (const tier of kind.tiers)
      upgraded(tier, Object.fromEntries(tier.upgrades.map(p => [p.id, p.ranks.length])));
  }
  get money() { return this.actions.money(); }
  get current() { return this.placed.find(t => t.slot === this.selected); }
  base(kind: TowerKind, level = 1, branch = 1): TowerTier {
    const tier = this.content.towers.find(t => t.tower_type_key === kind)?.tiers.find(t => t.tower_level === level && t.branch === branch);
    if (!tier) throw contentError(`tower[${kind}:${level}:${branch}]`, 'Missing authored tier'); return tier;
  }
  maxLevel(kind: TowerKind) {
    const unlock = this.content.unlocks.find(u => u.tower_kind === kind);
    if (!unlock) throw contentError(`level_tower_unlock[${kind}]`, 'Missing authored unlock'); return unlock.max_tower_level;
  }
  tuning(tower: PlacedTower): TowerTier {
    const base = this.base(tower.kind, tower.level, tower.branch), meta = this.meta.selectionKey;
    const cached = this.tuningCache.get(tower), keys = Object.keys(tower.ranks);
    if (cached && cached.base === base && cached.kind === tower.kind && cached.meta === meta
      && keys.length === Object.keys(cached.ranks).length && keys.every(key => cached.ranks[key] === tower.ranks[key])) return cached.value;
    // Authored content belongs to this battle's DAO snapshot. Revalidate on each
    // changed purchase, then share an immutable result with rendering and shots.
    const value = freezeTuning(this.meta.combat(upgraded(base, tower.ranks), tower.kind));
    this.tuningCache.set(tower, { base, kind: tower.kind, meta, ranks: { ...tower.ranks }, value });
    return value;
  }
  cost(kind: TowerKind, level = 1, branch = 1, slot: number | null = null) {
    const target = this.content.slots.find(s => s.index === slot);
    const served = target !== undefined && this.placed.some(t => t.kind === 'supply' && t.slot !== slot
      && inRange(target, t.position, this.tuning(t).tower_range, this.content.config.combat.range_vertical_fraction));
    return this.meta.cost(this.base(kind, level, branch), kind, this.trained.has(`${kind}:${level}`), !this.specialized, served);
  }
  select(slot: number) {
    if (!this.actions.acceptsInput() || !this.content.slots.some(s => s.index === slot)) return;
    this.actions.cancelOther(); const next = this.selected === slot ? null : slot; this.dismiss(); this.selected = next;
  }
  dismiss() { this.selected = null; this.armed = null; this.placement = null; }
  tapBuild(kind: TowerKind): PurchaseResult {
    if (!this.actions.acceptsInput() || this.selected === null || this.current || this.maxLevel(kind) < 1) return 'invalid';
    if (this.armed !== `build:${kind}`) { this.armed = this.armed === null ? `build:${kind}` : null; return null; }
    const cost = this.cost(kind);
    if (cost > this.money) { this.dismiss(); return 'needGold'; }
    const point = this.content.slots.find(s => s.index === this.selected)!;
    const tower: PlacedTower = { slot: point.index, position: { x: point.x, y: point.y }, kind, level: 1, branch: 1, ranks: {}, rally: null, site: null, charge: null, chargeRemaining:0 };
    const tuning = this.tuning(tower);
    if (tuning.melee) tower.rally = rallyPoint(tower.position, tower.position, tuning.melee.rally_point_radius, this.content.routes);
    if (tuning.has_engineer_obstacles) tower.site = this.nearestSite(tower, tower.position, tuning);
    this.actions.spend(cost); this.placed.push(tower); this.dismiss(); this.actions.changed(tower, null, false); return 'ok';
  }
  get offers(): TowerOffer[] {
    const t = this.current; if (!t || t.level + 1 > this.maxLevel(t.kind)) return [];
    const definition = this.content.towers.find(k => k.tower_type_key === t.kind)!;
    return definition.tiers.filter(tier => tier.tower_level === t.level + 1).sort((a,b) => a.branch - b.branch)
      .filter(tier => !tier.has_demolition_charge || this.nearestSite(t, t.position, this.meta.combat(tier, t.kind)) !== null)
      .map(tier => ({ tier, branch: tier.branch, cost: this.cost(t.kind, tier.tower_level, tier.branch, t.slot) }));
  }
  get paths(): UpgradePath[] { const t = this.current; return t && t.level === 4 && this.maxLevel(t.kind) >= 4 ? this.base(t.kind, t.level, t.branch).upgrades : []; }
  tapUpgrade(branch: number): PurchaseResult {
    if (!this.actions.acceptsInput()) return 'invalid';
    const offer = this.offers.find(o => o.branch === branch), t = this.current;
    if (!offer || !t) return 'invalid';
    if (this.armed !== `tier:${branch}`) { this.armed = `tier:${branch}`; this.placement = null; return null; }
    if (offer.cost > this.money) { this.dismiss(); return 'needGold'; }
    const old = this.tuning(t); this.actions.spend(offer.cost);
    t.level = offer.tier.tower_level; t.branch = branch;
    if (t.level === 4) this.specialized = true; else this.trained.add(`${t.kind}:${t.level}`);
    const tuning = this.tuning(t);
    t.site = tuning.has_engineer_obstacles ? t.site ?? this.nearestSite(t, t.position, tuning) : null;
    if (tuning.has_demolition_charge) t.charge = null; // Ready, unplaced; no initial cooldown.
    this.dismiss(); this.actions.changed(t, old, false); return 'ok';
  }
  tapPath(id: string): PurchaseResult {
    const t = this.current, path = this.paths.find(p => p.id === id);
    if (!this.actions.acceptsInput() || !t || !path) return 'invalid';
    this.placement = null;
    if (this.armed !== `path:${id}`) { this.armed = `path:${id}`; return null; }
    const next = path.ranks.find(r => r.rank === (t.ranks[id] ?? 0) + 1);
    if (!next) return 'invalid'; if (next.cost > this.money) return 'needGold';
    const old = this.tuning(t); this.actions.spend(next.cost); t.ranks[id] = next.rank;
    if(old.demolition_prepare_seconds!==null) t.chargeRemaining *= this.tuning(t).demolition_prepare_seconds! / old.demolition_prepare_seconds;
    this.armed = null; this.actions.changed(t, old, true); return 'ok';
  }
  beginPlacement() {
    const t = this.current; if (!this.actions.acceptsInput() || !t) return;
    const tuning = this.tuning(t); this.armed = null;
    this.placement = tuning.has_demolition_charge ? 'charge' : tuning.has_engineer_obstacles ? 'obstacles' : tuning.melee ? 'rally' : null;
  }
  place(point: Point): boolean {
    const t = this.current, placement = this.placement;
    if (!this.actions.acceptsInput() || !t || !placement) return false;
    const tuning = this.tuning(t); let placed = false;
    if (placement === 'rally' && tuning.melee && distance(point, t.position) <= tuning.melee.rally_point_radius) {
      t.rally = rallyPoint(point, t.position, tuning.melee.rally_point_radius, this.content.routes); this.flash = t.rally; this.flashRemaining = 4;
      this.actions.changed(t, tuning, false); placed = true;
    } else if (placement !== 'rally' && inRange(point, t.position, tuning.tower_range, this.content.config.combat.range_vertical_fraction)) {
      const site = this.nearestSite(t, point, tuning);
      if (site) {
        if (placement === 'charge') {
          if(t.charge!==null&&!equal(t.charge,site))t.chargeRemaining=tuning.demolition_prepare_seconds!;
          t.charge = site;
        } else t.site = site;
        placed = true;
      }
    }
    this.dismiss(); return placed;
  }
  advance(seconds: number) {
    for(const tower of this.placed)tower.chargeRemaining=Math.max(0,tower.chargeRemaining-seconds);
    this.flashRemaining=Math.max(0,this.flashRemaining-seconds);if(this.flashRemaining===0)this.flash=null;
  }
  nearestSite(t: PlacedTower, p: Point, tuning: TowerTier) {
    return nearestRangePoint(p, t.position, tuning.tower_range, this.content.config.combat.range_vertical_fraction, this.content.routes);
  }
  get range(): { center: Point; radius: number; upgrade: number | null } | null {
    const t = this.current, slot = this.content.slots.find(s => s.index === this.selected);
    if (!slot) return null;
    const radius = (tier: TowerTier) => tier.melee?.rally_point_radius ?? tier.tower_range;
    let preview: TowerTier | undefined;
    if (!t) {
      const kind = this.content.towers.find(k => this.armed === `build:${k.tower_type_key}`)?.tower_type_key;
      if (kind && this.money >= this.cost(kind)) preview = this.meta.combat(this.base(kind), kind);
    } else {
      const offer = this.offers.find(o => this.armed === `tier:${o.branch}`);
      if (offer && this.money >= offer.cost) preview = this.meta.combat(offer.tier, t.kind);
      const path = this.paths.find(p => this.armed === `path:${p.id}`), rank = path?.ranks.find(r => r.rank === (t.ranks[path!.id] ?? 0) + 1);
      if (path && rank && this.money >= rank.cost) preview = this.meta.combat(upgraded(this.base(t.kind, t.level, t.branch), { ...t.ranks, [path.id]: rank.rank }), t.kind);
    }
    const current = t ? radius(this.tuning(t)) : 0, next = preview ? radius(preview) : 0;
    return current > 0 || next > 0 ? { center: slot, radius: current || next, upgrade: current && next && current !== next ? next : null } : null;
  }
}

function freezeTuning<T extends object>(value: T): T {
  for (const child of Object.values(value)) if (child !== null && typeof child === 'object') freezeTuning(child);
  return Object.freeze(value);
}

export function inRange(p: Point, origin: Point, radius: number, vertical: number) {
  return radius > 0 && Math.hypot(p.x - origin.x, (p.y - origin.y) / vertical) <= radius;
}
// Native TowerAttackRange clips segments analytically before finding the nearest point.
export function nearestRangePoint(p: Point, origin: Point, radius: number, vertical: number, routes: Route[]): Point | null {
  if (!(radius > 0) || !Number.isFinite(p.x + p.y)) return null;
  let best: Point | null = null, gap = Infinity;
  for (const route of routes) for (let i = 1; i < route.points.length; i++) {
    const a = route.points[i - 1]!, b = route.points[i]!, dx = b.x - a.x, dy = b.y - a.y;
    const x = a.x - origin.x, y = (a.y - origin.y) / vertical, sy = dy / vertical;
    const aa = dx * dx + sy * sy, bb = 2 * (x * dx + y * sy), cc = x * x + y * y - radius * radius;
    let lo = 0, hi = 1;
    if (aa === 0) { if (cc > 0) continue; }
    else { const discriminant = bb * bb - 4 * aa * cc; if (discriminant < 0) continue;
      lo = Math.max(0, (-bb - Math.sqrt(discriminant)) / (2 * aa)); hi = Math.min(1, (-bb + Math.sqrt(discriminant)) / (2 * aa)); if (lo > hi) continue; }
    let point = closest(p, lerp(a,b,lo), lerp(a,b,hi));
    const reach = Math.hypot(point.x - origin.x, (point.y - origin.y) / vertical);
    if (reach > radius) point = lerp(origin, point, radius / reach);
    const d = distance(p, point); if (d < gap) { best = point; gap = d; }
  }
  return best;
}
export function rallyPoint(requested: Point, origin: Point, radius: number, routes: Route[]): Point {
  let best = requested, gap = Infinity;
  for (const route of routes) for (let d = 0; d <= route.total; d += 12) {
    const point = route.point(d), candidate = distance(point, requested); if (candidate < gap) { gap = candidate; best = point; }
  }
  const reach = distance(origin, best); return reach > radius ? lerp(origin, best, radius / reach) : best;
}
