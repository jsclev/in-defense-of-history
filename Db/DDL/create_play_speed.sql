-- Game seconds per wall-clock second; never changes the combat tick size.
CREATE TABLE play_speed (
    source TEXT PRIMARY KEY NOT NULL CHECK (source IN ('player', 'simulator', 'editor')),
    factor REAL NOT NULL CHECK (typeof(factor) IN ('integer', 'real') AND factor BETWEEN 0.01 AND 1000000000)
);
