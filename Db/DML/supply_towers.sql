-- Income pays once on wave start. Nearby auras use the strongest source.
-- Support never attacks or creates soldiers, obstacles or charges.
INSERT INTO tower (
    upgrade_path_count,     income_per_wave, support_attack_speed_multiplier, support_heal_per_second,
    id, tower_type_id, tower_name, tower_description, tower_level, branch, cost,
    attack_mode, turn_rate_degrees, has_melee_unit, has_demolition_charge,
    has_engineer_obstacles, tower_range, fire_interval, shot_min_damage,
    shot_max_damage, terror_min, terror_max, aoe_radius, aoe_falloff_exponent,
    splash_cover_pierce, contagion_chance, targeting, projectile_speed,
    demolition_prepare_seconds, obstacle_radius, obstacle_slow_fraction, obstacle_width_fraction
) VALUES
(0, 15, 1, 0, 'e6a89c04-b291-4f37-8ad2-0196f75c4301', '8cf674b2-397d-4a81-ae50-1d6c9427b035',
 'Supply Cart', 'Provides 15 coins whenever a wave begins.', 1, 1, 100,
 'none', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 'first', 0, NULL, NULL, NULL, NULL),
(0, 30, 1, 0, 'e6a89c04-b291-4f37-8ad2-0196f75c4302', '8cf674b2-397d-4a81-ae50-1d6c9427b035',
 'Supply Post', 'Provides 30 coins whenever a wave begins.', 2, 1, 150,
 'none', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 'first', 0, NULL, NULL, NULL, NULL),
(0, 50, 1, 0, 'e6a89c04-b291-4f37-8ad2-0196f75c4303', '8cf674b2-397d-4a81-ae50-1d6c9427b035',
 'Supply Camp', 'Provides 50 coins whenever a wave begins.', 3, 1, 220,
 'none', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 'first', 0, NULL, NULL, NULL, NULL),
(2, 100, 1, 0, 'e6a89c04-b291-4f37-8ad2-0196f75c4401', '8cf674b2-397d-4a81-ae50-1d6c9427b035',
 'Quartermaster''s Depot', 'Provides 100 coins whenever a wave begins.', 4, 1, 300,
 'none', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 'first', 0, NULL, NULL, NULL, NULL),
(2, 50, 1.25, 0, 'e6a89c04-b291-4f37-8ad2-0196f75c4402', '8cf674b2-397d-4a81-ae50-1d6c9427b035',
 'Ordnance Depot', 'Provides 50 coins per wave. Nearby ranged and artillery towers fire 25% faster. Overlapping depots do not stack.', 4, 2, 300,
 'none', 0, 0, 0, 0, 300, 0, 0, 0, 0, 0, 0, 1, 0, 0, 'first', 0, NULL, NULL, NULL, NULL),
(2, 50, 1, 8, 'e6a89c04-b291-4f37-8ad2-0196f75c4403', '8cf674b2-397d-4a81-ae50-1d6c9427b035',
 'Field Hospital', 'Provides 50 coins per wave. Heals nearby soldiers, reinforcements and heroes for 8 health per second, even in combat. Overlapping hospitals do not stack.', 4, 3, 300,
 'none', 0, 0, 0, 0, 300, 0, 0, 0, 0, 0, 0, 1, 0, 0, 'first', 0, NULL, NULL, NULL, NULL);
