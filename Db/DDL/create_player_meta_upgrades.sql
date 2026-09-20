-- Active player state and an authored restore preset reference the SQL catalog.
CREATE TABLE player_meta_upgrade_profile (
    profile_key TEXT PRIMARY KEY NOT NULL CHECK (profile_key IN ('active', 'level15'))
);

-- Every upgrade has an explicit selected/unselected row in each profile.
CREATE TABLE player_meta_upgrade_selection (
    profile_key TEXT NOT NULL REFERENCES player_meta_upgrade_profile (profile_key),
    upgrade_key TEXT NOT NULL REFERENCES meta_upgrade(upgrade_key),
    is_selected INTEGER NOT NULL CHECK (typeof(is_selected) = 'integer' AND is_selected IN (0, 1)),
    PRIMARY KEY (profile_key, upgrade_key)
);

-- Every level has an explicit result, including zero for an uncompleted level.
-- Total budget is SUM(best_stars); spent stars derive from selected upgrades.
CREATE TABLE player_meta_upgrade_level_stars (
    profile_key TEXT NOT NULL REFERENCES player_meta_upgrade_profile (profile_key),
    level_info_id TEXT NOT NULL REFERENCES level_info (id),
    best_stars INTEGER NOT NULL CHECK (typeof(best_stars) = 'integer' AND best_stars BETWEEN 0 AND 3),
    PRIMARY KEY (profile_key, level_info_id)
);
