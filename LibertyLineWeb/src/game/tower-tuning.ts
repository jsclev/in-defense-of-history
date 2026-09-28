import type { MetaCatalog, PlayerState, TowerTier } from '../data/contracts';
import { records, type Row } from '../data/records';
import { contentError } from '../content/schema';
export type TowerKind = Row<'tower_type'>['tower_type_key'];
export class MetaEffects {
  constructor(private player: PlayerState, private readonly catalog: MetaCatalog) {}
  setPlayer(player: PlayerState) { this.player = player; }
  get selectionKey() { return this.player.meta.selections.filter(s => s.is_selected).map(s => s.upgrade_key).join(','); }
  value(key: Row<'meta_upgrade'>['upgrade_key'], parameter: string): number | undefined {
    if (!this.player.meta.selections.some(s => s.upgrade_key === key && s.is_selected)) return undefined;
    const value = this.catalog.upgrades.find(u => u.upgrade_key === key)?.effects.find(e => e.parameter === parameter)?.value;
    if (value === undefined) throw contentError(`meta_upgrade[${key}].${parameter}`, 'Missing selected effect');
    return value;
  }
  rangedDamage(kind: TowerKind, blocked: boolean, prepared: boolean) {
    if (kind !== 'ranged') return 1;
    return (blocked ? this.value('crossfire', 'damageMultiplier') ?? 1 : 1)
      * (prepared ? this.value('twoGoodVolleys', 'damageMultiplier') ?? 1 : 1);
  }
  fireLane(kind: TowerKind, inAbatis: boolean) {
    return inAbatis && (kind === 'ranged' || kind === 'areaOfEffect') ? this.value('preparedFireLanes', 'damageMultiplier') ?? 1 : 1;
  }
  meleeDamage(fraction: number) {
    const threshold = this.value('bayonetCounterstroke', 'moraleThreshold');
    return threshold !== undefined && fraction < threshold ? this.value('bayonetCounterstroke', 'damageMultiplier')! : 1;
  }
  batteryDamage(mode: TowerTier['attack_mode'], priorHits: number, fraction: number) {
    if (mode === 'solidShot' && priorHits > 0) return this.value('batteryDoctrine', 'secondaryHitMultiplier') ?? 1;
    const close = this.value('batteryDoctrine', 'closeRangeFraction');
    return mode === 'grapeshot' && close !== undefined && fraction <= close ? this.value('batteryDoctrine', 'closeRangeMultiplier')! : 1;
  }
  melee(base: Row<'melee_unit'>): Row<'melee_unit'> {
    const result = { ...base };
    const fields = { campaignVeterans: ['hp', 'healthMultiplier'], reliefCompanies: ['respawn_seconds', 'respawnMultiplier'],
      fieldDressings: ['heal_per_second', 'healingMultiplier'] } as const;
    for (const [key, [field, parameter]] of Object.entries(fields)) {
      const value = this.value(key as keyof typeof fields, parameter); if (value !== undefined) result[field] *= value;
    }
    return result;
  }
  cost(base: TowerTier, kind: TowerKind, trained: boolean, first: boolean, served: boolean) {
    let multiplier = 1;
    const apply = (key: Row<'meta_upgrade'>['upgrade_key'], applies: boolean) => {
      if (applies) { const value = this.value(key, 'priceMultiplier'); if (value !== undefined) multiplier *= value; }
    };
    apply('localSuppliers', kind === 'supply'); apply('artificerCorps', base.tower_level === 1);
    apply('modelCompany', base.tower_level >= 2 && base.tower_level <= 3 && trained);
    apply('frenchContracts', base.tower_level === 4 && first); apply('forwardMagazines', base.tower_level > 1 && served);
    return Math.ceil(base.cost * multiplier - 1e-9);
  }
  combat(base: TowerTier, kind: TowerKind): TowerTier {
    const t = structuredClone(base);
    const multiply = (key: Row<'meta_upgrade'>['upgrade_key'], parameter: string, fields: (keyof Pick<TowerTier,
      'tower_range' | 'fire_interval' | 'turn_rate_degrees' | 'terror_min' | 'terror_max' | 'shot_min_damage' | 'shot_max_damage' | 'support_heal_per_second'>)[]) => {
      const value = this.value(key, parameter); if (value !== undefined) for (const field of fields) t[field] *= value;
    };
    if (kind === 'ranged') { multiply('rangeEstimation', 'rangeMultiplier', ['tower_range']); multiply('cartridgeDrill', 'reloadMultiplier', ['fire_interval']); }
    if (kind === 'melee' && t.melee) t.melee = this.melee(t.melee);
    if (kind === 'areaOfEffect') {
      multiply('gunCarriages', 'turnMultiplier', ['turn_rate_degrees']); multiply('thunderousReport', 'moraleMultiplier', ['terror_min', 'terror_max']);
      multiply('ammunitionWagons', 'reloadMultiplier', ['fire_interval']);
      const pierce = this.value('batteryDoctrine', 'coverPierceFraction');
      if (t.attack_mode === 'shell' && pierce !== undefined) t.splash_cover_pierce += (1 - t.splash_cover_pierce) * pierce;
    }
    if (kind === 'special') {
      multiply('forwardWorks', 'rangeMultiplier', ['tower_range']);
      const size = this.value('forwardWorks', 'obstacleSizeMultiplier'), preparation = this.value('workingParties', 'preparationMultiplier');
      if (t.obstacle_radius !== null && size !== undefined) t.obstacle_radius *= size;
      if (t.demolition_prepare_seconds !== null && preparation !== undefined) t.demolition_prepare_seconds *= preparation;
      if (t.attack_mode === 'demolition') { multiply('powderWorks', 'damageMultiplier', ['shot_min_damage', 'shot_max_damage']); multiply('powderWorks', 'moraleMultiplier', ['terror_min', 'terror_max']); }
    }
    if (kind === 'supply') {
      const range = this.value('forwardMagazines', 'serviceRange'), income = this.value('supplyConvoys', 'incomeMultiplier');
      if (range !== undefined) t.tower_range = Math.max(t.tower_range, range);
      if (income !== undefined) t.income_per_wave = Math.floor(t.income_per_wave * income);
      if (t.support_heal_per_second > 0) { multiply('fieldHospitals', 'healingMultiplier', ['support_heal_per_second']); multiply('fieldHospitals', 'rangeMultiplier', ['tower_range']); }
    }
    return t;
  }
}

