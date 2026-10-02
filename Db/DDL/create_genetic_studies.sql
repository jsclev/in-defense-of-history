-- Search coordination, captured options, progress and checkpoint membership.
-- Captured game content is already in the invocation's authored content tables.
CREATE TABLE ga_study (
    run_id TEXT PRIMARY KEY NOT NULL REFERENCES ga_run(run_id) ON DELETE CASCADE,
    algorithm TEXT NOT NULL, build_version TEXT NOT NULL, snapshot_sha256 TEXT NOT NULL,
    workers INTEGER NOT NULL CHECK(workers BETWEEN 1 AND 32),
    -- Zero disables an optional resource ceiling. Goal evidence decides completion.
    population INTEGER NOT NULL CHECK(population>=4), generations INTEGER NOT NULL CHECK(generations>=0),
    training_seeds INTEGER NOT NULL CHECK(training_seeds>0), validation_seeds INTEGER NOT NULL CHECK(validation_seeds>0),
    finalists INTEGER NOT NULL CHECK(finalists>0), max_evaluations INTEGER NOT NULL CHECK(max_evaluations>=0),
    hours REAL NOT NULL CHECK(hours>=0), search_seed TEXT NOT NULL,
    star_minimum INTEGER, star_maximum INTEGER, star_step INTEGER NOT NULL CHECK(star_step>0),
    fixed_meta INTEGER NOT NULL CHECK(fixed_meta IN (0,1)), early_wave_calls INTEGER NOT NULL CHECK(early_wave_calls IN (0,1)),
    meta_selections INTEGER NOT NULL, minimum_meta_candidates INTEGER NOT NULL, meta_adaptation_generations INTEGER NOT NULL,
    hero_ai_override INTEGER CHECK(hero_ai_override IN (0,1)), selected_heroes_overridden INTEGER NOT NULL CHECK(selected_heroes_overridden IN (0,1)),
    majority_tower_kind TEXT, earned_stars INTEGER NOT NULL CHECK(earned_stars>=0)
);
CREATE TABLE ga_stopping_policy (
    run_id TEXT PRIMARY KEY NOT NULL REFERENCES ga_study(run_id),
    minimum_training_battles INTEGER NOT NULL CHECK(minimum_training_battles>0),
    stability_battles INTEGER NOT NULL CHECK(stability_battles>0),
    stability_generations INTEGER NOT NULL CHECK(stability_generations>0),
    solutions INTEGER NOT NULL CHECK(solutions BETWEEN 1 AND 8)
);
CREATE TABLE ga_search_goal (
    run_id TEXT NOT NULL REFERENCES ga_study(run_id), stars_used INTEGER NOT NULL,
    training_battles INTEGER NOT NULL, last_improvement_battle INTEGER NOT NULL,
    last_improvement_generation INTEGER NOT NULL, last_exploration_battle INTEGER NOT NULL,
    last_exploration_generation INTEGER NOT NULL, winning_niches INTEGER NOT NULL,
    PRIMARY KEY(run_id,stars_used)
);
-- Each blind qualification attempt keeps a separate evidence run. Rejected
-- attempts remain readable; no held-out result enters training or breeding.
CREATE TABLE ga_qualification (
    study_run_id TEXT NOT NULL REFERENCES ga_study(run_id), attempt INTEGER NOT NULL CHECK(attempt>=0),
    evidence_run_id TEXT UNIQUE NOT NULL REFERENCES ga_run(run_id),
    training_battles INTEGER NOT NULL, generations INTEGER NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('running','qualified','rejected','resource-limit')),
    PRIMARY KEY(study_run_id,attempt)
);
CREATE TABLE ga_qualification_seed (
    evidence_run_id TEXT NOT NULL REFERENCES ga_run(run_id), ordinal INTEGER NOT NULL,
    seed TEXT NOT NULL, PRIMARY KEY(evidence_run_id,ordinal), UNIQUE(evidence_run_id,seed)
);
CREATE TABLE ga_study_seed (
    run_id TEXT NOT NULL REFERENCES ga_study(run_id) ON DELETE CASCADE,
    panel TEXT NOT NULL CHECK(panel IN ('training','validation')), ordinal INTEGER NOT NULL CHECK(ordinal>=0),
    seed TEXT NOT NULL CHECK(length(seed) BETWEEN 1 AND 20 AND seed NOT GLOB '*[^0-9]*'),
    PRIMARY KEY(run_id,panel,ordinal), UNIQUE(run_id,panel,seed)
);
CREATE TABLE ga_study_star (
    run_id TEXT NOT NULL REFERENCES ga_study(run_id) ON DELETE CASCADE,
    ordinal INTEGER NOT NULL CHECK(ordinal>=0), stars_used INTEGER NOT NULL CHECK(stars_used>=0),
    reachable INTEGER NOT NULL CHECK(reachable IN (0,1)), PRIMARY KEY(run_id,ordinal), UNIQUE(run_id,stars_used)
);
CREATE TABLE ga_study_upgrade (
    run_id TEXT NOT NULL REFERENCES ga_study(run_id) ON DELETE CASCADE,
    upgrade_id TEXT NOT NULL REFERENCES meta_upgrade(upgrade_key), PRIMARY KEY(run_id,upgrade_id)
);
CREATE TABLE ga_tower_limit (
    run_id TEXT NOT NULL REFERENCES ga_study(run_id) ON DELETE CASCADE,
    tower_kind TEXT NOT NULL, maximum INTEGER NOT NULL CHECK(maximum>=0), PRIMARY KEY(run_id,tower_kind)
);
CREATE TABLE ga_input_strategy (
    run_id TEXT NOT NULL REFERENCES ga_study(run_id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK(role IN ('seed','exchange')), ordinal INTEGER NOT NULL CHECK(ordinal>=0),
    strategy_id INTEGER NOT NULL REFERENCES ga_strategy(strategy_id), PRIMARY KEY(run_id,role,ordinal)
);
CREATE TABLE ga_checkpoint (
    run_id TEXT PRIMARY KEY NOT NULL REFERENCES ga_study(run_id) ON DELETE CASCADE,
    completed_generations INTEGER, next_candidate_id INTEGER NOT NULL, cache_hits INTEGER
);
CREATE TABLE ga_population_selection (
    run_id TEXT NOT NULL REFERENCES ga_checkpoint(run_id) ON DELETE CASCADE,
    stars_used INTEGER NOT NULL, selection_key TEXT NOT NULL, ordinal INTEGER NOT NULL,
    introduced_generation INTEGER, active INTEGER NOT NULL CHECK(active IN (0,1)),
    plans_per_selection INTEGER NOT NULL, minimum_candidates INTEGER NOT NULL,
    PRIMARY KEY(run_id,stars_used,selection_key), UNIQUE(run_id,stars_used,ordinal)
);
CREATE TABLE ga_population_upgrade (
    run_id TEXT NOT NULL, stars_used INTEGER NOT NULL, selection_key TEXT NOT NULL, upgrade_id TEXT NOT NULL,
    FOREIGN KEY(run_id,stars_used,selection_key) REFERENCES ga_population_selection(run_id,stars_used,selection_key) ON DELETE CASCADE,
    PRIMARY KEY(run_id,stars_used,selection_key,upgrade_id)
);
CREATE TABLE ga_population_member (
    run_id TEXT NOT NULL, stars_used INTEGER NOT NULL, selection_key TEXT NOT NULL, candidate_id INTEGER NOT NULL,
    archive_ordinal INTEGER CHECK(archive_ordinal>=0),
    FOREIGN KEY(run_id,stars_used,selection_key) REFERENCES ga_population_selection(run_id,stars_used,selection_key) ON DELETE CASCADE,
    FOREIGN KEY(run_id,candidate_id) REFERENCES ga_candidate(run_id,candidate_id),
    PRIMARY KEY(run_id,stars_used,selection_key,candidate_id), UNIQUE(run_id,stars_used,selection_key,archive_ordinal)
);
CREATE TABLE ga_progress (
    run_id TEXT PRIMARY KEY NOT NULL REFERENCES ga_run(run_id) ON DELETE CASCADE,
    phase TEXT NOT NULL CHECK(phase IN ('search','validation','saving','recording','completed','failed')),
    percent_complete REAL NOT NULL, elapsed_seconds REAL NOT NULL, estimated_seconds_remaining REAL,
    completed_generations INTEGER NOT NULL, training_evaluations INTEGER NOT NULL, validation_evaluations INTEGER NOT NULL
);
CREATE TABLE ga_progress_milestone (
    run_id TEXT NOT NULL REFERENCES ga_progress(run_id) ON DELETE CASCADE,
    ordinal INTEGER NOT NULL, percent INTEGER NOT NULL, elapsed_seconds REAL NOT NULL, PRIMARY KEY(run_id,ordinal)
);
CREATE TABLE ga_summary (
    run_id TEXT PRIMARY KEY NOT NULL REFERENCES ga_run(run_id) ON DELETE CASCADE,
    search_stop_reason TEXT, validation_complete INTEGER NOT NULL CHECK(validation_complete IN (0,1)),
    evaluation_seconds REAL NOT NULL, recording_seconds REAL, total_seconds REAL,
    cache_hits INTEGER NOT NULL, completed_generations INTEGER NOT NULL, unique_candidates INTEGER NOT NULL,
    playback_recordings INTEGER
);
CREATE TABLE ga_import (
    run_id TEXT PRIMARY KEY NOT NULL REFERENCES ga_run(run_id) ON DELETE CASCADE,
    source_database TEXT NOT NULL, source_run_id TEXT NOT NULL, selection TEXT NOT NULL
);
CREATE VIEW ga_study_overview AS
SELECT s.run_id,r.level_info_id,l.level_name,r.difficulty_id,r.starting_money,r.bounty_fraction,
       s.build_version,s.algorithm,s.workers,s.population,s.max_evaluations,s.hours,
       p.phase,p.percent_complete,p.training_evaluations,p.validation_evaluations,p.elapsed_seconds,
       m.validation_complete,m.search_stop_reason,m.playback_recordings
FROM ga_study s JOIN ga_run r USING(run_id) JOIN level_info l ON l.id=r.level_info_id
LEFT JOIN ga_progress p USING(run_id) LEFT JOIN ga_summary m USING(run_id);

-- Persistent best-per-behavior archive and actual allocated breeding turns.
CREATE TABLE ga_population_niche (
    run_id TEXT NOT NULL, stars_used INTEGER NOT NULL, selection_key TEXT NOT NULL,
    niche TEXT NOT NULL, candidate_id INTEGER NOT NULL,
    breeding_visits INTEGER NOT NULL CHECK(breeding_visits>=0),
    FOREIGN KEY(run_id,stars_used,selection_key) REFERENCES ga_population_selection(run_id,stars_used,selection_key) ON DELETE CASCADE,
    FOREIGN KEY(run_id,candidate_id) REFERENCES ga_candidate(run_id,candidate_id),
    PRIMARY KEY(run_id,stars_used,selection_key,niche)
);
