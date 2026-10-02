-- Evolved player intent. Progress is the preferred fraction along a road.
-- The shared engine's placement geometry determines the actual reachable site.
SELECT c.run_id,c.candidate_id,c.generation,t.ordinal,t.slot,t.kind,t.path_index,t.progress
FROM ga_candidate c JOIN ga_tactical_order t ON t.strategy_id=c.strategy_id
ORDER BY c.run_id,c.candidate_id,t.ordinal;

-- Actual successful commands, per seed; no replay or inference from DNA.
-- A NULL tactical_count identifies unknown historical evidence.
SELECT e.run_id,e.candidate_id,e.panel,e.seed,e.outcome,e.tactical_count,
       a.ordinal,a.seconds,a.wave,a.slot,a.kind,a.x,a.y
FROM ga_evaluation e LEFT JOIN ga_tactical_action a ON a.evaluation_id=e.evaluation_id
ORDER BY e.run_id,e.candidate_id,e.panel,e.ordinal,a.ordinal;
