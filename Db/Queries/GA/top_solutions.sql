-- Run as-is: the top three Charleston candidates selected for the phone.
-- Works in Db/in_defense_of_history.sqlite and the completed run DB.
-- These are original held-out results, not the separate playback outcomes.
-- These three passed the complete-set playstyle selector. Their held-out fitness
-- ranks in the full run are 4, 19 and 20; a plain LIMIT 3 would show other plans.
-- Remove the candidate_id filter and change LIMIT to inspect the full ranking.
-- Opening makeup is successful pre-wave-one construction in the representative
-- original seed, also used for its demonstration; it is not a planned branch.
SELECT candidate_id, generation, stars_used,
       victories, samples AS validation_battles,
       ROUND(100.0 * win_rate, 2) AS win_percent,
       ROUND(mean_victory_lives, 3) AS average_lives_remaining,
       (SELECT GROUP_CONCAT(label, '; ') FROM (
           SELECT COUNT(*) || ' ' || t.tower_name AS label
           FROM ga_placement p JOIN tower t ON lower(t.id)=lower(p.tower_id)
           WHERE p.evaluation_id=f.placement_evaluation_id AND p.phase='initial'
           GROUP BY t.id,t.tower_name ORDER BY t.tower_name
       )) AS initial_towers
FROM ga_candidate_placement_profile f
WHERE run_id = 'F486C197-4FBD-4C72-BC30-18B17A25B085'
  AND stars_used = 42
  AND panel = 'validation'
  AND panel_complete = 1
  AND candidate_id IN (10585, 11442, 12886)
ORDER BY win_rate DESC, mean_victory_lives DESC,
         mean_waves_started DESC, mean_survival_seconds DESC,
         candidate_id
LIMIT 3;
