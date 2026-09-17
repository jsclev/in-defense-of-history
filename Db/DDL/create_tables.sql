CREATE TABLE campaign (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    campaign_name TEXT NOT NULL,
    parent_campaign_id TEXT REFERENCES campaign (id)
);

CREATE TABLE enemy_type (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    enemy_type_key TEXT NOT NULL UNIQUE CHECK (LENGTH(TRIM(enemy_type_key)) > 0),
    enemy_type_name TEXT NOT NULL UNIQUE CHECK (LENGTH(TRIM(enemy_type_name)) > 0),
    enemy_type_description TEXT NOT NULL CHECK (LENGTH(TRIM(enemy_type_description)) > 0),
    image_name TEXT NOT NULL CHECK (LENGTH(TRIM(image_name)) > 0),
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
    traits TEXT NOT NULL DEFAULT '[]',
    morale_speed_threshold REAL NOT NULL DEFAULT 0.4 CHECK (morale_speed_threshold BETWEEN 0 AND 1),
    morale_attack_threshold REAL NOT NULL DEFAULT 0.4 CHECK (morale_attack_threshold BETWEEN 0 AND 1),
    morale_speed_multiplier REAL NOT NULL DEFAULT (2.0 / 3.0) CHECK (morale_speed_multiplier BETWEEN 0 AND 1),
    morale_attack_multiplier REAL NOT NULL DEFAULT (2.0 / 3.0) CHECK (morale_attack_multiplier BETWEEN 0 AND 1)
);

CREATE TABLE design_emplacement (
    emplacement_key TEXT PRIMARY KEY,
    tower_name TEXT NOT NULL CHECK (length(trim(tower_name)) > 0),
    short_name TEXT NOT NULL CHECK (length(trim(short_name)) > 0),
    level_count INTEGER NOT NULL CHECK (level_count > 0)
);

CREATE TABLE design_emplacement_level (
    has_melee_unit INTEGER NOT NULL CHECK (has_melee_unit IN (0, 1)),
    has_demolition_charge INTEGER NOT NULL CHECK (has_demolition_charge IN (0, 1)),
    has_engineer_obstacles INTEGER NOT NULL CHECK (has_engineer_obstacles IN (0, 1)),
    emplacement_key TEXT NOT NULL REFERENCES design_emplacement (emplacement_key),
    tower_level INTEGER NOT NULL CHECK (tower_level > 0),
    cost INTEGER NOT NULL CHECK (cost >= 0),
    tower_range REAL NOT NULL CHECK (tower_range > 0),
    fire_interval REAL NOT NULL CHECK (fire_interval >= 0),
    shot_min_damage REAL NOT NULL CHECK (shot_min_damage >= 0),
    shot_max_damage REAL NOT NULL CHECK (shot_max_damage >= shot_min_damage),
    terror_min REAL NOT NULL CHECK (terror_min >= 0),
    terror_max REAL NOT NULL CHECK (terror_max >= terror_min),
    aoe_radius REAL NOT NULL CHECK (aoe_radius >= 0),
    aoe_falloff_exponent REAL NOT NULL CHECK (aoe_falloff_exponent > 0),
    splash_cover_pierce REAL NOT NULL CHECK (splash_cover_pierce BETWEEN 0 AND 1),
    contagion_chance REAL NOT NULL CHECK (contagion_chance BETWEEN 0 AND 1),
    targeting TEXT NOT NULL CHECK (targeting IN ('first', 'last', 'strongest', 'shakiest')),
    projectile_speed REAL NOT NULL CHECK (projectile_speed >= 0),
    demolition_prepare_seconds REAL CHECK (demolition_prepare_seconds IS NULL OR demolition_prepare_seconds > 0),
    obstacle_radius REAL CHECK (obstacle_radius IS NULL OR obstacle_radius > 0),
    obstacle_slow_fraction REAL CHECK (obstacle_slow_fraction IS NULL OR
        (obstacle_slow_fraction > 0 AND obstacle_slow_fraction < 1)),
    PRIMARY KEY (emplacement_key, tower_level),
    CHECK ((obstacle_radius IS NULL) = (obstacle_slow_fraction IS NULL)),
    CHECK ((demolition_prepare_seconds IS NOT NULL) = has_demolition_charge),
    CHECK ((obstacle_radius IS NOT NULL) = has_engineer_obstacles)
);

CREATE TABLE tower_type (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    tower_type_category TEXT NOT NULL,
    tower_type_name TEXT NOT NULL,
    level_layout TEXT NOT NULL CHECK (json_valid(level_layout))
);

