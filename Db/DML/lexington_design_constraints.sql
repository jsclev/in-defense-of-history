-- Design-lab constraints for level 1, Lexington and Concord. These are the
-- designer-fixed inputs the simulator reads via DAOs and may NOT vary:
-- available tower kinds/levels, starting lives, and wave count (level_wave
-- rows). Runs last so it overrides tower_unlock_experiment.sql for this level.
DELETE FROM level_tower_unlock WHERE level_info_id =
    (SELECT id FROM level_info WHERE level_name = 'Lexington and Concord');

-- No special towers on level 1: the sweep showed a terror special is a strict
-- trap purchase against the level-1 roster (see sweep of 2026-08-04).
INSERT INTO level_tower_unlock (id, level_info_id, tower_kind, max_tower_level) VALUES
('c1de5160-0001-4000-8000-0000000000a1', (SELECT id FROM level_info WHERE level_name = 'Lexington and Concord'), 'ranged', 2),
('c1de5160-0002-4000-8000-0000000000a2', (SELECT id FROM level_info WHERE level_name = 'Lexington and Concord'), 'melee', 2);

UPDATE level_info SET num_starting_lives = 20
    WHERE level_name = 'Lexington and Concord';
