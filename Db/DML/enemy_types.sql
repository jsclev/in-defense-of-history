-- Crown Forces enemy roster. This is the single source of truth for the
-- simulation, the in-game encyclopedia, and wave authoring.
-- Names and descriptions are display copy. All references use enemy_type_key
-- or id; image_name is explicit so a display-name edit cannot change artwork.
--
-- Columns: cover resists shot, discipline resists terror (1.0 == unbreakable),
-- hardiness resists contagion. break_band_lo/hi is the fraction-of-max-morale
-- band the per-unit Shaken threshold is sampled from. traits is a JSON array
-- decoded by EnemyTypeDAO into [Trait]; an empty roster entry uses '[]'.
--
-- Speed tiers (virtual units/sec): V.Slow 25, Slow 40, Med 60, Fast 85, V.Fast 120.
-- All enemies initially use the schema defaults: at <=40% morale, movement
-- speed and melee damage each become 2/3 of normal. The four morale_* fields
-- are independent per-enemy tuning; break_band remains the legacy routing band.
INSERT INTO enemy_type (
    id, enemy_type_key, enemy_type_name, enemy_type_description, image_name, max_hp, speed, cover, discipline, hardiness,
    damage_min, damage_max, bounty, lives_cost, break_band_lo, break_band_hi, traits
) VALUES
('c972308d-7313-45ae-8cb4-04d2d5b78046', 'loyalist_militia', 'Loyalist Militia', 'Lightly trained troops with fragile morale and modest staying power.', 'loyalist_militia', 50, 60, 0.35, 0.20, 0.30, 2, 4, 8, 1, 0.45, 0.65, '[{"type":"wavering"}]'),
('369e4cb5-38dc-4857-8701-e6c1320c52bc', 'regimental_drummer', 'Regimental Drummer', 'Restores nearby allies'' morale with a steady rallying beat.', 'regimental_drummer', 60, 60, 0.10, 0.55, 0.60, 0, 0, 20, 1, 0.35, 0.50, '[{"type":"rallyBeat","radius":90,"moralePerSecond":6}]'),
('86175b06-0f08-4407-bac0-0aa95cde3f52', 'redcoat_regular', 'Redcoat Regular', 'Disciplined line infantry with balanced speed and staying power.', 'redcoat_regular', 90, 60, 0.05, 0.60, 0.70, 4, 7, 15, 1, 0.30, 0.45, '[]'),
('59cffa58-a230-4b83-b6e4-00cd84175ad1', 'light_infantry', 'Light Infantry', 'Fast skirmishers whose cover helps them evade incoming fire.', 'light_infantry', 70, 85, 0.45, 0.50, 0.60, 3, 6, 18, 1, 0.30, 0.45, '[{"type":"skirmish"}]'),
('e8e182d1-c209-4cdd-8f8d-8d95de3fe167', 'hessian_jager', 'Hessian Jäger', 'Accurate riflemen combining strong cover with hard-hitting attacks.', 'hessian_jager', 65, 85, 0.55, 0.45, 0.55, 6, 9, 22, 1, 0.30, 0.45, '[{"type":"mercenary"},{"type":"marksman"}]'),
('7c014dae-5896-4b32-896e-f95555833e1e', 'hessian_fusilier', 'Hessian Fusilier', 'Sturdy German infantry that holds formation under pressure.', 'hessian_fusilier', 110, 60, 0.05, 0.70, 0.65, 5, 8, 20, 1, 0.28, 0.40, '[{"type":"mercenary"}]'),
('b3e0cd5e-0128-46eb-a2c3-fe193d728228', 'native_warrior', 'Native Warrior', 'Swift woodland fighters who use cover to close the distance.', 'native_warrior', 60, 120, 0.60, 0.35, 0.75, 5, 8, 20, 1, 0.35, 0.55, '[{"type":"skirmish"},{"type":"tag","name":"ambush"}]'),
('414fd1af-c633-4780-b513-b70f13018cd3', 'highlander', 'Highlander', 'Fast, hard-hitting infantry with the resolve to press the attack.', 'highlander', 130, 85, 0.10, 0.75, 0.75, 8, 12, 30, 1, 0.25, 0.35, '[{"type":"highlandCharge"}]'),
('ef3a782a-58db-4ac8-b372-0745a27669b0', 'light_dragoon', 'Light Dragoon', 'Fast cavalry that rides past blocking troops.', 'light_dragoon', 140, 120, 0.15, 0.65, 0.60, 7, 11, 35, 1, 0.28, 0.40, '[{"type":"rideDown"},{"type":"falter"}]'),
('9ba1961d-cb79-4e0b-a6cd-6806d115813e', 'spy', 'Spy', 'A lightly armed infiltrator with high cover and little staying power.', 'spy', 45, 85, 0.70, 0.40, 0.50, 1, 2, 25, 0, 0.35, 0.50, '[{"type":"disguised"},{"type":"saboteur"}]'),
('5392e3d1-c1c6-40d0-b54d-2be8aa4dc277', 'grenadier', 'Grenadier', 'Slow, tough assault infantry with powerful close-range attacks.', 'grenadier', 240, 40, 0.0, 0.85, 0.75, 10, 15, 45, 2, 0.22, 0.30, '[{"type":"steadyAdvance"}]'),
('f00dd278-0466-4bd5-b454-9c5a3dc964ec', 'royal_artillery', 'Royal Artillery', 'Slow-moving gun crews that trade speed for heavy damage.', 'royal_artillery', 300, 25, 0.10, 0.70, 0.65, 15, 25, 60, 2, 0.25, 0.35, '[{"type":"bombard"},{"type":"crewed"}]'),
(
    '48cf0732-a2a6-4271-b631-232a70c263ce', 'mounted_officer', 'Mounted Officer', 'Bolsters nearby allies'' discipline; losing him shakes their morale.', 'mounted_officer', 180, 85, 0.10, 0.90, 0.70, 6, 10, 50, 2, 0.20, 0.30,
    '[{"type":"commandAura","radius":120,"disciplineBonus":0.25,"deathShock":25}]'
),
('8dc553a0-c688-470d-ae0a-f2a0cfa04f45', 'foot_guards', 'Foot Guards', 'Elite infantry with exceptional toughness and unbreakable discipline.', 'foot_guards', 500, 40, 0.0, 1.0, 0.85, 12, 20, 75, 3, 0.15, 0.25, '[{"type":"steadyAdvance"},{"type":"tag","name":"unbreakable"}]');
