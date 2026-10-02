-- Works for both invocation databases and the shipping catalog. Optional :run_id.
SELECT d.run_id,l.level_name,d.difficulty_id,d.starting_money,d.bounty_fraction,d.content_sha256,
       d.candidate_id,d.stars_used,d.panel,f.samples,f.expected_samples,f.panel_complete,f.victories,f.win_rate,
       f.mean_victory_lives,f.mean_waves_started,f.mean_survival_seconds,p.level_run_id,p.matches_evaluation
FROM ga_solution_details d JOIN ga_candidate_fitness f USING(run_id,candidate_id,panel)
JOIN level_info l ON l.id=d.level_info_id
LEFT JOIN genetic_solution_recording p USING(run_id,candidate_id,panel)
WHERE :run_id IS NULL OR d.run_id=:run_id
ORDER BY d.run_id,d.panel,d.stars_used,f.win_rate DESC,f.mean_victory_lives DESC,
         f.mean_waves_started DESC,f.mean_survival_seconds DESC,d.candidate_id;
