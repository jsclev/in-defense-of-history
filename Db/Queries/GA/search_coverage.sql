-- Run this on a genetic-v12 invocation database. All queries read saved data.
-- Working parents, persistent behavior champions and the complete candidate
-- pool are separate concepts; validation is selected from the complete pool.
SELECT s.run_id,s.stars_used,s.selection_key,s.active,s.introduced_generation,
       (SELECT count(*) FROM ga_population_member m
        WHERE m.run_id=s.run_id AND m.selection_key=s.selection_key AND m.stars_used=s.stars_used) AS all_candidates,
       (SELECT count(*) FROM ga_population_member m
        WHERE m.run_id=s.run_id AND m.selection_key=s.selection_key AND m.stars_used=s.stars_used
          AND m.archive_ordinal IS NOT NULL) AS working_parents,
       (SELECT count(*) FROM ga_population_niche n
        WHERE n.run_id=s.run_id AND n.selection_key=s.selection_key AND n.stars_used=s.stars_used) AS behavior_champions,
       (SELECT count(*) FROM ga_population_niche n
        WHERE n.run_id=s.run_id AND n.selection_key=s.selection_key AND n.stars_used=s.stars_used
          AND n.breeding_visits>0) AS niches_allocated_offspring
FROM ga_population_selection s ORDER BY s.run_id,s.stars_used,s.ordinal;

-- See which finalists would have been discarded by the former parent-only rule.
SELECT f.run_id,f.candidate_id,f.stars_used,f.win_rate,f.mean_victory_lives,
       m.archive_ordinal AS final_working_parent_rank
FROM ga_candidate_fitness f
LEFT JOIN ga_population_member m ON m.run_id=f.run_id AND m.candidate_id=f.candidate_id
WHERE f.panel='validation'
ORDER BY f.run_id,f.win_rate DESC,f.mean_victory_lives DESC,
         f.mean_waves_started DESC,f.mean_survival_seconds DESC,f.candidate_id;

-- Best original training evidence for each persistent behavior niche.
SELECT n.run_id,n.selection_key,n.niche,n.candidate_id,n.breeding_visits,
       f.win_rate,f.mean_victory_lives,f.mean_waves_started
FROM ga_population_niche n
JOIN ga_candidate_fitness f ON f.run_id=n.run_id AND f.candidate_id=n.candidate_id AND f.panel='training'
ORDER BY n.run_id,f.win_rate DESC,f.mean_victory_lives DESC,n.candidate_id;
