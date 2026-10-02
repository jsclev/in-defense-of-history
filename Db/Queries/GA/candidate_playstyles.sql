-- Original fitness order; one row per representative phase/tower. No replay.
-- phase: 0 opening, 1 one-third of waves, 2 two-thirds, 3 final.
-- NULL evidence means unknown legacy data, never zero participation.
-- slowing_seconds sums time across affected enemies; simultaneous slowing can
-- therefore exceed the battle's duration.
WITH ranked AS (
  SELECT f.*,ROW_NUMBER() OVER (
    PARTITION BY run_id,panel,stars_used
    ORDER BY win_rate DESC,mean_victory_lives DESC,mean_waves_started DESC,
             mean_survival_seconds DESC,candidate_id) AS fitness_rank
  FROM ga_candidate_placement_profile f WHERE panel_complete=1
)
SELECT f.run_id,f.panel,f.fitness_rank,f.candidate_id,f.win_rate,f.mean_victory_lives,
       p.minimum_lives,p.duration,p.reinforcement_actions,p.early_wave_actions,p.demolition_actions,
       t.phase,t.seconds,t.slot,base.tower_name AS family,tier.tower_name AS actual_tier,
       t.level,t.branch,t.attack_mode,t.spent,t.damage,t.shots,t.blocking_seconds,t.slowing_seconds,t.income,t.detonations,
       (SELECT group_concat('route '||r.route_index||' at '||round(100*r.progress,1)||'%', '; ')
        FROM ga_playstyle_route r WHERE r.evaluation_id=t.evaluation_id AND r.tower_ordinal=t.ordinal) AS covered_routes
FROM ranked f
LEFT JOIN ga_playstyle p ON p.evaluation_id=f.placement_evaluation_id
LEFT JOIN ga_playstyle_tower t ON t.evaluation_id=p.evaluation_id
LEFT JOIN tower base ON lower(base.id)=lower(t.family_id)
LEFT JOIN tower tier ON lower(tier.id)=lower(t.tier_id)
ORDER BY f.run_id,f.panel,f.fitness_rank,t.phase,t.slot;

-- Successful purchases, including actual timing, prices and ability paths.
SELECT f.run_id,f.panel,f.candidate_id,f.win_rate,f.mean_victory_lives,
       p.ordinal,p.seconds,p.wave,p.slot,p.action,t.tower_name,p.path_id,p.cost
FROM ga_candidate_placement_profile f
JOIN ga_playstyle_purchase p ON p.evaluation_id=f.placement_evaluation_id
JOIN tower t ON lower(t.id)=lower(p.tier_id)
WHERE f.panel_complete=1
ORDER BY f.run_id,f.panel,f.win_rate DESC,f.mean_victory_lives DESC,
         f.mean_waves_started DESC,f.mean_survival_seconds DESC,f.candidate_id,p.ordinal;
