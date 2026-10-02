-- Required: :run_id, :candidate_id. Ordered player intent, not purchase receipts.
SELECT d.ordinal,d.seconds,d.earliest_wave,d.save_for_purchase,d.action,d.slot,
       d.tower_id,t.tower_name,d.upgrade_path_id,p.path_name
FROM ga_candidate c JOIN ga_decision d USING(strategy_id)
LEFT JOIN tower t ON lower(d.tower_id)=lower(t.id)
LEFT JOIN tower_upgrade_path p ON d.upgrade_path_id=p.id
WHERE c.run_id=:run_id AND c.candidate_id=:candidate_id ORDER BY d.ordinal;

SELECT u.ordinal,u.upgrade_id,m.title,m.star_cost
FROM ga_candidate c JOIN ga_meta_upgrade u USING(strategy_id)
JOIN meta_upgrade m ON m.upgrade_key=u.upgrade_id
WHERE c.run_id=:run_id AND c.candidate_id=:candidate_id ORDER BY u.ordinal;

SELECT s.reinforcement_priority,s.reinforcement_x,s.reinforcement_y,s.reinforcement_hold_seconds
FROM ga_candidate c JOIN ga_strategy s USING(strategy_id)
WHERE c.run_id=:run_id AND c.candidate_id=:candidate_id;

SELECT w.* FROM ga_candidate c JOIN ga_early_wave w USING(strategy_id)
WHERE c.run_id=:run_id AND c.candidate_id=:candidate_id ORDER BY w.ordinal;
