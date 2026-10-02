-- Run as-is. Every planned purchase for the complete Charleston validation
-- candidates, ordered by fitness then decision priority. No bound parameters.
-- These are intentions, not executed purchase receipts. seconds/earliest_wave
-- are eligibility gates; save_for_purchase can block lower-priority decisions.
WITH ranked AS (
    SELECT f.*, ROW_NUMBER() OVER (
        ORDER BY win_rate DESC, mean_victory_lives DESC,
                 mean_waves_started DESC, mean_survival_seconds DESC, candidate_id
    ) AS fitness_rank
    FROM ga_candidate_fitness f
    WHERE run_id = 'F486C197-4FBD-4C72-BC30-18B17A25B085'
      AND stars_used = 42 AND panel = 'validation' AND panel_complete = 1
)
SELECT r.fitness_rank,r.candidate_id,d.ordinal+1 AS decision_priority,
       d.slot,d.action,t.tower_name AS planned_branch,p.path_name AS ability_upgrade,
       d.seconds AS earliest_seconds,d.earliest_wave,d.save_for_purchase,
       d.tower_id,d.upgrade_path_id
FROM ranked r JOIN ga_decision d USING(strategy_id)
LEFT JOIN tower t ON lower(t.id)=lower((
    SELECT b.tower_id FROM ga_decision b
    WHERE b.strategy_id=d.strategy_id AND b.slot=d.slot AND b.action='build' AND b.ordinal<=d.ordinal
    ORDER BY b.ordinal DESC LIMIT 1
))
LEFT JOIN tower_upgrade_path p ON p.id=d.upgrade_path_id
ORDER BY r.fitness_rank,d.ordinal;
