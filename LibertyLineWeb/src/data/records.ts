import { z } from 'zod';
import { positive } from '../content/schema';

// Typed decoding contracts, corresponding to Swift's AuthoredRow/DAOs. These
// contain validation and behavior identifiers only, never replacement content.
const text = z.string().trim().min(1);
// Foundation UUID accepts the authored 128-bit UUID shape without RFC variant
// restrictions; some long-standing tower IDs use those non-RFC variant bits.
const id = z.guid();
const number = z.number().finite();
const nonnegative = number.nonnegative();
const integer = nonnegative.int();
const count = positive.int();
const fraction = nonnegative.max(1);
const flag = z.union([z.literal(0), z.literal(1)]);
const url = z.url({ protocol: /^https$/ }).refine(value => !/\s/.test(value), 'Expected HTTPS source URL');
const singleton = z.literal(1);
export const towerKind = z.enum(['ranged', 'melee', 'areaOfEffect', 'special', 'supply']);
export const enemyKind = z.enum(['loyalist_militia', 'regimental_drummer', 'redcoat_regular', 'light_infantry',
  'hessian_jager', 'hessian_fusilier', 'native_warrior', 'highlander', 'light_dragoon', 'spy', 'grenadier', 'royal_artillery',
  'mounted_officer', 'foot_guards']);
export const profileKey = z.enum(['active', 'level15']);
export const hudSection = z.enum(['hero_bar', 'stats_view', 'misc_view', 'master_controls']);
const hudCorner = z.enum(['north_west', 'north_east', 'south_west', 'south_east']);
export const metaTrack = z.enum(['marksmanship', 'infantry', 'artillery', 'engineering', 'supply', 'command']);
// Behavior contracts from MetaUpgrades.swift; all effect AMOUNTS come from SQL.
export const metaRequirements = {
  rangeEstimation: ['rangeMultiplier'], cartridgeDrill: ['reloadMultiplier'], crossfire: ['damageMultiplier'],
  twoGoodVolleys: ['damageMultiplier', 'shotCount', 'preparationSeconds'], campaignVeterans: ['healthMultiplier'],
  reliefCompanies: ['respawnMultiplier'], fieldDressings: ['healingMultiplier'], bayonetCounterstroke: ['damageMultiplier', 'moraleThreshold'],
  gunCarriages: ['turnMultiplier'], thunderousReport: ['moraleMultiplier'], ammunitionWagons: ['reloadMultiplier'],
  batteryDoctrine: ['secondaryHitMultiplier', 'closeRangeMultiplier', 'closeRangeFraction', 'coverPierceFraction'],
  forwardWorks: ['rangeMultiplier', 'obstacleSizeMultiplier'], preparedFireLanes: ['damageMultiplier'], workingParties: ['preparationMultiplier'],
  powderWorks: ['damageMultiplier', 'moraleMultiplier'], localSuppliers: ['priceMultiplier'], supplyConvoys: ['incomeMultiplier'],
  forwardMagazines: ['priceMultiplier', 'serviceRange'], fieldHospitals: ['healingMultiplier', 'rangeMultiplier'],
  artificerCorps: ['priceMultiplier'], modelCompany: ['priceMultiplier'], frenchContracts: ['priceMultiplier'],
} as const;
const metaKey = z.enum(Object.keys(metaRequirements) as [keyof typeof metaRequirements, ...(keyof typeof metaRequirements)[]]);
const metaParameter = z.enum([...new Set(Object.values(metaRequirements).flat())] as [string, ...string[]]);

function json<T extends z.ZodType>(schema: T) {
  return text.transform((value, ctx) => {
    try { return JSON.parse(value) as unknown; }
    catch { ctx.addIssue({ code: 'custom', message: 'Invalid JSON' }); return z.NEVER; }
  }).pipe(schema);
}
const trait = z.discriminatedUnion('type', [
  z.object({ type: z.enum(['wavering', 'mercenary', 'steadyAdvance', 'skirmish', 'marksman', 'saboteur',
    'disguised', 'tacticalWithdrawal', 'highlandCharge', 'rideDown', 'falter', 'bombard', 'crewed']) }),
  z.object({ type: z.literal('rallyBeat'), radius: positive, moralePerSecond: nonnegative }),
  z.object({ type: z.literal('commandAura'), radius: positive, disciplineBonus: fraction, deathShock: nonnegative }),
  z.object({ type: z.literal('tag'), name: text }),
]);
const upgradeAttribute = z.enum(['range', 'fireInterval', 'damage', 'terror', 'blastRadius', 'coverPierce', 'turnRate',
  'meleeAttack', 'meleeDefense', 'meleeHP', 'meleeInterval', 'meleeRespawn', 'meleeHealing', 'rallyRadius',
  'preparation', 'obstacleRadius', 'obstacleSlow', 'income', 'supportSpeed', 'supportHealing']);
