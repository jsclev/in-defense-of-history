-- Required: :run_id, :candidate_id. Optional :panel (NULL = both).
-- level_run_id may be NULL: routine fitness evaluation does not record playback.
SELECT e.evaluation_id,e.panel,e.ordinal,e.seed,e.outcome,e.seconds,e.lives_remaining,
       e.gold_remaining,e.gold_earned,e.killed,e.leaked,e.waves_started,e.level_run_id
FROM ga_evaluation e
WHERE e.run_id=:run_id AND e.candidate_id=:candidate_id AND (:panel IS NULL OR e.panel=:panel)
ORDER BY e.panel,e.ordinal;
