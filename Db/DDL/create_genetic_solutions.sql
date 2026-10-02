-- GA persistence. DNA, original fitness evidence and retained solutions are
-- relational; JSON is only an interchange/export format. DDL lives here only.
-- No dependency on simulator_run: a shipping catalog also contains ga_run rows.
CREATE TABLE ga_run (
    run_id TEXT PRIMARY KEY NOT NULL CHECK(length(run_id)=36),
    format_version INTEGER NOT NULL CHECK(format_version IN (1,2)),
    executable_sha256 TEXT NOT NULL CHECK(length(executable_sha256)=64),
    level_info_id TEXT NOT NULL REFERENCES level_info(id),
    difficulty_id TEXT NOT NULL REFERENCES difficulty(id),
    starting_money INTEGER NOT NULL CHECK(starting_money>0),
    bounty_fraction REAL NOT NULL CHECK(bounty_fraction BETWEEN 0 AND 1),
    max_game_seconds REAL NOT NULL CHECK(max_game_seconds>0),
    content_sha256 TEXT NOT NULL CHECK(length(content_sha256)=64),
    heroes_enabled INTEGER NOT NULL CHECK(heroes_enabled IN (0,1)),
    CHECK((format_version=1 AND heroes_enabled=0) OR (format_version=2 AND heroes_enabled=1))
);
CREATE TABLE ga_hero (
    run_id TEXT NOT NULL REFERENCES ga_run(run_id) ON DELETE CASCADE,
    ordinal INTEGER NOT NULL CHECK(ordinal IN (0,1)),
    hero_id TEXT NOT NULL,
    deployment_ordinal INTEGER CHECK(deployment_ordinal IN (0,1)),
    role TEXT CHECK(role IN ('primary','secondary')),
    spawn_feature_id TEXT,
    x REAL, y REAL, ai_enabled INTEGER CHECK(ai_enabled IN (0,1)),
    CHECK((deployment_ordinal IS NULL AND role IS NULL AND spawn_feature_id IS NULL AND x IS NULL AND y IS NULL AND ai_enabled IS NULL)
       OR (deployment_ordinal IS NOT NULL AND role IS NOT NULL AND length(spawn_feature_id)>0 AND x IS NOT NULL AND y IS NOT NULL AND ai_enabled IS NOT NULL)),
    PRIMARY KEY(run_id,ordinal), UNIQUE(run_id,hero_id), UNIQUE(run_id,deployment_ordinal)
);
CREATE TABLE ga_strategy (
    strategy_id INTEGER PRIMARY KEY,
    run_id TEXT NOT NULL REFERENCES ga_run(run_id) ON DELETE CASCADE,
    reinforcement_priority TEXT NOT NULL CHECK(reinforcement_priority IN ('nearestExit','nearPoint')),
    reinforcement_x REAL, reinforcement_y REAL,
    reinforcement_hold_seconds REAL NOT NULL CHECK(reinforcement_hold_seconds>=0),
    decision_count INTEGER NOT NULL CHECK(decision_count>=0),
    meta_upgrade_count INTEGER NOT NULL CHECK(meta_upgrade_count>=0),
    early_wave_count INTEGER NOT NULL CHECK(early_wave_count>=0),
    -- NULL identifies historical DNA using the original automatic sites.
    tactical_count INTEGER CHECK(tactical_count>=0),
    CHECK((reinforcement_priority='nearestExit' AND reinforcement_x IS NULL AND reinforcement_y IS NULL)
       OR (reinforcement_priority='nearPoint' AND reinforcement_x IS NOT NULL AND reinforcement_y IS NOT NULL)),
    UNIQUE(run_id,strategy_id)
);
CREATE TABLE ga_decision (
    strategy_id INTEGER NOT NULL REFERENCES ga_strategy(strategy_id) ON DELETE CASCADE,
    ordinal INTEGER NOT NULL CHECK(ordinal>=0),
    seconds REAL NOT NULL CHECK(seconds>=0),
    earliest_wave INTEGER NOT NULL CHECK(earliest_wave>=0),
    save_for_purchase INTEGER NOT NULL CHECK(save_for_purchase IN (0,1)),
    action TEXT NOT NULL CHECK(action IN ('build','upgrade','purchaseUpgrade')),
    slot INTEGER NOT NULL CHECK(slot>=0),
    tower_id TEXT, upgrade_path_id TEXT,
    CHECK((action='build' AND tower_id IS NOT NULL AND upgrade_path_id IS NULL)
       OR (action='upgrade' AND tower_id IS NULL AND upgrade_path_id IS NULL)
       OR (action='purchaseUpgrade' AND tower_id IS NULL AND upgrade_path_id IS NOT NULL)),
    PRIMARY KEY(strategy_id,ordinal)
);
CREATE TABLE ga_meta_upgrade (
    strategy_id INTEGER NOT NULL REFERENCES ga_strategy(strategy_id) ON DELETE CASCADE,
    ordinal INTEGER NOT NULL CHECK(ordinal>=0),
    upgrade_id TEXT NOT NULL REFERENCES meta_upgrade(upgrade_key),
    PRIMARY KEY(strategy_id,ordinal), UNIQUE(strategy_id,upgrade_id)
);
CREATE TABLE ga_early_wave (
    strategy_id INTEGER NOT NULL REFERENCES ga_strategy(strategy_id) ON DELETE CASCADE,
    ordinal INTEGER NOT NULL CHECK(ordinal>=0),
    wave INTEGER NOT NULL CHECK(wave>=2),
    policy TEXT NOT NULL CHECK(policy IN ('automatic','afterVisible','whenCountdownAtMost','whenEnemiesAtMost')),
    seconds REAL, countdown_seconds INTEGER, enemy_count INTEGER,
    CHECK((policy='automatic' AND seconds IS NULL AND countdown_seconds IS NULL AND enemy_count IS NULL)
       OR (policy='afterVisible' AND seconds>=0 AND seconds IS NOT NULL AND countdown_seconds IS NULL AND enemy_count IS NULL)
       OR (policy='whenCountdownAtMost' AND seconds IS NULL AND countdown_seconds>=1 AND countdown_seconds IS NOT NULL AND enemy_count IS NULL)
       OR (policy='whenEnemiesAtMost' AND seconds>=0 AND seconds IS NOT NULL AND countdown_seconds IS NULL AND enemy_count>=0 AND enemy_count IS NOT NULL)),
    PRIMARY KEY(strategy_id,ordinal), UNIQUE(strategy_id,wave)
);
CREATE TABLE ga_candidate (
    run_id TEXT NOT NULL REFERENCES ga_run(run_id) ON DELETE CASCADE,
    candidate_id INTEGER NOT NULL CHECK(candidate_id>=0),
    generation INTEGER NOT NULL CHECK(generation>=0),
    stars_used INTEGER NOT NULL CHECK(stars_used>=0),
    strategy_id INTEGER NOT NULL UNIQUE,
    FOREIGN KEY(run_id,strategy_id) REFERENCES ga_strategy(run_id,strategy_id),
    PRIMARY KEY(run_id,candidate_id)
);
CREATE INDEX ga_candidate_generation ON ga_candidate(run_id,generation,stars_used);
CREATE TABLE ga_panel (
    run_id TEXT NOT NULL, candidate_id INTEGER NOT NULL,
    panel TEXT NOT NULL CHECK(panel IN ('training','validation')),
    expected_samples INTEGER NOT NULL CHECK(expected_samples>0),
    sample_count INTEGER NOT NULL CHECK(sample_count>0 AND sample_count<=expected_samples),
    FOREIGN KEY(run_id,candidate_id) REFERENCES ga_candidate(run_id,candidate_id) ON DELETE CASCADE,
    PRIMARY KEY(run_id,candidate_id,panel)
);
CREATE TABLE ga_evaluation (
    evaluation_id INTEGER PRIMARY KEY,
    run_id TEXT NOT NULL, candidate_id INTEGER NOT NULL, panel TEXT NOT NULL,
    ordinal INTEGER NOT NULL CHECK(ordinal>=0),
    -- Decimal TEXT preserves all UInt64 bits, including values above 2^63-1.
    seed TEXT NOT NULL CHECK(length(seed) BETWEEN 1 AND 20 AND seed NOT GLOB '*[^0-9]*'),
    level_run_id TEXT,
    outcome TEXT NOT NULL CHECK(outcome IN ('victory','defeat','timeout')),
    seconds REAL NOT NULL CHECK(seconds>=0),
    lives_remaining INTEGER NOT NULL CHECK(lives_remaining>=0),
    gold_remaining INTEGER NOT NULL, gold_earned INTEGER NOT NULL,
    killed INTEGER NOT NULL CHECK(killed>=0), leaked INTEGER NOT NULL CHECK(leaked>=0),
    waves_started INTEGER NOT NULL CHECK(waves_started>=0),
    built_towers_known INTEGER NOT NULL CHECK(built_towers_known IN (0,1)),
    fate_count INTEGER NOT NULL CHECK(fate_count>=0),
    progress_count INTEGER NOT NULL CHECK(progress_count>=0),
    leak_count INTEGER NOT NULL CHECK(leak_count>=0),
    economy_count INTEGER NOT NULL CHECK(economy_count>=0),
    reinforcement_count INTEGER NOT NULL CHECK(reinforcement_count>=0),
    wave_call_count INTEGER NOT NULL CHECK(wave_call_count>=0),
    built_tower_count INTEGER NOT NULL CHECK(built_tower_count>=0),
    -- NULL means historical unknown; zero means captured, with no commands.
    tactical_count INTEGER CHECK(tactical_count>=0),
    FOREIGN KEY(run_id,candidate_id,panel) REFERENCES ga_panel(run_id,candidate_id,panel) ON DELETE CASCADE,
    UNIQUE(run_id,candidate_id,panel,ordinal), UNIQUE(run_id,candidate_id,panel,seed)
);
CREATE INDEX ga_evaluation_panel ON ga_evaluation(run_id,panel,candidate_id);
CREATE TABLE ga_enemy_fate (
    evaluation_id INTEGER NOT NULL REFERENCES ga_evaluation(evaluation_id) ON DELETE CASCADE,
    enemy_type_id TEXT NOT NULL, killed INTEGER NOT NULL CHECK(killed>=0), leaked INTEGER NOT NULL CHECK(leaked>=0),
    PRIMARY KEY(evaluation_id,enemy_type_id)
);
CREATE TABLE ga_wave_progress (
    evaluation_id INTEGER NOT NULL REFERENCES ga_evaluation(evaluation_id) ON DELETE CASCADE,
    ordinal INTEGER NOT NULL CHECK(ordinal>=0), max_progress REAL NOT NULL,
    PRIMARY KEY(evaluation_id,ordinal)
);
CREATE TABLE ga_wave_leak (
    evaluation_id INTEGER NOT NULL REFERENCES ga_evaluation(evaluation_id) ON DELETE CASCADE,
    ordinal INTEGER NOT NULL CHECK(ordinal>=0), leaked INTEGER NOT NULL CHECK(leaked>=0),
    PRIMARY KEY(evaluation_id,ordinal)
);
CREATE TABLE ga_wave_economy (
    evaluation_id INTEGER NOT NULL REFERENCES ga_evaluation(evaluation_id) ON DELETE CASCADE,
    ordinal INTEGER NOT NULL CHECK(ordinal>=0), wave INTEGER NOT NULL,
    seconds REAL NOT NULL, money INTEGER NOT NULL, lives INTEGER NOT NULL,
    PRIMARY KEY(evaluation_id,ordinal)
);
CREATE TABLE ga_reinforcement_deployment (
    evaluation_id INTEGER NOT NULL REFERENCES ga_evaluation(evaluation_id) ON DELETE CASCADE,
    ordinal INTEGER NOT NULL CHECK(ordinal>=0), seconds REAL NOT NULL, wave INTEGER NOT NULL,
    x REAL NOT NULL, y REAL NOT NULL, PRIMARY KEY(evaluation_id,ordinal)
);
CREATE TABLE ga_wave_call (
    evaluation_id INTEGER NOT NULL REFERENCES ga_evaluation(evaluation_id) ON DELETE CASCADE,
    ordinal INTEGER NOT NULL CHECK(ordinal>=0), seconds REAL NOT NULL, wave INTEGER NOT NULL,
    countdown_seconds INTEGER, early_call_bonus INTEGER NOT NULL,
    money_before INTEGER NOT NULL, money_after INTEGER NOT NULL, PRIMARY KEY(evaluation_id,ordinal)
);
CREATE TABLE ga_built_tower (
    evaluation_id INTEGER NOT NULL REFERENCES ga_evaluation(evaluation_id) ON DELETE CASCADE,
    tower_kind TEXT NOT NULL, count INTEGER NOT NULL CHECK(count>=0), PRIMARY KEY(evaluation_id,tower_kind)
);
-- Membership only: retaining a solution never copies its DNA or evaluations.
CREATE TABLE genetic_solution (
    run_id TEXT NOT NULL, candidate_id INTEGER NOT NULL, panel TEXT NOT NULL,
    PRIMARY KEY(run_id,candidate_id,panel),
    FOREIGN KEY(run_id,candidate_id,panel) REFERENCES ga_panel(run_id,candidate_id,panel) ON DELETE CASCADE
);
CREATE VIEW ga_solution_details AS
SELECT s.run_id,s.candidate_id,s.panel,r.format_version,r.executable_sha256,r.level_info_id,r.difficulty_id,
       r.starting_money,r.bounty_fraction,r.max_game_seconds,r.content_sha256,r.heroes_enabled,c.stars_used
