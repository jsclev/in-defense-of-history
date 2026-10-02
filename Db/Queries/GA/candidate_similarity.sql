-- Run as-is. Compare all complete Charleston validation candidates in fitness
-- order (3 pairs in the phone bundle, 276 in the completed study database).
-- These are separate structural measures, NOT a gameplay-equivalence score.
-- Tower agreement compares intended branches at the same zero-based slot;
-- it excludes upgrade depth, purchase order/timing and whether purchases occurred.
-- Meta agreement ignores list order. Wave/reinforcement agreement uses every
-- stored policy field with exact numeric comparisons. See candidate_makeup.sql
-- and top_candidate_actions.sql for the full plans.
WITH ranked AS (
    SELECT f.*, ROW_NUMBER() OVER (
        ORDER BY win_rate DESC, mean_victory_lives DESC,
                 mean_waves_started DESC, mean_survival_seconds DESC, candidate_id
    ) AS fitness_rank
    FROM ga_candidate_fitness f
    WHERE run_id = 'F486C197-4FBD-4C72-BC30-18B17A25B085'
      AND stars_used = 42 AND panel = 'validation' AND panel_complete = 1
), builds AS (
    SELECT DISTINCT strategy_id,slot,lower(tower_id) AS tower_id
    FROM ga_decision WHERE action='build'
), pairs AS (
    SELECT a.fitness_rank AS rank_a,b.fitness_rank AS rank_b,
           a.candidate_id AS candidate_a,b.candidate_id AS candidate_b,
           a.strategy_id AS strategy_a,b.strategy_id AS strategy_b
    FROM ranked a JOIN ranked b ON a.fitness_rank<b.fitness_rank
)
SELECT p.rank_a,p.candidate_a,p.rank_b,p.candidate_b,
       (SELECT COUNT(*) FROM (
           SELECT slot FROM builds WHERE strategy_id=p.strategy_a
           UNION SELECT slot FROM builds WHERE strategy_id=p.strategy_b
       )) AS compared_tower_slots,
       (SELECT COUNT(*) FROM (
           SELECT slot FROM builds WHERE strategy_id=p.strategy_a
           UNION SELECT slot FROM builds WHERE strategy_id=p.strategy_b
       ) slots WHERE NOT EXISTS (
           SELECT tower_id FROM builds WHERE strategy_id=p.strategy_a AND slot=slots.slot
           EXCEPT SELECT tower_id FROM builds WHERE strategy_id=p.strategy_b AND slot=slots.slot
       ) AND NOT EXISTS (
           SELECT tower_id FROM builds WHERE strategy_id=p.strategy_b AND slot=slots.slot
           EXCEPT SELECT tower_id FROM builds WHERE strategy_id=p.strategy_a AND slot=slots.slot
       )) AS same_tower_slots,
       a.meta_upgrade_count AS meta_count_a,b.meta_upgrade_count AS meta_count_b,
       (SELECT COUNT(*) FROM ga_meta_upgrade x JOIN ga_meta_upgrade y USING(upgrade_id)
        WHERE x.strategy_id=p.strategy_a AND y.strategy_id=p.strategy_b) AS shared_meta_upgrades,
       (SELECT COALESCE(SUM(m.star_cost),0)
        FROM ga_meta_upgrade x JOIN ga_meta_upgrade y USING(upgrade_id)
        JOIN meta_upgrade m ON m.upgrade_key=x.upgrade_id
        WHERE x.strategy_id=p.strategy_a AND y.strategy_id=p.strategy_b) AS shared_meta_stars,
       (SELECT COUNT(*) FROM (
           SELECT wave FROM ga_early_wave WHERE strategy_id=p.strategy_a
           UNION SELECT wave FROM ga_early_wave WHERE strategy_id=p.strategy_b
       )) AS compared_wave_rules,
       (SELECT COUNT(*) FROM ga_early_wave x JOIN ga_early_wave y USING(wave)
        WHERE x.strategy_id=p.strategy_a AND y.strategy_id=p.strategy_b
          AND x.policy=y.policy AND x.seconds IS y.seconds
          AND x.countdown_seconds IS y.countdown_seconds AND x.enemy_count IS y.enemy_count) AS same_wave_rules,
       (a.reinforcement_priority=b.reinforcement_priority
        AND a.reinforcement_x IS b.reinforcement_x AND a.reinforcement_y IS b.reinforcement_y
        AND a.reinforcement_hold_seconds=b.reinforcement_hold_seconds) AS same_reinforcement_rule,
       a.decision_count AS purchase_steps_a,b.decision_count AS purchase_steps_b
FROM pairs p JOIN ga_strategy a ON a.strategy_id=p.strategy_a
JOIN ga_strategy b ON b.strategy_id=p.strategy_b
ORDER BY p.rank_a,p.rank_b;
