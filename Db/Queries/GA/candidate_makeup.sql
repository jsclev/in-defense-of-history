-- Run as-is. One row per complete Charleston validation candidate, in fitness
-- order: 3 rows in the phone bundle, 24 in the completed study database.
-- Tower names are intended branches, not proof that every purchase occurred.
-- Slot numbers are the stored zero-based map slots. Inspect exact purchase
-- order/timing with top_candidate_actions.sql; compare pairs with candidate_similarity.sql.
WITH ranked AS (
    SELECT f.*, ROW_NUMBER() OVER (
        ORDER BY win_rate DESC, mean_victory_lives DESC,
                 mean_waves_started DESC, mean_survival_seconds DESC, candidate_id
    ) AS fitness_rank
    FROM ga_candidate_fitness f
    WHERE run_id = 'F486C197-4FBD-4C72-BC30-18B17A25B085'
      AND stars_used = 42 AND panel = 'validation' AND panel_complete = 1
), tower_plans AS (
    SELECT d.strategy_id,d.slot,d.ordinal,t.tower_name,
           (SELECT COUNT(*) FROM ga_decision u
            WHERE u.strategy_id=d.strategy_id AND u.slot=d.slot AND u.action='upgrade') AS level_upgrades,
           (SELECT GROUP_CONCAT(label, ', ') FROM (
               SELECT p.path_name || ' x' || COUNT(*) AS label
               FROM ga_decision u JOIN tower_upgrade_path p ON p.id=u.upgrade_path_id
               WHERE u.strategy_id=d.strategy_id AND u.slot=d.slot AND u.action='purchaseUpgrade'
               GROUP BY p.id,p.path_name ORDER BY MIN(u.ordinal)
           )) AS ability_upgrades
    FROM ga_decision d JOIN tower t ON lower(t.id)=lower(d.tower_id)
    WHERE d.action='build'
)
SELECT r.fitness_rank,r.candidate_id,r.generation,r.victories,
       r.samples AS validation_battles,r.win_rate,r.mean_victory_lives,
       r.mean_waves_started,r.mean_survival_seconds,r.stars_used,s.decision_count,
       (SELECT GROUP_CONCAT(label, '; ') FROM (
           SELECT 'slot ' || p.slot || ': ' || p.tower_name ||
                  ' (level-up steps=' || p.level_upgrades ||
                  CASE WHEN p.ability_upgrades IS NULL THEN '' ELSE '; ' || p.ability_upgrades END || ')' AS label
           FROM tower_plans p WHERE p.strategy_id=r.strategy_id ORDER BY p.slot,p.ordinal
       )) AS planned_towers_and_upgrades,
       (SELECT GROUP_CONCAT(label, '; ') FROM (
           SELECT m.title || ' (' || m.star_cost || ' stars)' AS label
           FROM ga_meta_upgrade u JOIN meta_upgrade m ON m.upgrade_key=u.upgrade_id
           WHERE u.strategy_id=r.strategy_id ORDER BY m.title
       )) AS campaign_upgrades,
       s.reinforcement_priority,s.reinforcement_x,s.reinforcement_y,s.reinforcement_hold_seconds,
       (SELECT GROUP_CONCAT(label, '; ') FROM (
           SELECT 'wave ' || w.wave || ': ' || w.policy ||
                  CASE WHEN w.seconds IS NULL THEN '' ELSE ', seconds=' || w.seconds END ||
                  CASE WHEN w.countdown_seconds IS NULL THEN '' ELSE ', countdown=' || w.countdown_seconds END ||
                  CASE WHEN w.enemy_count IS NULL THEN '' ELSE ', enemies=' || w.enemy_count END AS label
           FROM ga_early_wave w WHERE w.strategy_id=r.strategy_id ORDER BY w.wave
       )) AS wave_call_rules,
       (SELECT GROUP_CONCAT(label, '; ') FROM (
           SELECT h.long_name || ', ' || COALESCE(g.role,'not deployed') ||
                  CASE WHEN g.deployment_ordinal IS NULL THEN ''
                       ELSE ', x=' || g.x || ', y=' || g.y || ', AI=' || g.ai_enabled END AS label
           FROM ga_hero g JOIN hero h ON lower(h.id)=lower(g.hero_id)
           WHERE g.run_id=r.run_id ORDER BY g.ordinal
       )) AS heroes
FROM ranked r JOIN ga_strategy s USING(strategy_id)
ORDER BY r.fitness_rank;
