// Schema.swift
// Versioned, forward-only migrations. Each entry in `all` is one version;
// migrate() applies whatever the database hasn't seen yet, atomically.
// Telemetry tables will arrive as v2+ without touching v1.

public enum Migrations {
    static let v1 = """
    CREATE TABLE enemy_types (
        id            TEXT PRIMARY KEY,
        name          TEXT NOT NULL,
        max_hp        REAL NOT NULL,
        speed         REAL NOT NULL,
        cover         REAL NOT NULL,
        discipline    REAL NOT NULL,
        hardiness     REAL NOT NULL,
        damage_min    REAL NOT NULL,
        damage_max    REAL NOT NULL,
        gold          INTEGER NOT NULL,
        lives_cost    INTEGER NOT NULL DEFAULT 1,
        break_band_lo REAL NOT NULL,
        break_band_hi REAL NOT NULL,
        traits        TEXT NOT NULL DEFAULT '[]'
    );

    CREATE TABLE tower_types (
        id   TEXT PRIMARY KEY,
        name TEXT NOT NULL
    );

    CREATE TABLE tower_levels (
        tower_id         TEXT NOT NULL REFERENCES tower_types(id) ON DELETE CASCADE,
        level            INTEGER NOT NULL,
        cost             INTEGER NOT NULL,
        range            REAL NOT NULL,
        fire_interval    REAL NOT NULL,
        shot_min         REAL NOT NULL DEFAULT 0,
        shot_max         REAL NOT NULL DEFAULT 0,
        terror_min       REAL NOT NULL DEFAULT 0,
        terror_max       REAL NOT NULL DEFAULT 0,
        aoe_radius       REAL NOT NULL DEFAULT 0,
        contagion_chance REAL NOT NULL DEFAULT 0,
        targeting        TEXT NOT NULL DEFAULT 'first',
        PRIMARY KEY (tower_id, level)
    );

    CREATE TABLE levels (
        id            TEXT PRIMARY KEY,
        name          TEXT NOT NULL,
        starting_gold INTEGER NOT NULL,
        lives         INTEGER NOT NULL
    );

    -- Path polylines are packed float64 pairs (little-endian x,y per point):
    -- compact, fast, and lossless. See PointBlob in Repositories.swift.
    CREATE TABLE level_paths (
        level_id   TEXT NOT NULL REFERENCES levels(id) ON DELETE CASCADE,
        path_index INTEGER NOT NULL,
        points     BLOB NOT NULL,
        PRIMARY KEY (level_id, path_index)
    );

    CREATE TABLE tower_slots (
        level_id   TEXT NOT NULL REFERENCES levels(id) ON DELETE CASCADE,
        slot_index INTEGER NOT NULL,
        x          REAL NOT NULL,
        y          REAL NOT NULL,
        PRIMARY KEY (level_id, slot_index)
    );

    CREATE TABLE waves (
        level_id   TEXT NOT NULL REFERENCES levels(id) ON DELETE CASCADE,
        wave_index INTEGER NOT NULL,
        start_time REAL NOT NULL,
        PRIMARY KEY (level_id, wave_index)
    );

    CREATE TABLE wave_spawns (
        level_id      TEXT NOT NULL REFERENCES levels(id) ON DELETE CASCADE,
        wave_index    INTEGER NOT NULL,
        spawn_index   INTEGER NOT NULL,
        enemy_type_id TEXT NOT NULL REFERENCES enemy_types(id),
        count         INTEGER NOT NULL,
        interval      REAL NOT NULL,
        delay         REAL NOT NULL DEFAULT 0,
        path_index    INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (level_id, wave_index, spawn_index)
    );

    CREATE INDEX idx_wave_spawns_level ON wave_spawns(level_id);
    CREATE INDEX idx_waves_level ON waves(level_id);
    """

    /// All migrations in order. Version N is all[N-1].
    public static let all: [String] = [v1]

    public static func migrate(_ db: SQLiteDatabase) throws {
        try db.exec("""
        CREATE TABLE IF NOT EXISTS schema_migrations (
            version    INTEGER PRIMARY KEY,
            applied_at TEXT NOT NULL
        );
        """)
        let current = try db.scalarInt("SELECT MAX(version) FROM schema_migrations;") ?? 0
        guard current < all.count else { return }
        for version in (Int(current) + 1)...all.count {
            try db.transaction {
                try db.exec(all[version - 1])
                try db.run(
                    "INSERT INTO schema_migrations (version, applied_at) VALUES (?, datetime('now'));",
                    [.integer(version)]
                )
            }
        }
    }
}
