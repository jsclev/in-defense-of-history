-- Every evaluated candidate, including losers: no shortlist filter or LIMIT.
-- Run against a study database; the phone bundle contains only its installed plans.
-- Training is the common seed panel available for every candidate. Validation
-- is a separate panel and must not be mixed into this fitness ordering.
-- strategy_id links directly to ga_decision, ga_meta_upgrade, ga_early_wave
-- and ga_strategy for the complete constituent plan.
SELECT f.run_id,f.candidate_id,f.strategy_id,f.generation,f.stars_used,
       f.victories,f.samples,f.win_rate,f.mean_victory_lives,
       f.mean_waves_started,f.mean_survival_seconds,f.panel_complete,
       s.decision_count,s.meta_upgrade_count,s.early_wave_count,
       s.reinforcement_priority,s.reinforcement_hold_seconds
FROM ga_candidate_fitness f
JOIN ga_strategy s USING(strategy_id)
WHERE f.panel='training'
ORDER BY f.run_id,f.stars_used,f.win_rate DESC,f.mean_victory_lives DESC,
         f.mean_waves_started DESC,f.mean_survival_seconds DESC,f.candidate_id;