CREATE TABLE tower (
    has_melee_unit INTEGER NOT NULL CHECK (has_melee_unit IN (0, 1)),
    has_demolition_charge INTEGER NOT NULL CHECK (has_demolition_charge IN (0, 1)),
    has_engineer_obstacles INTEGER NOT NULL CHECK (has_engineer_obstacles IN (0, 1)),
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    tower_type_id TEXT NOT NULL REFERENCES tower_type (id),
    tower_name TEXT NOT NULL,
    tower_description TEXT NOT NULL CHECK (LENGTH(TRIM(tower_description)) > 0),
    tower_level INTEGER NOT NULL,
    branch INTEGER NOT NULL CHECK (branch BETWEEN 1 AND 4),
    cost INTEGER NOT NULL,
    tower_range REAL NOT NULL,
    fire_interval REAL NOT NULL,
    shot_min_damage REAL NOT NULL,
    shot_max_damage REAL NOT NULL,
    terror_min REAL NOT NULL,
    terror_max REAL NOT NULL,
    aoe_radius REAL NOT NULL,
    aoe_falloff_exponent REAL NOT NULL CHECK (aoe_falloff_exponent > 0),
    splash_cover_pierce REAL NOT NULL CHECK (splash_cover_pierce BETWEEN 0.0 AND 1.0),
    contagion_chance REAL NOT NULL,
    targeting TEXT NOT NULL,
    projectile_speed REAL NOT NULL CHECK (projectile_speed >= 0),
    demolition_prepare_seconds REAL
        CHECK (demolition_prepare_seconds IS NULL OR demolition_prepare_seconds > 0),
    obstacle_radius REAL CHECK (obstacle_radius IS NULL OR obstacle_radius > 0),
    obstacle_slow_fraction REAL CHECK (obstacle_slow_fraction IS NULL OR
        (obstacle_slow_fraction > 0 AND obstacle_slow_fraction < 1)),
    CHECK ((obstacle_radius IS NULL) = (obstacle_slow_fraction IS NULL)),
    CHECK ((demolition_prepare_seconds IS NOT NULL) = has_demolition_charge),
    CHECK ((obstacle_radius IS NOT NULL) = has_engineer_obstacles)
);

-- attack_rating is the soldier's average swing damage; the engine rolls a
-- fixed band around it. defense_rating is the fraction of incoming damage
-- the soldier turns away.
CREATE TABLE melee_unit (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    tower_id TEXT NOT NULL UNIQUE REFERENCES tower (id),
    -- Capped at 4: the GPU simulator packs 4 soldier slots per tower
    -- (SIM_MAX_MELEE_UNITS_PER) and rejects catalogs above it.
    soldier_count INTEGER NOT NULL CHECK (soldier_count BETWEEN 1 AND 4),
    attack_rating REAL NOT NULL CHECK (attack_rating > 0),
    defense_rating REAL NOT NULL CHECK (defense_rating >= 0.0 AND defense_rating < 1.0),
    hp REAL NOT NULL CHECK (hp > 0),
    rally_point_radius REAL NOT NULL CHECK (rally_point_radius > 0),
    attack_interval REAL NOT NULL CHECK (attack_interval > 0),
    respawn_seconds REAL NOT NULL CHECK (respawn_seconds > 0),
    heal_per_second REAL NOT NULL CHECK (heal_per_second >= 0)
);

-- A single shared configuration, measured in game seconds. Lifetime and
-- cooldown are independent: more than one group can be alive at a time.
CREATE TABLE reinforcement_config (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    time_to_live_seconds REAL NOT NULL
        CHECK (typeof(time_to_live_seconds) IN ('integer', 'real') AND time_to_live_seconds > 0),
    cooldown_seconds REAL NOT NULL
        CHECK (typeof(cooldown_seconds) IN ('integer', 'real') AND cooldown_seconds > 0)
);

CREATE TABLE difficulty (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    difficulty_level INTEGER NOT NULL UNIQUE CHECK (difficulty_level BETWEEN 1 AND 4),
    difficulty_name TEXT NOT NULL UNIQUE,
    difficulty_description TEXT NOT NULL DEFAULT '',
    enemy_hp_multiplier REAL NOT NULL CHECK (enemy_hp_multiplier > 0)
);

CREATE TABLE player_selected_difficulty (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    difficulty_id TEXT NOT NULL REFERENCES difficulty (id),
    selection_slot INTEGER NOT NULL UNIQUE CHECK (selection_slot = 1)
);

CREATE TABLE player_settings (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    debug_mode INTEGER NOT NULL CHECK (debug_mode IN (0, 1)),
    show_debug_info INTEGER NOT NULL CHECK (show_debug_info IN (0, 1)),
    show_debug_layout_guides INTEGER NOT NULL CHECK (show_debug_layout_guides IN (0, 1)),
    enemy_escape_haptics_enabled INTEGER NOT NULL CHECK (enemy_escape_haptics_enabled IN (0, 1))
);

