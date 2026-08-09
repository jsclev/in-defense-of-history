CREATE TABLE campaign (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    campaign_name TEXT NOT NULL,
    parent_campaign_id TEXT REFERENCES campaign (id)
);

CREATE TABLE enemy_type (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    enemy_type_name TEXT NOT NULL,
    max_hp REAL NOT NULL,
    speed REAL NOT NULL,
    cover REAL NOT NULL,
    discipline REAL NOT NULL,
    hardiness REAL NOT NULL,
    damage_min REAL NOT NULL,
    damage_max REAL NOT NULL,
    bounty INTEGER NOT NULL,
    lives_cost INTEGER NOT NULL DEFAULT 1,
    break_band_lo REAL NOT NULL,
    break_band_hi REAL NOT NULL,
    traits TEXT NOT NULL DEFAULT '[]'
);

CREATE TABLE tower_type (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    tower_type_category TEXT NOT NULL,
    tower_type_name TEXT NOT NULL
);

CREATE TABLE tower (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    tower_type_id TEXT NOT NULL REFERENCES tower_type (id),
    tower_name TEXT NOT NULL,
    tower_level INTEGER NOT NULL,
    branch INTEGER NOT NULL DEFAULT 1 CHECK (branch BETWEEN 1 AND 3),
    cost INTEGER NOT NULL,
    tower_range REAL NOT NULL,
    fire_interval REAL NOT NULL,
    shot_min_damage REAL NOT NULL DEFAULT 0,
    shot_max_damage REAL NOT NULL DEFAULT 0,
    terror_min REAL NOT NULL DEFAULT 0,
    terror_max REAL NOT NULL DEFAULT 0,
    aoe_radius REAL NOT NULL DEFAULT 0,
    aoe_falloff_exponent REAL NOT NULL DEFAULT 1.0 CHECK (aoe_falloff_exponent > 0),
    splash_cover_pierce REAL NOT NULL DEFAULT 0.0 CHECK (splash_cover_pierce BETWEEN 0.0 AND 1.0),
    contagion_chance REAL NOT NULL DEFAULT 0,
    targeting TEXT NOT NULL DEFAULT 'first',
    projectile_speed REAL NOT NULL DEFAULT 0 CHECK (projectile_speed >= 0),
    unit_count INTEGER NOT NULL DEFAULT 0 CHECK (unit_count >= 0),
    unit_hp REAL NOT NULL DEFAULT 0,
    unit_damage_min REAL NOT NULL DEFAULT 0,
    unit_damage_max REAL NOT NULL DEFAULT 0 CHECK (unit_damage_max >= unit_damage_min),
    unit_attack_interval REAL NOT NULL DEFAULT 0,
    unit_respawn_seconds REAL NOT NULL DEFAULT 0,
    unit_heal_per_second REAL NOT NULL DEFAULT 0
);

CREATE TABLE player_selected_hero (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    hero_id TEXT NOT NULL UNIQUE REFERENCES hero (id),
    selection_slot INTEGER NOT NULL UNIQUE CHECK (selection_slot BETWEEN 1 AND 2)
);

CREATE TABLE player_unlocked_hero (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    hero_id TEXT NOT NULL UNIQUE REFERENCES hero (id)
);

CREATE TABLE level_info (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    campaign_id TEXT NOT NULL REFERENCES campaign (id),
    level_name TEXT NOT NULL,
    world_map_x REAL NOT NULL,
    world_map_y REAL NOT NULL,
    started_at REAL NOT NULL,
    ended_at REAL NOT NULL,
    starting_money INTEGER NOT NULL CHECK (starting_money > 0),
    num_starting_lives INTEGER NOT NULL CHECK (num_starting_lives > 0),
    num_waves INTEGER NOT NULL DEFAULT 0 CHECK (num_waves >= 0),
    playable_rect_x REAL NOT NULL CHECK (playable_rect_x >= 0.0),
    playable_rect_y REAL NOT NULL CHECK (playable_rect_y >= 0.0),
    playable_rect_width REAL NOT NULL CHECK (playable_rect_width >= 0.0),
    playable_rect_height REAL NOT NULL CHECK (playable_rect_height >= 0.0),
    map_image_name TEXT NOT NULL DEFAULT '',
    map_image_width REAL NOT NULL DEFAULT 0.0 CHECK (map_image_width >= 0.0),
    map_image_height REAL NOT NULL DEFAULT 0.0 CHECK (map_image_height >= 0.0),
    CHECK (map_image_width = 0.0 OR playable_rect_x + playable_rect_width <= map_image_width),
    CHECK (map_image_height = 0.0 OR playable_rect_y + playable_rect_height <= map_image_height)
);

