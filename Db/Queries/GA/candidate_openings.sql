-- Run as-is against a complete study or the phone bundle. One row per candidate
-- and panel, in ORIGINAL fitness order. Every candidate is included, even losers.
-- Makeup is the deterministic representative seed, not an aggregate of seeds.
-- A NULL list can be empty or unknown; evidence flags distinguish those cases.
-- Activity lists report known participation, not inferred combat effects.
-- The full selector checks matching seeds
-- across the entire held-out panel; this summary is for human inspection.
WITH ranked AS (
    SELECT f.*, ROW_NUMBER() OVER (
        PARTITION BY run_id,panel,stars_used
        ORDER BY win_rate DESC,mean_victory_lives DESC,mean_waves_started DESC,
                 mean_survival_seconds DESC,candidate_id
    ) AS fitness_rank
    FROM ga_candidate_placement_profile f WHERE panel_complete=1
)
SELECT f.run_id,f.panel,f.stars_used,f.fitness_rank,f.candidate_id,
       f.victories,f.samples,ROUND(f.mean_victory_lives,3) AS average_lives_remaining,
       f.placement_seed,f.placements_known,
       EXISTS(SELECT 1 FROM ga_playstyle s
              WHERE s.evaluation_id=f.placement_evaluation_id) AS playstyle_known,
       NOT EXISTS(SELECT 1 FROM ga_playstyle_tower s
                  WHERE s.evaluation_id=f.placement_evaluation_id
                    AND s.slowing_seconds IS NULL)
           AND EXISTS(SELECT 1 FROM ga_playstyle s
                      WHERE s.evaluation_id=f.placement_evaluation_id) AS slowing_known,
       (SELECT GROUP_CONCAT(label, '; ') FROM (
           SELECT COUNT(*) || ' ' || t.tower_name AS label
           FROM ga_placement p JOIN tower t ON lower(t.id)=lower(p.tower_id)
           WHERE p.evaluation_id=f.placement_evaluation_id AND p.phase='initial'
           GROUP BY t.id,t.tower_name ORDER BY t.tower_name
       )) AS initial_tower_mix,
       (SELECT GROUP_CONCAT(label, '; ') FROM (
           SELECT COUNT(*) || ' ' || t.tower_name AS label
           FROM ga_placement p JOIN tower t ON lower(t.id)=lower(p.tower_id)
           WHERE p.evaluation_id=f.placement_evaluation_id AND p.phase='initial'
             AND EXISTS (
                 SELECT 1 FROM ga_playstyle_tower a
                 WHERE a.evaluation_id=p.evaluation_id AND a.slot=p.slot
                   AND (a.damage>0 OR a.shots>0 OR a.blocking_seconds>0
                        OR a.slowing_seconds>0 OR a.income>0 OR a.detonations>0)
             )
           GROUP BY t.id,t.tower_name ORDER BY t.tower_name
       )) AS opening_towers_that_participated,
       (SELECT GROUP_CONCAT(label, '; ') FROM (
           SELECT 'slot ' || p.slot || ': ' || t.tower_name AS label
           FROM ga_placement p JOIN tower t ON lower(t.id)=lower(p.tower_id)
           WHERE p.evaluation_id=f.placement_evaluation_id AND p.phase='initial'
           ORDER BY p.slot
       )) AS initial_layout,
       (SELECT GROUP_CONCAT(label, '; ') FROM (
           SELECT (p.ordinal+1) || '. slot ' || p.slot || ': ' || t.tower_name AS label
           FROM ga_placement p JOIN tower t ON lower(t.id)=lower(p.tower_id)
           WHERE p.evaluation_id=f.placement_evaluation_id AND p.phase='subsequent'
           ORDER BY p.ordinal LIMIT 5
       )) AS next_five_builds
FROM ranked f
ORDER BY f.run_id,f.panel,f.stars_used,f.fitness_rank;
