-- Actual successful opening and first five later builds for each candidate's
-- representative seed. Unknown legacy data produces an explicit row, not a
-- fabricated opening inferred from time-zero orders. Full DNA is in ga_decision.
SELECT f.run_id,f.panel,f.candidate_id,f.placement_seed,f.placements_known,
       p.phase,p.ordinal+1 AS placement_number,p.slot,p.tower_id,t.tower_name,
       f.source_recording_id
FROM ga_candidate_placement_profile f
LEFT JOIN ga_placement p ON p.evaluation_id=f.placement_evaluation_id
LEFT JOIN tower t ON lower(t.id)=lower(p.tower_id)
ORDER BY f.run_id,f.panel,f.stars_used,f.win_rate DESC,f.mean_victory_lives DESC,
         f.mean_waves_started DESC,f.mean_survival_seconds DESC,f.candidate_id,p.phase,p.ordinal;
