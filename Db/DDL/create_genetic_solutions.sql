-- Shipping GA candidates are independent of disposable simulator history.
CREATE TABLE genetic_solution (
    run_id TEXT NOT NULL CHECK (length(run_id) = 36),
    candidate_id INTEGER NOT NULL CHECK (candidate_id >= 0),
    panel TEXT NOT NULL CHECK (panel IN ('training', 'validation')),
    level_info_id TEXT NOT NULL REFERENCES level_info(id),
    difficulty_id TEXT NOT NULL REFERENCES difficulty(id),
    starting_money INTEGER NOT NULL CHECK (starting_money > 0),
    bounty_fraction REAL NOT NULL CHECK (bounty_fraction BETWEEN 0 AND 1),
    max_game_seconds REAL NOT NULL CHECK (max_game_seconds > 0),
    content_sha256 TEXT NOT NULL CHECK (length(content_sha256) = 64),
    stars_used INTEGER NOT NULL CHECK (stars_used >= 0),
    solution_json TEXT NOT NULL CHECK (json_valid(solution_json)),
    -- Preserve old no-hero evidence, but never reinterpret it as hero-enabled.
    CHECK ((json_extract(solution_json, '$.formatVersion') IS 1
            AND json_extract(solution_json, '$.heroesEnabled') IS 0
            AND json_type(solution_json, '$.context.heroLoadout') IS NULL)
        OR (json_extract(solution_json, '$.formatVersion') IS 2
            AND json_extract(solution_json, '$.heroesEnabled') IS 1
            AND json_type(solution_json, '$.context.heroLoadout.selectedHeroIDs') IS 'array'
            AND json_array_length(solution_json, '$.context.heroLoadout.selectedHeroIDs') BETWEEN 1 AND 2
            AND json_type(solution_json, '$.context.heroLoadout.deployments') IS 'array')),
    CHECK (json_extract(solution_json, '$.runID') IS run_id),
    CHECK (json_extract(solution_json, '$.candidate.id') IS candidate_id),
    CHECK (json_extract(solution_json, '$.panel') IS panel),
    CHECK (lower(json_extract(solution_json, '$.context.levelID')) IS level_info_id),
    CHECK (lower(json_extract(solution_json, '$.context.difficultyID')) IS difficulty_id),
    CHECK (json_extract(solution_json, '$.context.startingMoney') IS starting_money),
    CHECK (json_extract(solution_json, '$.context.bountyFraction') IS bounty_fraction),
    CHECK (json_extract(solution_json, '$.context.maxGameSeconds') IS max_game_seconds),
    CHECK (json_extract(solution_json, '$.context.contentSHA256') IS content_sha256),
    CHECK (json_extract(solution_json, '$.candidate.starsUsed') IS stars_used),
    PRIMARY KEY (run_id, candidate_id, panel)
);
CREATE INDEX genetic_solution_lookup ON genetic_solution
    (level_info_id, difficulty_id, content_sha256, starting_money, bounty_fraction, stars_used, panel);
