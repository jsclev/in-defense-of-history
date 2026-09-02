-- Ranged Level 1 (Musketmen)
INSERT INTO tower (
    id, tower_type_id, tower_name,
    tower_level, branch, cost, tower_range, fire_interval,
    shot_min_damage, shot_max_damage, projectile_speed
) VALUES (
    '0a4b1c62-8f3e-4d97-b120-6e5a9c8d7f01', '7a10c1de-4b71-4f3d-9d34-5b7f1a2c9e01', 'Musketmen',
    1, 1, 70, 198.0, 0.8,
    12.0, 12.0, 550.0
);

-- Ranged Level 2 (Marksmen)
INSERT INTO tower (
    id, tower_type_id, tower_name,
    tower_level, branch, cost, tower_range, fire_interval,
    shot_min_damage, shot_max_damage, projectile_speed
) VALUES (
    '1b5c2d73-9a4f-4ea8-8c31-7f6b0d9e8a02', '7a10c1de-4b71-4f3d-9d34-5b7f1a2c9e01', 'Marksmen',
    2, 1, 90, 231.0, 0.8,
    20.0, 20.0, 550.0
);

-- Ranged Level 3 (Riflemen)
INSERT INTO tower (
    id, tower_type_id, tower_name,
    tower_level, branch, cost, tower_range, fire_interval,
    shot_min_damage, shot_max_damage, projectile_speed
) VALUES (
    '2c6d3e84-0b5a-4fb9-9d42-8a7c1e0f9b03', '7a10c1de-4b71-4f3d-9d34-5b7f1a2c9e01', 'Riflemen',
    3, 1, 130, 264.0, 0.8,
    30.0, 30.0, 550.0
);

