-- Compact original evidence; missing header means unknown legacy playstyle.
CREATE TABLE ga_playstyle (
    evaluation_id INTEGER PRIMARY KEY REFERENCES ga_evaluation(evaluation_id) ON DELETE CASCADE,
    duration REAL NOT NULL CHECK(duration>=0),
    purchase_count INTEGER NOT NULL CHECK(purchase_count>=0),
    tower_count INTEGER NOT NULL CHECK(tower_count>=0),
    reinforcement_actions INTEGER NOT NULL CHECK(reinforcement_actions>=0),
    early_wave_actions INTEGER NOT NULL CHECK(early_wave_actions>=0),
    demolition_actions INTEGER NOT NULL CHECK(demolition_actions>=0),
    starting_lives INTEGER NOT NULL CHECK(starting_lives>0),
    minimum_lives INTEGER NOT NULL CHECK(minimum_lives>=0)
);
CREATE TABLE ga_playstyle_purchase (
    evaluation_id INTEGER NOT NULL REFERENCES ga_playstyle(evaluation_id) ON DELETE CASCADE,
    ordinal INTEGER NOT NULL CHECK(ordinal>=0),
    seconds REAL NOT NULL CHECK(seconds>=0),
    wave INTEGER NOT NULL CHECK(wave>=0),
    slot INTEGER NOT NULL CHECK(slot>=0),
    family_id TEXT NOT NULL, tier_id TEXT NOT NULL,
    action TEXT NOT NULL CHECK(action IN ('build','upgrade','ability')),
    path_id TEXT,
    cost INTEGER NOT NULL CHECK(cost>=0),
    CHECK((action='ability')=(path_id IS NOT NULL)),
    PRIMARY KEY(evaluation_id,ordinal)
);
CREATE TABLE ga_playstyle_tower (
    evaluation_id INTEGER NOT NULL REFERENCES ga_playstyle(evaluation_id) ON DELETE CASCADE,
    ordinal INTEGER NOT NULL CHECK(ordinal>=0),
    phase INTEGER NOT NULL CHECK(phase BETWEEN 0 AND 3),
    seconds REAL NOT NULL CHECK(seconds>=0),
    slot INTEGER NOT NULL CHECK(slot>=0),
    family_id TEXT NOT NULL, tier_id TEXT NOT NULL,
    level INTEGER NOT NULL CHECK(level>=1), branch INTEGER NOT NULL CHECK(branch>=1),
    attack_mode TEXT NOT NULL,
    spent INTEGER NOT NULL CHECK(spent>=0), damage REAL NOT NULL CHECK(damage>=0),
    shots INTEGER NOT NULL CHECK(shots>=0), blocking_seconds REAL NOT NULL CHECK(blocking_seconds>=0),
    slowing_seconds REAL CHECK(slowing_seconds IS NULL OR slowing_seconds>=0),
    income INTEGER NOT NULL CHECK(income>=0), detonations INTEGER NOT NULL CHECK(detonations>=0),
    route_count INTEGER NOT NULL CHECK(route_count>=0),
    PRIMARY KEY(evaluation_id,ordinal), UNIQUE(evaluation_id,phase,slot)
);
CREATE TABLE ga_playstyle_route (
    evaluation_id INTEGER NOT NULL,
    tower_ordinal INTEGER NOT NULL,
    ordinal INTEGER NOT NULL CHECK(ordinal>=0),
    route_index INTEGER NOT NULL CHECK(route_index>=0),
    progress REAL NOT NULL CHECK(progress BETWEEN 0 AND 1),
    PRIMARY KEY(evaluation_id,tower_ordinal,ordinal),
    FOREIGN KEY(evaluation_id,tower_ordinal) REFERENCES ga_playstyle_tower(evaluation_id,ordinal) ON DELETE CASCADE
);