CREATE TABLE player_selected_hero (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    hero_id TEXT NOT NULL UNIQUE REFERENCES hero (id),
    -- Primary is slot 1, optional secondary is slot 2 when saved. Reads derive
    -- roles from current hero rankings so a ranking edit immediately takes effect.
    selection_slot INTEGER NOT NULL UNIQUE CHECK (selection_slot BETWEEN 1 AND 2)
);

CREATE TABLE player_unlocked_hero (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    hero_id TEXT NOT NULL UNIQUE REFERENCES hero (id)
);

CREATE TABLE player_hud_layout (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    hud_section_name TEXT NOT NULL UNIQUE CHECK (
        hud_section_name IN ('hero_bar', 'stats_view', 'misc_view', 'master_controls')
    ),
    hud_location_name TEXT NOT NULL UNIQUE CHECK (
        hud_location_name IN (
            'north_west', 'north', 'north_east',
            'west', 'east',
            'south_west', 'south', 'south_east'
        )
    )
);

CREATE TABLE virtual_canvas (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    canvas_width REAL NOT NULL CHECK (canvas_width > 0.0),
    canvas_height REAL NOT NULL CHECK (canvas_height > 0.0),
    play_area_x REAL NOT NULL CHECK (play_area_x >= 0.0),
    play_area_y REAL NOT NULL CHECK (play_area_y >= 0.0),
    play_area_width REAL NOT NULL CHECK (play_area_width > 0.0),
    play_area_height REAL NOT NULL CHECK (play_area_height > 0.0),
    slot_width REAL NOT NULL CHECK (slot_width > 0.0),
    slot_height REAL NOT NULL CHECK (slot_height > 0.0),
    path_width REAL NOT NULL CHECK (path_width > 0.0),
    tower_menu_total_width REAL NOT NULL CHECK (tower_menu_total_width > 0.0),
    tower_menu_total_height REAL NOT NULL CHECK (tower_menu_total_height > 0.0),
    stats_view_width_fraction REAL NOT NULL
        CHECK (stats_view_width_fraction > 0.0 AND stats_view_width_fraction <= 1.0),
    stats_view_height_fraction REAL NOT NULL
        CHECK (stats_view_height_fraction > 0.0 AND stats_view_height_fraction <= 1.0),
    master_controls_width_fraction REAL NOT NULL
        CHECK (master_controls_width_fraction > 0.0 AND master_controls_width_fraction <= 1.0),
    master_controls_height_fraction REAL NOT NULL
        CHECK (master_controls_height_fraction > 0.0 AND master_controls_height_fraction <= 1.0),
    hero_bar_width_fraction REAL NOT NULL
        CHECK (hero_bar_width_fraction > 0.0 AND hero_bar_width_fraction <= 1.0),
    hero_bar_height_fraction REAL NOT NULL
        CHECK (hero_bar_height_fraction > 0.0 AND hero_bar_height_fraction <= 1.0),
    misc_view_width_fraction REAL NOT NULL
        CHECK (misc_view_width_fraction > 0.0 AND misc_view_width_fraction <= 1.0),
    misc_view_height_fraction REAL NOT NULL
        CHECK (misc_view_height_fraction > 0.0 AND misc_view_height_fraction <= 1.0),
    CHECK (play_area_x + play_area_width <= canvas_width),
    CHECK (play_area_y + play_area_height <= canvas_height),
    CHECK (tower_menu_total_width <= play_area_width),
    CHECK (tower_menu_total_height <= play_area_height)
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
    map_image_name TEXT NOT NULL DEFAULT ''
);

