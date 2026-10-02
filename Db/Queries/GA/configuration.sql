-- Required: :run_id. Exact captured study choices and battle context.
SELECT * FROM ga_run WHERE run_id=:run_id;
SELECT * FROM ga_study WHERE run_id=:run_id;
SELECT * FROM ga_hero WHERE run_id=:run_id ORDER BY ordinal;
SELECT * FROM ga_study_seed WHERE run_id=:run_id ORDER BY panel,ordinal;
SELECT * FROM ga_study_star WHERE run_id=:run_id ORDER BY ordinal;
SELECT u.upgrade_id,m.title,m.star_cost FROM ga_study_upgrade u
JOIN meta_upgrade m ON m.upgrade_key=u.upgrade_id WHERE u.run_id=:run_id ORDER BY u.upgrade_id;
SELECT * FROM ga_tower_limit WHERE run_id=:run_id ORDER BY tower_kind;
SELECT * FROM ga_input_strategy WHERE run_id=:run_id ORDER BY role,ordinal;