// Behavior identifiers mirror TowerUpgradeAttribute. Every delta comes from SQL.
export function upgraded(base: TowerTier, ranks: Readonly<Record<string, number>>): TowerTier {
  const t = structuredClone(base);
  if (Object.keys(ranks).some(id => !t.upgrades.some(p => p.id === id))) throw contentError(`tower[${base.id}].upgrades`, 'Unknown path');
  for (const path of t.upgrades) {
    const count = ranks[path.id] ?? 0; // Unpurchased battle state, not a content default.
    if (!Number.isInteger(count) || count < 0 || count > path.ranks.length) throw contentError(`tower_upgrade_path[${path.id}].rank`, 'Invalid purchased rank');
    for (const rank of path.ranks.slice(0, count)) {
      for (const effect of rank.effects_json) {
        const field: Partial<Record<typeof effect.attribute, keyof TowerTier>> = { range: 'tower_range', fireInterval: 'fire_interval',
          blastRadius: 'aoe_radius', coverPierce: 'splash_cover_pierce', turnRate: 'turn_rate_degrees', preparation: 'demolition_prepare_seconds',
          obstacleRadius: 'obstacle_radius', obstacleSlow: 'obstacle_slow_fraction', income: 'income_per_wave', supportSpeed: 'support_attack_speed_multiplier', supportHealing: 'support_heal_per_second' };
        const melee: Partial<Record<typeof effect.attribute, keyof Row<'melee_unit'>>> = { meleeAttack: 'attack_rating', meleeDefense: 'defense_rating',
          meleeHP: 'hp', meleeInterval: 'attack_interval', meleeRespawn: 'respawn_seconds', meleeHealing: 'heal_per_second', rallyRadius: 'rally_point_radius' };
        const invalid = () => { throw contentError(`tower_upgrade_rank[${path.id}:${rank.rank}].${effect.attribute}`, 'Incompatible capability or invalid combined tuning'); };
        const projectile = ['direct', 'shell', 'grapeshot', 'solidShot'].includes(t.attack_mode), aimed = ['shell', 'grapeshot', 'solidShot'].includes(t.attack_mode);
        if ((effect.attribute === 'fireInterval' && !projectile) || (effect.attribute === 'damage' && !projectile && !t.has_demolition_charge)
          || (['terror','turnRate'].includes(effect.attribute) && !aimed && !(effect.attribute === 'terror' && t.has_demolition_charge))
          || (['blastRadius','coverPierce'].includes(effect.attribute) && t.attack_mode !== 'shell' && !t.has_demolition_charge)) invalid();
        const target = field[effect.attribute], m = melee[effect.attribute];
        if (target) { if (typeof t[target] !== 'number') invalid(); const values = t as unknown as Record<string, number>; values[target] = values[target]! + effect.delta; }
        else if (m) { if (!t.melee) invalid(); const values = t.melee! as unknown as Record<string, number>; values[m] = values[m]! + effect.delta; }
        else if (effect.attribute === 'damage') { t.shot_min_damage += effect.delta; t.shot_max_damage += effect.delta; }
        else { t.terror_min += effect.delta; t.terror_max += effect.delta; }
        if ((projectile && t.fire_interval <= 0) || !records.tower.safeParse(t).success || (t.melee && !records.melee_unit.safeParse(t.melee).success)) invalid();
      }
    }
  }
  return t;
}
