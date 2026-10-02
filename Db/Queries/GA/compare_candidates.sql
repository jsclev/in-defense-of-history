-- Required: :run_id, :candidate_a, :candidate_b. Optional :panel (validation).
-- Pair only the SAME seed; missing samples remain visible as NULLs.
WITH a AS (SELECT * FROM ga_evaluation WHERE run_id=:run_id AND candidate_id=:candidate_a AND panel=COALESCE(:panel,'validation')),
     b AS (SELECT * FROM ga_evaluation WHERE run_id=:run_id AND candidate_id=:candidate_b AND panel=COALESCE(:panel,'validation')),
     seeds AS (SELECT seed FROM a UNION SELECT seed FROM b)
SELECT seeds.seed,a.outcome AS a_outcome,b.outcome AS b_outcome,
       a.lives_remaining AS a_lives,b.lives_remaining AS b_lives,
       a.waves_started AS a_waves,b.waves_started AS b_waves,
       a.seconds AS a_seconds,b.seconds AS b_seconds,
       a.evaluation_id IS NOT NULL AND b.evaluation_id IS NOT NULL AS paired
FROM seeds LEFT JOIN a USING(seed) LEFT JOIN b USING(seed)
ORDER BY length(seeds.seed),seeds.seed;