-- Ranged Level 4 (Morgan's Sharpshooters)
INSERT INTO tower (
    id, tower_type_id, tower_name,
    tower_level, branch, cost, tower_range, fire_interval,
    shot_min_damage, shot_max_damage, projectile_speed
) VALUES (
    '1008b722-563a-44a0-8b31-c9cca93b9927', '7a10c1de-4b71-4f3d-9d34-5b7f1a2c9e01', 'Morgan''s Sharpshooters',
    4, 1, 300, 275.0, 0.8,
    30.0, 30.0, 550.0
);

-- Ranged Level 4 (Knowlton's Rangers)
INSERT INTO tower (
    id, tower_type_id, tower_name,
    tower_level, branch, cost, tower_range, fire_interval,
    shot_min_damage, shot_max_damage, projectile_speed
) VALUES (
    '72788425-7677-418a-a06c-6b3120f94631', '7a10c1de-4b71-4f3d-9d34-5b7f1a2c9e01', 'Knowlton''s Rangers',
    4, 2, 300, 275.0, 0.8,
    30.0, 30.0, 550.0
);

-- Ranged Level 4 (Whitcomb's Rangers)
INSERT INTO tower (
    id, tower_type_id, tower_name,
    tower_level, branch, cost, tower_range, fire_interval,
    shot_min_damage, shot_max_damage, projectile_speed
) VALUES (
    'c5cc2d7b-b08c-4ba7-a532-52ba070589a5', '7a10c1de-4b71-4f3d-9d34-5b7f1a2c9e01', 'Whitcomb''s Rangers',
    4, 3, 300, 275.0, 0.8,
    30.0, 30.0, 550.0
);

-- Melee soldier stats live in melee_unit (melee_units.sql), keyed by tower id.

-- Melee Level 1 (Militia)
INSERT INTO tower (
    id, tower_type_id, tower_name,
    tower_level, branch, cost, tower_range, fire_interval
) VALUES (
    '3d7e4f95-1c6b-4ac0-ae53-9b8d2f1a0c04', '2f8e6b93-0c5a-4d18-8a67-1e94d3c7ab02', 'Militia',
    1, 1, 70, 259.2, 0.0
);

-- Melee Level 2 (Minutemen)
INSERT INTO tower (
    id, tower_type_id, tower_name,
    tower_level, branch, cost, tower_range, fire_interval
) VALUES (
    '4e8f5a06-2d7c-4bd1-bf64-0c9e3a2b1d05', '2f8e6b93-0c5a-4d18-8a67-1e94d3c7ab02', 'Minutemen',
    2, 1, 120, 259.2, 0.0
);

-- Melee Level 3 (Continental Line)
INSERT INTO tower (
    id, tower_type_id, tower_name,
    tower_level, branch, cost, tower_range, fire_interval
) VALUES (
    '5f9a6b17-3e8d-4ce2-c075-1d0f4b3c2e06', '2f8e6b93-0c5a-4d18-8a67-1e94d3c7ab02', 'Continental Line',
    3, 1, 170, 259.2, 0.0
);

-- Melee Level 4 (Continental Regulars)
INSERT INTO tower (
    id, tower_type_id, tower_name,
    tower_level, branch, cost, tower_range, fire_interval
) VALUES (
    '9c1aa74b-b783-4fc1-b9c3-daeaf5284146', '2f8e6b93-0c5a-4d18-8a67-1e94d3c7ab02', 'Continental Regulars',
    4, 1, 300, 259.2, 0.0
);

-- Melee Level 4 (Continental Light Infantry)
INSERT INTO tower (
    id, tower_type_id, tower_name,
    tower_level, branch, cost, tower_range, fire_interval
) VALUES (
    '634b9957-dce1-4b53-8665-1017904ad89d', '2f8e6b93-0c5a-4d18-8a67-1e94d3c7ab02', 'Continental Light Infantry',
    4, 2, 300, 259.2, 0.0
);

-- Melee Level 4 (Maryland Line)
INSERT INTO tower (
    id, tower_type_id, tower_name,
    tower_level, branch, cost, tower_range, fire_interval
) VALUES (
    '550638ec-0f26-4329-9719-2d3f2e697238', '2f8e6b93-0c5a-4d18-8a67-1e94d3c7ab02', 'Maryland Line',
    4, 3, 300, 259.2, 0.0
);

-- Area of Effect Level 1 (4-pounder)
INSERT INTO tower (
    id, tower_type_id, tower_name,
    tower_level, branch, cost, tower_range, fire_interval,
    shot_min_damage, shot_max_damage, aoe_radius, splash_cover_pierce, projectile_speed
) VALUES (
    '6a0b7c28-4f9e-4df3-d186-2e1a5c4d3f07', 'c94d7f21-6e38-4b0a-b152-8d06a5e9fc03', '4-pounder',
    1, 1, 125, 240.0, 2.4,
    12.0, 24.0, 95.0, 0.5, 320.0
);

-- Area of Effect Level 2 (6-pounder)
INSERT INTO tower (
    id, tower_type_id, tower_name,
    tower_level, branch, cost, tower_range, fire_interval,
    shot_min_damage, shot_max_damage, aoe_radius, splash_cover_pierce, projectile_speed
) VALUES (
    '7b1c8d39-5a0f-4ea4-e297-3f2b6d5e4a08', 'c94d7f21-6e38-4b0a-b152-8d06a5e9fc03', '6-pounder',
    2, 1, 160, 240.0, 2.4,
    19.0, 37.0, 95.0, 0.5, 320.0
);

-- Area of Effect Level 3 (Howitzer)
INSERT INTO tower (
    id, tower_type_id, tower_name,
    tower_level, branch, cost, tower_range, fire_interval,
    shot_min_damage, shot_max_damage, aoe_radius, splash_cover_pierce, projectile_speed
) VALUES (
    '8c2d9e40-6b1a-4fb5-f3a8-4a3c7e6f5b09', 'c94d7f21-6e38-4b0a-b152-8d06a5e9fc03', 'Howitzer',
    3, 1, 240, 270.0, 2.4,
    27.0, 53.0, 99.0, 0.5, 320.0
);

-- Area of Effect Level 4 (Mortar Battery)
INSERT INTO tower (
    id, tower_type_id, tower_name,
    tower_level, branch, cost, tower_range, fire_interval,
    shot_min_damage, shot_max_damage, aoe_radius, splash_cover_pierce, projectile_speed
) VALUES (
    'f614aea2-b5cb-4cd3-a30d-e33a02c27c90', 'c94d7f21-6e38-4b0a-b152-8d06a5e9fc03', 'Mortar Battery',
    4, 1, 300, 300.0, 2.4,
    27.0, 53.0, 99.0, 0.5, 320.0
);

-- Area of Effect Level 4 (Mobile Field Battery)
INSERT INTO tower (
    id, tower_type_id, tower_name,
    tower_level, branch, cost, tower_range, fire_interval,
    shot_min_damage, shot_max_damage, aoe_radius, splash_cover_pierce, projectile_speed
) VALUES (
    '01b02f93-d2ff-4754-9072-35a1aa65cd6d', 'c94d7f21-6e38-4b0a-b152-8d06a5e9fc03', 'Mobile Field Battery',
    4, 2, 300, 300.0, 2.4,
    27.0, 53.0, 99.0, 0.5, 320.0
);

-- Area of Effect Level 4 (Knox's Siege Guns)
INSERT INTO tower (
    id, tower_type_id, tower_name,
    tower_level, branch, cost, tower_range, fire_interval,
    shot_min_damage, shot_max_damage, aoe_radius, splash_cover_pierce, projectile_speed
) VALUES (
    '0a0648b8-9771-45f5-b947-46c5a478062d', 'c94d7f21-6e38-4b0a-b152-8d06a5e9fc03', 'Knox''s Siege Guns',
    4, 3, 300, 300.0, 2.4,
    27.0, 53.0, 99.0, 0.5, 320.0
);

-- Special Level 1 (Engineer Post)
INSERT INTO tower (
    id, tower_type_id, tower_name,
    tower_level, branch, cost, tower_range, fire_interval
) VALUES (
    '9d3e0f51-7c2b-4ac6-a4b9-5b4d8f7a6c10', '5b3a9e87-1d64-4c29-9f80-3c72b6d4ea04', 'Engineer Post',
    1, 1, 100, 210.0, 1.2
);

-- Special Level 2 (Field Engineers)
INSERT INTO tower (
    id, tower_type_id, tower_name,
    tower_level, branch, cost, tower_range, fire_interval
) VALUES (
    '0e4f1a62-8d3c-4bd7-b5c0-6c5e9a8b7d11', '5b3a9e87-1d64-4c29-9f80-3c72b6d4ea04', 'Field Engineers',
    2, 1, 150, 240.0, 1.2
);

-- Special Level 3 (Sappers)
INSERT INTO tower (
    id, tower_type_id, tower_name,
    tower_level, branch, cost, tower_range, fire_interval
) VALUES (
    '1f5a2b73-9e4d-4ce8-c6d1-7d6f0b9c8e12', '5b3a9e87-1d64-4c29-9f80-3c72b6d4ea04', 'Sappers',
    3, 1, 220, 270.0, 1.2
);

-- Special Level 4 (Demolition Sappers)
INSERT INTO tower (
    id, tower_type_id, tower_name,
    tower_level, branch, cost, tower_range, fire_interval
) VALUES (
    'fa950e72-3c9c-420a-ab60-b40cb41407cf', '5b3a9e87-1d64-4c29-9f80-3c72b6d4ea04', 'Demolition Sappers',
    4, 1, 300, 300.0, 1.2
);

-- Special Level 4 (Fieldworks Corp)
INSERT INTO tower (
    id, tower_type_id, tower_name,
    tower_level, branch, cost, tower_range, fire_interval
) VALUES (
    '01b5f5d5-5472-4dbd-be95-9089af603422', '5b3a9e87-1d64-4c29-9f80-3c72b6d4ea04', 'Fieldworks Corp',
    4, 2, 300, 300.0, 1.2
);

-- Special Level 4 (Corps of Miners)
INSERT INTO tower (
    id, tower_type_id, tower_name,
    tower_level, branch, cost, tower_range, fire_interval
) VALUES (
    '44c58827-2c6c-4ec4-a2f2-43473908aee8', '5b3a9e87-1d64-4c29-9f80-3c72b6d4ea04', 'Corps of Miners',
    4, 3, 300, 300.0, 1.2
);
