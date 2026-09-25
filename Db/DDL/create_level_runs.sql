-- One attempt at a level, independent of a multi-candidate simulator study.
CREATE TABLE level_run (
    id TEXT PRIMARY KEY NOT NULL CHECK (length(id) = 36),
    level_id TEXT NOT NULL,
    source TEXT NOT NULL CHECK (source IN ('player', 'simulator', 'editor')),
    play_speed_factor REAL NOT NULL CHECK (play_speed_factor BETWEEN 0.01 AND 1000000000),
    started_at TEXT NOT NULL,
    finished_at TEXT,
    status TEXT NOT NULL CHECK (status IN ('running', 'victory', 'defeat', 'timeout', 'abandoned', 'failed')),
    last_sequence INTEGER NOT NULL CHECK (last_sequence >= -1),
    last_tick INTEGER NOT NULL CHECK (last_tick >= 0),
    format_version INTEGER NOT NULL CHECK (format_version = 2),
    setup BLOB NOT NULL,
    result_json TEXT CHECK (result_json IS NULL OR json_valid(result_json))
);
CREATE INDEX level_run_level ON level_run(level_id, started_at);

-- Sequence orders physical records. Presentation rows are bounded timeline-v1
-- blocks of virtual-time value segments and ordered input/combat events. Legacy
-- frame rows remain readable. Playback never reruns gameplay or RNG.
CREATE TABLE level_action (
    run_id TEXT NOT NULL REFERENCES level_run(id),
    sequence INTEGER NOT NULL CHECK (sequence >= 0),
    tick INTEGER NOT NULL CHECK (tick >= 0),
    category TEXT NOT NULL CHECK (category IN ('input', 'event', 'presentation', 'lifecycle')),
    name TEXT NOT NULL CHECK (length(name) > 0),
    payload_json TEXT NOT NULL CHECK (json_valid(payload_json)),
    presentation BLOB,
    CHECK ((category = 'presentation') = (presentation IS NOT NULL)),
    PRIMARY KEY (run_id, sequence)
);
CREATE INDEX level_action_tick ON level_action(run_id, tick, sequence);
