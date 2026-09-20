-- Full catalog authority. No column defaults: every content field and effect is authored.
CREATE TABLE meta_upgrade_track (
    track_key TEXT PRIMARY KEY NOT NULL,
    title TEXT NOT NULL CHECK (LENGTH(TRIM(title)) > 0),
    short_title TEXT NOT NULL CHECK (LENGTH(TRIM(short_title)) > 0),
    display_order INTEGER NOT NULL UNIQUE CHECK (typeof(display_order) = 'integer' AND display_order > 0)
);
CREATE TABLE meta_upgrade (
    upgrade_key TEXT PRIMARY KEY NOT NULL,
    track_key TEXT NOT NULL REFERENCES meta_upgrade_track(track_key),
    display_order INTEGER NOT NULL CHECK (typeof(display_order) = 'integer' AND display_order > 0),
    star_cost INTEGER NOT NULL CHECK (typeof(star_cost) = 'integer' AND star_cost BETWEEN 1 AND 1000),
    prerequisite_key TEXT REFERENCES meta_upgrade(upgrade_key),
    title TEXT NOT NULL CHECK (LENGTH(TRIM(title)) > 0),
    description TEXT NOT NULL CHECK (LENGTH(TRIM(description)) > 0),
    icon_name TEXT NOT NULL CHECK (LENGTH(TRIM(icon_name)) > 0),
    historical_information TEXT NOT NULL CHECK (LENGTH(TRIM(historical_information)) > 0),
    source_title TEXT NOT NULL CHECK (LENGTH(TRIM(source_title)) > 0),
    source_url TEXT NOT NULL CHECK (LENGTH(TRIM(source_url)) > 0),
    CHECK (prerequisite_key IS NULL OR prerequisite_key <> upgrade_key),
    UNIQUE(track_key, display_order)
);
CREATE TABLE meta_upgrade_effect (
    upgrade_key TEXT NOT NULL REFERENCES meta_upgrade(upgrade_key),
    parameter TEXT NOT NULL CHECK (LENGTH(TRIM(parameter)) > 0),
    value REAL NOT NULL CHECK (typeof(value) IN ('integer', 'real') AND value > 0),
    PRIMARY KEY(upgrade_key, parameter)
);
