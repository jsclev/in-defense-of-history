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
-- Simulator event batches store their compressed bytes directly in event_data.
-- Historical base64 JSON batches remain readable with event_data NULL.
CREATE TABLE level_action (
    run_id TEXT NOT NULL REFERENCES level_run(id),
    sequence INTEGER NOT NULL CHECK (sequence >= 0),
    tick INTEGER NOT NULL CHECK (tick >= 0),
    category TEXT NOT NULL CHECK (category IN ('input', 'event', 'presentation', 'lifecycle')),
    name TEXT NOT NULL CHECK (length(name) > 0),
    payload_json TEXT NOT NULL CHECK (json_valid(payload_json)),
    presentation BLOB,
    event_data BLOB CHECK (event_data IS NULL OR
        (typeof(event_data) = 'blob' AND length(event_data) > 0 AND
         category = 'event' AND name IN ('battle-events-v3','battle-events-v4','battle-events-v5') AND payload_json = '{}')),
    CHECK ((category = 'presentation') = (presentation IS NOT NULL)),
    PRIMARY KEY (run_id, sequence)
);
CREATE INDEX level_action_tick ON level_action(run_id, tick, sequence);

-- Demonstrations generated only after GA selection. Original fitness evidence
-- stays in genetic_solution; rerun results never replace or rank that evidence.
CREATE TABLE genetic_solution_recording (
    run_id TEXT NOT NULL,
    candidate_id INTEGER NOT NULL,
    panel TEXT NOT NULL CHECK (panel IN ('training', 'validation')),
    -- Seeds are UInt64, including values above SQLite's signed integer range.
    seed TEXT NOT NULL CHECK (length(seed) BETWEEN 1 AND 20 AND seed NOT GLOB '*[^0-9]*'),
    level_run_id TEXT NOT NULL UNIQUE REFERENCES level_run(id),
    outcome TEXT NOT NULL CHECK (outcome IN ('victory', 'defeat', 'timeout')),
    lives_remaining INTEGER NOT NULL CHECK (lives_remaining >= 0),
    waves_started INTEGER NOT NULL CHECK (waves_started >= 0),
    seconds REAL NOT NULL CHECK (seconds >= 0),
    matches_evaluation INTEGER NOT NULL CHECK (matches_evaluation IN (0, 1)),
    PRIMARY KEY (run_id, candidate_id, panel),
    FOREIGN KEY (run_id, candidate_id, panel)
        REFERENCES genetic_solution(run_id, candidate_id, panel) ON DELETE CASCADE
);
