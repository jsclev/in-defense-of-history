-- Compact candidate evidence. Absent header = unknown legacy placements.
-- Original fitness and demonstration provenance remain separate.
CREATE TABLE ga_placement_plan (
    evaluation_id INTEGER PRIMARY KEY REFERENCES ga_evaluation(evaluation_id) ON DELETE CASCADE,
    initial_count INTEGER NOT NULL CHECK(initial_count>=0),
    subsequent_count INTEGER NOT NULL CHECK(subsequent_count>=0),
    source_recording_id TEXT
);
CREATE TABLE ga_placement (
    evaluation_id INTEGER NOT NULL REFERENCES ga_placement_plan(evaluation_id) ON DELETE CASCADE,
    phase TEXT NOT NULL CHECK(phase IN ('initial','subsequent')),
    ordinal INTEGER NOT NULL CHECK(ordinal>=0),
    slot INTEGER NOT NULL CHECK(slot>=0),
    tower_id TEXT NOT NULL,
    PRIMARY KEY(evaluation_id,phase,ordinal),
    UNIQUE(evaluation_id,slot)
);

-- One deterministic representative seed per candidate/panel. Ranking remains
-- the original full-panel fitness; unknown placement data stays NULL.
CREATE VIEW ga_candidate_placement_profile AS
SELECT f.*,e.evaluation_id AS placement_evaluation_id,e.seed AS placement_seed,
       (p.evaluation_id IS NOT NULL) AS placements_known,
       p.initial_count,p.subsequent_count,p.source_recording_id
FROM ga_candidate_fitness f JOIN ga_evaluation e ON e.evaluation_id=(
    SELECT v.evaluation_id FROM ga_evaluation v
    WHERE v.run_id=f.run_id AND v.candidate_id=f.candidate_id AND v.panel=f.panel
    ORDER BY (v.outcome='victory') DESC,
        CASE WHEN v.outcome='victory' THEN v.lives_remaining ELSE 0 END DESC,
        v.waves_started DESC,CASE WHEN v.outcome='defeat' THEN v.seconds ELSE 0 END DESC,
        length(v.seed),v.seed LIMIT 1)
LEFT JOIN ga_placement_plan p USING(evaluation_id);