CREATE TABLE level_tower_unlock (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    level_info_id TEXT NOT NULL REFERENCES level_info (id),
    tower_kind TEXT NOT NULL,
    max_tower_level INTEGER NOT NULL CHECK (max_tower_level >= 1),
    UNIQUE (level_info_id, tower_kind)
);

CREATE TABLE level_path_point (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    level_info_id TEXT NOT NULL REFERENCES level_info (id),
    path_index INTEGER NOT NULL DEFAULT 0,
    point_index INTEGER NOT NULL,
    map_position_x REAL NOT NULL,
    map_position_y REAL NOT NULL,
    UNIQUE (level_info_id, path_index, point_index)
);

CREATE TABLE level_wave (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    level_info_id TEXT NOT NULL REFERENCES level_info (id),
    wave_index INTEGER NOT NULL CHECK (wave_index >= 1),
    spawn_time REAL NOT NULL,
    UNIQUE (level_info_id, wave_index)
);

CREATE TABLE level_wave_enemy_spawn (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    level_wave_id TEXT NOT NULL REFERENCES level_wave (id),
    enemy_type_id TEXT NOT NULL REFERENCES enemy_type (id),
    spawn_index INTEGER NOT NULL CHECK (spawn_index >= 0),
    num_enemies INTEGER NOT NULL CHECK (num_enemies >= 1),
    spawn_time_since_previous_spawn REAL NOT NULL CHECK (spawn_time_since_previous_spawn >= 0.0),
    spawn_interval REAL NOT NULL DEFAULT 0.8 CHECK (spawn_interval > 0.0),
    path_index INTEGER NOT NULL DEFAULT 0 CHECK (path_index >= 0),
    UNIQUE (level_wave_id, spawn_index, enemy_type_id)
);

CREATE TABLE tower_slot (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    level_info_id TEXT NOT NULL REFERENCES level_info (id),
    map_position_x REAL NOT NULL,
    map_position_y REAL NOT NULL
);

CREATE TABLE hero (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    short_name TEXT NOT NULL,
    long_name TEXT NOT NULL,
    nickname TEXT,
    unlocked_at_level_wave_id TEXT NOT NULL REFERENCES level_wave (id),
    general_description TEXT NOT NULL,
    historical_description TEXT NOT NULL,
    historical_text TEXT NOT NULL,
    primary_image_name TEXT NOT NULL,
    details_image_name TEXT NOT NULL
);

CREATE TABLE sim_enemy_type (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    enemy_type_id TEXT NOT NULL UNIQUE REFERENCES enemy_type (id),
    min_speed REAL NOT NULL CHECK (min_speed > 0),
    max_speed REAL NOT NULL CHECK (max_speed >= min_speed),
    min_hp REAL NOT NULL CHECK (min_hp > 0),
    max_hp REAL NOT NULL CHECK (max_hp >= min_hp)
);

CREATE TABLE sim_enemy_type_bounty (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    enemy_type_id TEXT NOT NULL UNIQUE REFERENCES enemy_type (id),
    min_bounty REAL NOT NULL CHECK (min_bounty >= 0),
    max_bounty REAL NOT NULL CHECK (max_bounty >= min_bounty)
);

CREATE TABLE sim_melee_unit (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    tower_id TEXT NOT NULL UNIQUE REFERENCES tower (id),
    min_hp REAL NOT NULL CHECK (min_hp > 0),
    max_hp REAL NOT NULL CHECK (max_hp >= min_hp),
    min_damage REAL NOT NULL CHECK (min_damage > 0),
    max_damage REAL NOT NULL CHECK (max_damage >= min_damage)
);

CREATE TABLE sim_stat_bounds (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    level_info_id TEXT REFERENCES level_info (id),
    tower_kind TEXT NOT NULL,
    stat TEXT NOT NULL,
    min_value REAL NOT NULL,
    max_value REAL NOT NULL CHECK (max_value >= min_value),
    derived_from TEXT NOT NULL DEFAULT '',
    UNIQUE (level_info_id, tower_kind, stat)
);