const upgradeEffect = z.object({ attribute: upgradeAttribute, delta: number }).refine(effect =>
  ['fireInterval', 'meleeInterval', 'meleeRespawn', 'preparation'].includes(effect.attribute)
    ? effect.delta < 0 : effect.delta > 0, { path: ['delta'], message: 'Expected beneficial delta' });

// Field names stay aligned with the shared database; JSON fields are decoded.
export const records = {
  campaign: z.object({ id, campaign_name: text, parent_campaign_id: id.nullable() }),
  level_info: z.object({ id, campaign_id: id, level_name: text, world_map_x: number, world_map_y: number,
    started_at: positive, ended_at: positive, starting_money: integer, num_starting_lives: count,
    num_waves: integer, map_image_name: z.string() }),
  level_path_point: z.object({ id, level_info_id: id, path_index: integer, point_index: integer,
    map_position_x: number, map_position_y: number }),
  level_wave: z.object({ id, level_info_id: id, wave_index: count, spawn_time: nonnegative,
    call_button_delay: nonnegative, auto_start_countdown: nonnegative, early_call_bonus: integer }),
  level_wave_enemy_spawn: z.object({ id, level_wave_id: id, enemy_type_id: id, spawn_index: integer,
    num_enemies: count, spawn_time_since_previous_spawn: nonnegative, spawn_interval: nonnegative, path_index: integer }),
  level_hero: z.object({ id, level_info_id: id, hero_id: id, enemy_path_index: integer }),
  level_tower_unlock: z.object({ id, level_info_id: id, tower_kind: towerKind, max_tower_level: integer }),
  tower_type: z.object({ id, tower_type_key: towerKind, tower_type_category: text, tower_type_name: text,
    level_layout: json(z.array(z.array(count).min(1).refine(values => new Set(values).size === values.length,
      'Duplicate branch')).min(1)).refine(layout => JSON.stringify(layout[0]) === '[1]', 'First level requires branch 1') }),
  tower: z.object({ id, tower_type_id: id, tower_name: text, tower_description: text, tower_level: count,
    branch: count, cost: integer, tower_range: nonnegative, fire_interval: nonnegative, shot_min_damage: nonnegative,
    shot_max_damage: nonnegative, terror_min: nonnegative, terror_max: nonnegative, aoe_radius: nonnegative,
    aoe_falloff_exponent: positive, splash_cover_pierce: fraction, contagion_chance: fraction,
    targeting: z.enum(['first', 'last', 'strongest', 'shakiest']), projectile_speed: nonnegative,
    upgrade_path_count: integer, income_per_wave: integer, support_attack_speed_multiplier: number.min(1),
    support_heal_per_second: nonnegative,
    attack_mode: z.enum(['none', 'direct', 'shell', 'grapeshot', 'solidShot', 'melee', 'obstacles', 'demolition']),
    turn_rate_degrees: nonnegative, has_melee_unit: flag, has_demolition_charge: flag, has_engineer_obstacles: flag,
    demolition_prepare_seconds: positive.nullable(), obstacle_width_fraction: positive.max(1).nullable(),
    obstacle_radius: positive.nullable(), obstacle_slow_fraction: positive.lt(1).nullable(),
  }).refine(t => t.shot_max_damage >= t.shot_min_damage, { path: ['shot_max_damage'], message: 'Below minimum damage' })
    .refine(t => t.terror_max >= t.terror_min, { path: ['terror_max'], message: 'Below minimum terror' })
    .refine(t => Boolean(t.has_demolition_charge) === (t.demolition_prepare_seconds !== null),
      { path: ['demolition_prepare_seconds'], message: 'Must match has_demolition_charge' })
    .refine(t => [t.obstacle_radius, t.obstacle_width_fraction, t.obstacle_slow_fraction].every(v => Boolean(t.has_engineer_obstacles) === (v !== null)),
      { path: ['has_engineer_obstacles'], message: 'Obstacle fields must match capability' })
    .refine(t => t.attack_mode !== 'none' || !(t.has_melee_unit || t.has_demolition_charge || t.has_engineer_obstacles),
      { path: ['attack_mode'], message: 'None requires all combat capabilities disabled' })
    .refine(t => !['shell', 'grapeshot', 'solidShot'].includes(t.attack_mode) || t.turn_rate_degrees > 0,
      { path: ['turn_rate_degrees'], message: 'Aimed artillery requires positive turn rate' })
    .refine(t => t.tower_range > 0 || (t.attack_mode === 'none' && t.support_attack_speed_multiplier === 1 && t.support_heal_per_second === 0),
      { path: ['tower_range'], message: 'Attack or support aura requires positive range' }),
  tower_history: z.object({ tower_id: id, historical_description: text, source_title: text, source_url: url,
    presentation_kind: z.enum(['standard', 'mortarStudy', 'siegeStudy']), strategy_text: text.nullable(), inclusion_reason: text.nullable(),
  }).refine(h => [h.strategy_text, h.inclusion_reason].every(v => (h.presentation_kind === 'standard') === (v === null)),
    { path: ['presentation_kind'], message: 'Guide fields must match presentation kind' }),
  tower_upgrade_path: z.object({ id: text, tower_id: id, slot: count.max(2), path_name: text,
    path_description: text, icon_name: text, historical_basis: text, source_url: url, rank_count: count.min(2) }),
  tower_upgrade_rank: z.object({ path_id: text, rank: count, cost: count, rank_description: text,
    effects_json: json(z.array(upgradeEffect).min(1).refine(effects => new Set(effects.map(e => e.attribute)).size === effects.length,
      'Duplicate upgrade attribute')) }),
  melee_unit: z.object({ id, tower_id: id, soldier_count: count.max(4), attack_rating: positive, defense_rating: fraction.lt(1),
    hp: positive, rally_point_radius: positive, attack_interval: positive, respawn_seconds: positive, heal_per_second: nonnegative }),
  enemy_type: z.object({ id, enemy_type_key: enemyKind, enemy_type_name: text, enemy_type_description: text, image_name: text,
    max_hp: positive, speed: nonnegative, cover: fraction, discipline: fraction, hardiness: fraction, damage_min: nonnegative,
    damage_max: nonnegative, bounty: integer, lives_cost: integer, break_band_lo: fraction, break_band_hi: fraction,
    traits: json(z.array(trait)), morale_speed_threshold: fraction, morale_attack_threshold: fraction,
    morale_speed_multiplier: fraction, morale_attack_multiplier: fraction,
  }).refine(e => e.damage_max >= e.damage_min, { path: ['damage_max'], message: 'Below minimum damage' })
    .refine(e => e.break_band_hi >= e.break_band_lo, { path: ['break_band_hi'], message: 'Below lower break band' }),
  enemy_encyclopedia: z.object({ enemy_type_id: id, strategy_text: text, historical_description: text,
    inclusion_reason: text, adaptation_text: text, source_title: text, source_url: url }),
  hero: z.object({ id, short_name: text, long_name: text, ranking: count.max(100), nickname: text.nullable(),
    unlocked_at_level_wave_id: id, general_description: text, historical_description: text, historical_text: text,
    primary_image_name: text, icon_image_name: text, ability_icon_image_name: text, unit_image_name: text }),
  hero_combat: z.object({ id, hero_id: id, attack_rating: positive, defense_rating: fraction.lt(1), hp: positive,
    attack_interval: positive, respawn_seconds: positive, heal_per_second: nonnegative, move_speed: positive }),
  hero_ai: z.object({ hero_id: id, controller: z.enum(['israel_putnam', 'henry_knox', 'louis_duportail', 'george_washington',
    'mary_hays', 'daniel_morgan', 'benedict_arnold', 'friedrich_von_steuben', 'francis_marion', 'nathanael_greene',
    'william_prescott', 'thaddeus_kosciuszko', 'salem_poor', 'john_glover', 'horatio_gates']),
    decision_interval: positive.max(60), retreat_health_fraction: positive.max(1), resume_health_fraction: positive.max(1),
  }).refine(a => a.resume_health_fraction > a.retreat_health_fraction,
    { path: ['resume_health_fraction'], message: 'Must exceed retreat threshold' }),
  difficulty: z.object({ id, difficulty_level: count.max(4), difficulty_name: text, difficulty_description: text, enemy_hp_multiplier: positive }),
  player_settings: z.object({ id: singleton, debug_mode: flag, show_debug_info: flag, show_debug_layout_guides: flag,
    enemy_escape_haptics_enabled: flag, show_ga_solution_button: flag }),
  player_selected_difficulty: z.object({ id, difficulty_id: id, selection_slot: singleton }),
  player_selected_hero: z.object({ id, hero_id: id, selection_slot: count.max(2) }),
  player_unlocked_hero: z.object({ id, hero_id: id }),
  player_hero_control: z.object({ hero_id: id, ai_enabled: flag }),
  player_hud_layout: z.object({ id, hud_section_name: hudSection, hud_location_name: hudCorner }),
  reinforcement_config: z.object({ id: singleton, time_to_live_seconds: positive, cooldown_seconds: positive }),
  play_speed: z.object({ source: z.enum(['player', 'simulator', 'editor']), factor: number.min(0.01).max(1_000_000_000) }),
  encyclopedia_demo: z.object({ id: singleton, context_level_id: id, starting_money: integer }),
  virtual_canvas: z.object({ id, canvas_width: positive, canvas_height: positive,
    play_area_x: nonnegative, play_area_y: nonnegative, play_area_width: positive, play_area_height: positive,
    slot_width: positive, slot_height: positive, path_width: positive, tower_menu_total_width: positive, tower_menu_total_height: positive,
    stats_view_width_fraction: positive.max(1), stats_view_height_fraction: positive.max(1),
    master_controls_width_fraction: positive.max(1), master_controls_height_fraction: positive.max(1),
    hero_bar_width_fraction: positive.max(1), hero_bar_height_fraction: positive.max(1),
    misc_view_width_fraction: positive.max(1), misc_view_height_fraction: positive.max(1),
  }).refine(c => c.play_area_x + c.play_area_width <= c.canvas_width && c.play_area_y + c.play_area_height <= c.canvas_height,
    { path: ['play_area_width'], message: 'Play area must fit inside canvas' }),
  combat_rules: z.object({ id: singleton, kill_bounty_multiplier: nonnegative, rout_bounty_multiplier: nonnegative,
    capture_bounty_multiplier: nonnegative, morale_max: positive, base_morale_regen_per_second: positive,
    break_morale_splash: nonnegative, break_splash_radius: positive, wavering_splash_multiplier: nonnegative,
    shaken_speed_multiplier: fraction, rout_speed_multiplier: positive, steady_advance_hp_gate: fraction,
    contagion_tick_interval: positive, disease_hp_per_second: nonnegative, disease_hp_floor_fraction: fraction,
    disease_morale_per_second: nonnegative, contagion_spread_radius: positive, contagion_spread_chance: fraction,
    melee_attack_spread: fraction, melee_move_speed: positive, melee_engage_scan_radius_fraction: positive.max(1),
    melee_reach: positive, melee_combat_spacing: positive, melee_leash_radius_fraction: positive.max(1), enemy_swing_interval: positive,
    hero_engage_scan_radius: positive, hero_leash_radius: positive, melee_post_spread: nonnegative, melee_spawn_spread: nonnegative,
    arrival_radius: positive, range_vertical_fraction: positive.max(1), projectile_hit_radius: positive, grapeshot_hit_radius: positive,
    solid_shot_hit_radius: positive, firing_tolerance_degrees: positive.max(180), initial_heading_degrees: number.min(-180).max(180),
    enemy_body_offset_x: number.min(-1_000_000), enemy_body_offset_y: number.min(-1_000_000), morale_visibility_threshold: nonnegative,
    morale_response_duration: positive, morale_recovery_delay: nonnegative, morale_display_duration: positive,
    reinforcement_soldier_count: count, grapeshot_spread_degrees: json(z.array(number.min(-180).max(180)).min(1)
      .refine(values => new Set(values).size === values.length, 'Duplicate grapeshot angle')),
  }).refine(r => r.morale_visibility_threshold <= r.morale_max,
    { path: ['morale_visibility_threshold'], message: 'Exceeds morale maximum' }),
  meta_upgrade_track: z.object({ track_key: metaTrack,
    title: text, short_title: text, display_order: count }),
  meta_upgrade: z.object({ upgrade_key: metaKey, track_key: metaTrack, display_order: count, star_cost: count.max(1000),
    prerequisite_key: metaKey.nullable(), title: text, description: text, icon_name: text.regex(/^[a-z][a-z0-9_]*$/),
    historical_information: text, source_title: text, source_url: url }),
  meta_upgrade_effect: z.object({ upgrade_key: metaKey, parameter: metaParameter, value: positive }).refine(effect => {
    if (effect.parameter === 'shotCount') return Number.isInteger(effect.value) && effect.value <= 10;
    if (effect.parameter === 'preparationSeconds') return effect.value <= 120;
    if (effect.parameter === 'serviceRange') return effect.value <= 10000;
    if (['reloadMultiplier', 'respawnMultiplier', 'preparationMultiplier', 'priceMultiplier', 'moraleThreshold',
      'closeRangeFraction', 'coverPierceFraction'].includes(effect.parameter)) return effect.value < 1;
    return effect.value > 1 && effect.value <= 5;
  }, { path: ['value'], message: 'Outside supported effect bounds' }),
  player_meta_upgrade_profile: z.object({ profile_key: profileKey }),
  player_meta_upgrade_selection: z.object({ profile_key: profileKey, upgrade_key: metaKey, is_selected: flag }),
  player_meta_upgrade_level_stars: z.object({ profile_key: profileKey, level_info_id: id, best_stars: integer.max(3) }),
} as const;
export type Table = keyof typeof records;
export type Row<K extends Table> = z.output<(typeof records)[K]>;
export type Level = Row<'level_info'> & { campaign_name: string };
export type Canvas = Pick<Row<'virtual_canvas'>, 'canvas_width' | 'canvas_height' | 'play_area_x' | 'play_area_y' |
  'play_area_width' | 'play_area_height' | 'slot_width' | 'slot_height'>;