CREATE TABLE level_tower_unlock (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    level_info_id TEXT NOT NULL REFERENCES level_info (id),
    tower_kind TEXT NOT NULL,
    max_tower_level INTEGER NOT NULL CHECK (max_tower_level >= 0),
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
    -- Game seconds after the previous wave STARTS before its call button appears.
    call_button_delay REAL NOT NULL CHECK (call_button_delay >= 0.0),
    -- Game seconds the button stays available before this wave starts itself.
    -- Wave 1 always waits for a manual call, regardless of these values.
    auto_start_countdown REAL NOT NULL CHECK (auto_start_countdown >= 0.0),
    -- Money awarded once when this wave is called early. Wave 1 never awards it.
    early_call_bonus INTEGER NOT NULL CHECK (early_call_bonus >= 0),
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

CREATE TABLE hero (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    short_name TEXT NOT NULL,
    long_name TEXT NOT NULL,
    ranking INTEGER NOT NULL CHECK (typeof(ranking) = 'integer' AND ranking BETWEEN 1 AND 100),
    nickname TEXT,
    unlocked_at_level_wave_id TEXT NOT NULL REFERENCES level_wave (id),
    general_description TEXT NOT NULL,
    historical_description TEXT NOT NULL,
    historical_text TEXT NOT NULL,
    primary_image_name TEXT NOT NULL,
    details_image_name TEXT NOT NULL,
    icon_image_name TEXT NOT NULL,
    ability_icon_image_name TEXT NOT NULL,
    unit_image_name TEXT
);

CREATE TABLE hero_combat (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    hero_id TEXT NOT NULL UNIQUE REFERENCES hero (id),
    attack_rating REAL NOT NULL CHECK (attack_rating > 0),
    defense_rating REAL NOT NULL CHECK (defense_rating >= 0.0 AND defense_rating < 1.0),
    hp REAL NOT NULL CHECK (hp > 0),
    attack_interval REAL NOT NULL CHECK (attack_interval > 0),
    respawn_seconds REAL NOT NULL CHECK (respawn_seconds > 0),
    heal_per_second REAL NOT NULL DEFAULT 0 CHECK (heal_per_second >= 0),
    move_speed REAL NOT NULL CHECK (move_speed > 0)
);

CREATE TABLE level_hero (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    level_info_id TEXT NOT NULL REFERENCES level_info (id),
    hero_id TEXT NOT NULL REFERENCES hero (id),
    enemy_path_index INTEGER NOT NULL CHECK (enemy_path_index >= 0),
    UNIQUE (level_info_id, hero_id)
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

CREATE TABLE sim_tower_range (
    id TEXT PRIMARY KEY NOT NULL CHECK (LENGTH(id) = 36),
    tower_id TEXT NOT NULL UNIQUE REFERENCES tower (id),
    min_range INTEGER NOT NULL CHECK (min_range > 0),
    max_range INTEGER NOT NULL CHECK (max_range >= min_range)
);

CREATE TABLE sim_tower_sweep (
    profile TEXT PRIMARY KEY NOT NULL,
    tuning TEXT NOT NULL CHECK(json_valid(tuning))
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

CREATE TABLE simulator_run (
    id                   TEXT PRIMARY KEY NOT NULL,
    level_name           TEXT NOT NULL,
    focus                TEXT NOT NULL DEFAULT '',
    status               TEXT NOT NULL,
    total_iterations     INTEGER NOT NULL DEFAULT 0,
    completed_iterations INTEGER NOT NULL DEFAULT 0,
    iterations_per_second REAL NOT NULL DEFAULT 0,
    started_at           TEXT NOT NULL,
    updated_at           TEXT NOT NULL,
    finished_at          TEXT,
    process_id           INTEGER NOT NULL DEFAULT 0,
    output_path          TEXT NOT NULL DEFAULT '',
    report_path          TEXT,
    error_message        TEXT
);
CREATE INDEX idx_simulator_run_status ON simulator_run (status, started_at DESC);

CREATE TABLE sweep_row (
    id                            INTEGER PRIMARY KEY,
    run_id                        TEXT,
    perm                          INTEGER NOT NULL,
    money                         INTEGER NOT NULL,
    starting_lives                INTEGER NOT NULL,
    upgrade_growth                TEXT NOT NULL,
    tower_range                   TEXT NOT NULL,
    tower_rof                     TEXT NOT NULL,
    tower_projectile_speed        TEXT NOT NULL,
    tower_splash                  TEXT NOT NULL,
    tower_falloff                 TEXT NOT NULL,
    enemy_speed_bracket_position  REAL NOT NULL,
    enemy_hp_bracket_position     REAL NOT NULL,
    enemy_bounty_bracket_position REAL NOT NULL,
    melee_hp_bracket_position     REAL NOT NULL,
    melee_damage_bracket_position REAL NOT NULL,
    comp_curve                    TEXT NOT NULL,
    comp_mix                      TEXT NOT NULL,
    comp_spacing                  TEXT NOT NULL,
    seeds                         INTEGER NOT NULL,
    win_rate                      REAL NOT NULL,
    lives_p10                     REAL NOT NULL,
    lives_p50                     REAL NOT NULL,
    lives_p90                     REAL NOT NULL,
    mean_leaked                   REAL NOT NULL,
    rout_share                    REAL NOT NULL,
    tension_mean                  REAL NOT NULL,
    tension_peak                  REAL NOT NULL,
    tension_final                 REAL NOT NULL,
    mean_seconds                  REAL NOT NULL,
    w1_greedy_clear               REAL NOT NULL,
    w1_greedy_leaks               REAL NOT NULL,
    w1_naive_clear                REAL NOT NULL,
    w1_naive_leaks                REAL NOT NULL
);
CREATE INDEX idx_sweep_row_run ON sweep_row (run_id);
CREATE INDEX idx_sweep_row_range ON sweep_row (tower_range);
CREATE INDEX idx_sweep_row_win ON sweep_row (win_rate);