FROM genetic_solution s JOIN ga_run r USING(run_id) JOIN ga_candidate c USING(run_id,candidate_id);

-- Player-controlled sites, separate from purchase prerequisites.
CREATE TABLE ga_tactical_order (
    strategy_id INTEGER NOT NULL REFERENCES ga_strategy(strategy_id) ON DELETE CASCADE,
    ordinal INTEGER NOT NULL CHECK(ordinal>=0),
    slot INTEGER NOT NULL CHECK(slot>=0),
    kind TEXT NOT NULL CHECK(kind IN ('rally','obstacles','demolition')),
    path_index INTEGER NOT NULL CHECK(path_index>=0),
    progress REAL NOT NULL CHECK(progress BETWEEN 0 AND 1),
    PRIMARY KEY(strategy_id,ordinal), UNIQUE(strategy_id,slot,kind)
);
CREATE TABLE ga_tactical_action (
    evaluation_id INTEGER NOT NULL REFERENCES ga_evaluation(evaluation_id) ON DELETE CASCADE,
    ordinal INTEGER NOT NULL CHECK(ordinal>=0),
    seconds REAL NOT NULL CHECK(seconds>=0), wave INTEGER NOT NULL CHECK(wave>=0),
    slot INTEGER NOT NULL CHECK(slot>=0),
    kind TEXT NOT NULL CHECK(kind IN ('rally','obstacles','demolition')),
    x REAL NOT NULL, y REAL NOT NULL,
    PRIMARY KEY(evaluation_id,ordinal)
);
