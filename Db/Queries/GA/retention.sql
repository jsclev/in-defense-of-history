-- Required: :run_id,:candidate_id,:panel. Marks an EXISTING evaluated candidate
-- for retention. Does not rerank, edit fitness, or manufacture a recording.
-- Always enable foreign keys on any connection used to edit this database.
PRAGMA foreign_keys=ON;
BEGIN IMMEDIATE;
INSERT INTO genetic_solution(run_id,candidate_id,panel)
SELECT run_id,candidate_id,panel FROM ga_panel
WHERE run_id=:run_id AND candidate_id=:candidate_id AND panel=:panel
ON CONFLICT(run_id,candidate_id,panel) DO NOTHING;
SELECT changes() AS retained_rows_added;
COMMIT;
-- Removal is deliberately not automatic. Original evaluations and existing
-- recordings are retained; make a backup before any explicit deletion.
