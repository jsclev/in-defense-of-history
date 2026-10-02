-- Rebuildable derived view. SQLite SUM uses compensated floating-point sums;
-- GeneticFitness uses ordered Double additions. Use the same ordinal fold so
-- last-bit differences cannot reorder ties in historical or future panels.
DROP VIEW IF EXISTS main.ga_candidate_fitness;
CREATE VIEW ga_candidate_fitness AS
WITH RECURSIVE fitness(run_id,candidate_id,panel,expected_samples,sample_count,n,
                       victories,defeats,timeouts,victory_lives,waves,survival) AS (
    SELECT run_id,candidate_id,panel,expected_samples,sample_count,0,
           0,0,0,0.0,0.0,0.0
    FROM ga_panel
    UNION ALL
    SELECT f.run_id,f.candidate_id,f.panel,f.expected_samples,f.sample_count,f.n+1,
           f.victories+(e.outcome='victory'),f.defeats+(e.outcome='defeat'),f.timeouts+(e.outcome='timeout'),
           f.victory_lives+CASE WHEN e.outcome='victory' THEN CAST(e.lives_remaining AS REAL) ELSE 0.0 END,
           f.waves+CAST(e.waves_started AS REAL),
           f.survival+CASE WHEN e.outcome='defeat' THEN e.seconds ELSE 0.0 END
    FROM fitness f JOIN ga_evaluation e ON e.run_id=f.run_id AND e.candidate_id=f.candidate_id
         AND e.panel=f.panel AND e.ordinal=f.n
    WHERE f.n<f.sample_count
)
SELECT c.run_id,c.candidate_id,c.generation,c.stars_used,c.strategy_id,f.panel,
       f.expected_samples,f.n AS samples,f.n=f.expected_samples AS panel_complete,
       f.victories,f.defeats,f.timeouts,CAST(f.victories AS REAL)/f.n AS win_rate,
       f.victory_lives/f.n AS mean_victory_lives,f.waves/f.n AS mean_waves_started,
       f.survival/f.n AS mean_survival_seconds
FROM fitness f JOIN ga_candidate c USING(run_id,candidate_id)
WHERE f.n=f.sample_count;
