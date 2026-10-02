-- Offline migration only, on a newly backed-up destination. The converter has
-- read the original catalog and recreates it with create_genetic_solutions.sql.
-- Foreign keys are disabled while the table is replaced; every link and saved
-- recording is checked before the new database is delivered.
DROP TABLE genetic_solution;
