-- Simulator-derived choice-irrelevance bounds. Seeded from the sweeps of
-- 2026-08-05 (Lexington fine-grid 1.95M perms x 200 seeds; Savannah
-- range/splash 90k x 200 seeds), derived on the designed-stats slice
-- (rof 0.8, growth 1.7). Committing a row here is the designer accepting the
-- simulator's finding; --store-bounds updates the live DB and prints the SQL
-- for this file.
INSERT INTO sim_stat_bounds (id, level_info_id, tower_kind, stat, min_value, max_value, derived_from) VALUES
('b0d5c0e1-0001-4000-8000-000000000001',
 (SELECT id FROM level_info WHERE level_name = 'Lexington and Concord'),
 'ranged', 'range', 130.0, 250.0,
 'sweeps/2026-08-05-lexington-finegrid.csv; floor below tested grid (win 62% at 130), ceiling: win>=99% & naiveW1>=85% at 250'),
('b0d5c0e1-0002-4000-8000-000000000002',
 (SELECT id FROM level_info WHERE level_name = 'Savannah' ORDER BY id LIMIT 1),
 'ranged', 'range', 200.0, 290.0,
 'sweeps/2026-08-05-savannah-range-splash.csv; floor: win 4.6%@190 -> 52%@200; ceiling not reached at <=290 (naiveW1 max 64%)');
