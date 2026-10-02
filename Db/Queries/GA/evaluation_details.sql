-- Required: :evaluation_id from evaluations.sql. These are engine observations.
SELECT * FROM ga_wave_economy WHERE evaluation_id=:evaluation_id ORDER BY ordinal;
SELECT * FROM ga_wave_progress WHERE evaluation_id=:evaluation_id ORDER BY ordinal;
SELECT * FROM ga_wave_leak WHERE evaluation_id=:evaluation_id ORDER BY ordinal;
SELECT * FROM ga_enemy_fate WHERE evaluation_id=:evaluation_id ORDER BY enemy_type_id;
SELECT * FROM ga_built_tower WHERE evaluation_id=:evaluation_id ORDER BY tower_kind;
SELECT * FROM ga_reinforcement_deployment WHERE evaluation_id=:evaluation_id ORDER BY ordinal;
SELECT * FROM ga_wave_call WHERE evaluation_id=:evaluation_id ORDER BY ordinal;

-- Compact evidence from the original battle. No rows means unknown legacy
-- evidence; it does not mean the candidate made no purchases or had no activity.
SELECT * FROM ga_playstyle WHERE evaluation_id=:evaluation_id;
SELECT * FROM ga_playstyle_purchase WHERE evaluation_id=:evaluation_id ORDER BY ordinal;
SELECT * FROM ga_playstyle_tower WHERE evaluation_id=:evaluation_id ORDER BY phase,slot;
SELECT * FROM ga_playstyle_route WHERE evaluation_id=:evaluation_id ORDER BY tower_ordinal,ordinal;
