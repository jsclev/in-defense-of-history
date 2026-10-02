-- No parameters. Lists GA studies with their current progress and budgets.
SELECT o.*,s.status,s.started_at,s.finished_at,s.iterations_per_second,
       (SELECT COUNT(*) FROM ga_candidate c WHERE c.run_id=o.run_id) AS candidates,
       (SELECT COUNT(*) FROM ga_evaluation e WHERE e.run_id=o.run_id) AS original_evaluations
FROM ga_study_overview o LEFT JOIN simulator_run s ON s.id=o.run_id
ORDER BY s.started_at DESC,o.run_id;
