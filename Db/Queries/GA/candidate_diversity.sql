-- All complete candidates with at least one win, in original fitness order.
-- Compare each with the highest-ranked winner in its run/panel/star budget.
-- Pairwise diagnostics against the strongest winner. The Swift selector chooses
-- alternatives by composition novelty and checks ALL earlier selections.
-- Opening-only diagnostics: full selection also uses ga_playstyle evidence.
-- Position/five-placement differences are soft preferences, not vetoes.
-- Missing legacy placement data is UNKNOWN, not a failed diversity check.
-- No parameters, simulations, playback, or writes.
WITH ranked AS (
    SELECT f.*,ROW_NUMBER() OVER (
        PARTITION BY run_id,panel,stars_used
        ORDER BY win_rate DESC,mean_victory_lives DESC,
                 mean_waves_started DESC,mean_survival_seconds DESC,candidate_id
    ) AS fitness_rank
    FROM ga_candidate_placement_profile f WHERE panel_complete=1 AND victories>0
), pairs AS (
    SELECT c.*,r.candidate_id AS reference_candidate_id,r.placement_evaluation_id AS reference_evaluation_id,r.placements_known AS reference_known,
           r.initial_count AS reference_initial_count
    FROM ranked c JOIN ranked r
      ON r.run_id=c.run_id AND r.panel=c.panel AND r.stars_used=c.stars_used
     AND r.fitness_rank=1
), initial AS (
    SELECT evaluation_id,slot,lower(tower_id) AS tower_id FROM ga_placement WHERE phase='initial'
), families AS (
    SELECT evaluation_id,tower_id,COUNT(*) AS quantity FROM initial GROUP BY evaluation_id,tower_id
), later AS (
    SELECT evaluation_id,slot,tower_id,ordinal+1 AS placement_number
    FROM ga_placement WHERE phase='subsequent' 
), counts AS (
    SELECT p.*,
      (SELECT COUNT(*) FROM initial a WHERE a.evaluation_id=p.placement_evaluation_id
       AND NOT EXISTS (SELECT 1 FROM initial b WHERE b.evaluation_id=p.reference_evaluation_id AND b.tower_id=a.tower_id)) AS candidate_new_family_towers,
      (SELECT COUNT(*) FROM initial b WHERE b.evaluation_id=p.reference_evaluation_id
       AND NOT EXISTS (SELECT 1 FROM initial a WHERE a.evaluation_id=p.placement_evaluation_id AND a.tower_id=b.tower_id)) AS reference_new_family_towers,
      (SELECT COUNT(*) FROM initial a WHERE a.evaluation_id=p.placement_evaluation_id)
      + (SELECT COUNT(*) FROM initial b WHERE b.evaluation_id=p.reference_evaluation_id)
      - (SELECT COUNT(*) FROM initial a JOIN initial b ON a.slot=b.slot
         WHERE a.evaluation_id=p.placement_evaluation_id AND b.evaluation_id=p.reference_evaluation_id)
      AS initial_slots,
      (SELECT COUNT(*) FROM initial a JOIN initial b
         ON a.slot=b.slot AND lower(a.tower_id)=lower(b.tower_id)
       WHERE a.evaluation_id=p.placement_evaluation_id AND b.evaluation_id=p.reference_evaluation_id)
      AS matching_initial_slots,
      (SELECT COUNT(*) FROM later a JOIN later b USING(placement_number)
       WHERE a.evaluation_id=p.placement_evaluation_id AND b.evaluation_id=p.reference_evaluation_id
         AND a.placement_number<=5) AS compared_next_placements,
      (SELECT COUNT(*) FROM later a JOIN later b USING(placement_number)
       WHERE a.evaluation_id=p.placement_evaluation_id AND b.evaluation_id=p.reference_evaluation_id
         AND a.placement_number<=5 AND
         (a.slot<>b.slot OR lower(a.tower_id)<>lower(b.tower_id))) AS different_next_placements
    FROM pairs p
), comparisons AS (
    SELECT c.*,
      MAX(CASE WHEN initial_count>0 THEN 1.0*candidate_new_family_towers/initial_count ELSE 0 END,
          CASE WHEN reference_initial_count>0 THEN 1.0*reference_new_family_towers/reference_initial_count ELSE 0 END) AS new_family_share,
      CASE WHEN initial_count>0 AND reference_initial_count>0 THEN 1.0-COALESCE((
          SELECT SUM(MIN(1.0*a.quantity/c.initial_count,1.0*b.quantity/c.reference_initial_count))
          FROM families a JOIN families b USING(tower_id)
          WHERE a.evaluation_id=c.placement_evaluation_id AND b.evaluation_id=c.reference_evaluation_id
      ),0.0) ELSE 0.0 END AS composition_difference
    FROM counts c
)
SELECT run_id,panel,stars_used,fitness_rank,candidate_id,reference_candidate_id,
       victories,samples,win_rate,mean_victory_lives,mean_waves_started,mean_survival_seconds,
       placements_known,reference_known,placement_seed,source_recording_id,
       CASE WHEN placements_known AND reference_known THEN ROUND(100.0*new_family_share,2) END AS new_family_percent,
       CASE WHEN placements_known AND reference_known THEN ROUND(100.0*composition_difference,2) END AS composition_difference_percent,
       CASE WHEN placements_known AND reference_known THEN initial_slots END AS initial_slots,
       CASE WHEN placements_known AND reference_known THEN initial_slots-matching_initial_slots END AS different_initial_slots,
       CASE WHEN placements_known AND reference_known
            THEN ROUND(100.0*(initial_slots-matching_initial_slots)/NULLIF(initial_slots,0),2)
       END AS initial_difference_percent,
       CASE WHEN placements_known AND reference_known THEN compared_next_placements END AS compared_next_placements,
       CASE WHEN placements_known AND reference_known THEN different_next_placements END AS different_next_placements,
       CASE WHEN NOT placements_known OR NOT reference_known THEN NULL
            WHEN initial_slots>0 AND new_family_share>=0.25
            THEN 1 ELSE 0 END AS material_opening_difference
FROM comparisons
ORDER BY run_id,panel,stars_used,fitness_rank;
