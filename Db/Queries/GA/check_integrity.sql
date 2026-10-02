PRAGMA integrity_check;
PRAGMA foreign_key_check;
-- All queries below should return zero rows. They detect missing original samples
-- and missing child rows even if someone edited with foreign_keys disabled.
SELECT p.run_id,p.candidate_id,p.panel,p.sample_count,COUNT(e.evaluation_id) AS actual
FROM ga_panel p LEFT JOIN ga_evaluation e USING(run_id,candidate_id,panel)
GROUP BY p.run_id,p.candidate_id,p.panel HAVING actual<>p.sample_count;
SELECT strategy_id FROM ga_strategy s
WHERE decision_count<>(SELECT COUNT(*) FROM ga_decision d WHERE d.strategy_id=s.strategy_id)
   OR meta_upgrade_count<>(SELECT COUNT(*) FROM ga_meta_upgrade u WHERE u.strategy_id=s.strategy_id)
   OR early_wave_count<>(SELECT COUNT(*) FROM ga_early_wave w WHERE w.strategy_id=s.strategy_id);

-- Validate the stored compact evidence without replaying any candidate.
SELECT p.evaluation_id FROM ga_playstyle p
WHERE p.purchase_count<>(SELECT COUNT(*) FROM ga_playstyle_purchase c WHERE c.evaluation_id=p.evaluation_id)
   OR p.tower_count<>(SELECT COUNT(*) FROM ga_playstyle_tower t WHERE t.evaluation_id=p.evaluation_id);
SELECT t.evaluation_id,t.ordinal FROM ga_playstyle_tower t
WHERE t.route_count<>(SELECT COUNT(*) FROM ga_playstyle_route r
                     WHERE r.evaluation_id=t.evaluation_id AND r.tower_ordinal=t.ordinal);
-- Legacy absence is unknown, but every genetic-v10/v11 evaluation requires the
-- new evidence. In-progress saves are transactional, so no partial rows appear.
SELECT e.evaluation_id FROM ga_evaluation e JOIN ga_study s USING(run_id)
LEFT JOIN ga_playstyle p USING(evaluation_id)
WHERE s.algorithm IN ('genetic-v10','genetic-v11') AND p.evaluation_id IS NULL;
SELECT t.evaluation_id,t.ordinal FROM ga_playstyle_tower t
JOIN ga_evaluation e USING(evaluation_id) JOIN ga_study s USING(run_id)
WHERE s.algorithm IN ('genetic-v10','genetic-v11') AND t.slowing_seconds IS NULL;
