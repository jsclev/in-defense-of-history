-- Required: :run_id. Archive order is the frozen population's actual order.
SELECT c.completed_generations,c.next_candidate_id,c.cache_hits,s.stars_used,s.selection_key,
       s.introduced_generation,s.active,s.plans_per_selection,s.minimum_candidates,
       COUNT(m.candidate_id) AS evaluated_candidates,SUM(m.archive_ordinal IS NOT NULL) AS archived_candidates
FROM ga_checkpoint c JOIN ga_population_selection s USING(run_id)
LEFT JOIN ga_population_member m USING(run_id,stars_used,selection_key)
WHERE c.run_id=:run_id GROUP BY c.run_id,s.stars_used,s.selection_key ORDER BY s.stars_used,s.ordinal;

SELECT stars_used,selection_key,candidate_id,archive_ordinal FROM ga_population_member
WHERE run_id=:run_id AND archive_ordinal IS NOT NULL ORDER BY stars_used,selection_key,archive_ordinal;
