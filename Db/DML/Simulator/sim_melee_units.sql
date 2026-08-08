-- Simulator-only melee unit brackets, ±25% around designed values (rounded).
-- min/max_damage bracket the unit's AVERAGE swing damage; the designed
-- min-max roll band keeps its shape and scales to the chosen average.
INSERT INTO sim_melee_unit (id, tower_id, min_hp, max_hp, min_damage, max_damage) VALUES
('5e0ee001-0000-4000-8000-000000000001', '3d7e4f95-1c6b-4ac0-ae53-9b8d2f1a0c04', 40.0, 65.0, 1.5, 2.5),    -- Militia (50hp, avg 2)
('5e0ee001-0000-4000-8000-000000000002', '4e8f5a06-2d7c-4bd1-bf64-0c9e3a2b1d05', 60.0, 100.0, 3.0, 5.0),   -- Minutemen (80hp, avg 4)
('5e0ee001-0000-4000-8000-000000000003', '5f9a6b17-3e8d-4ce2-c075-1d0f4b3c2e06', 90.0, 150.0, 4.9, 8.1),   -- Continental Line (120hp, avg 6.5)
('5e0ee001-0000-4000-8000-000000000004', '9c1aa74b-b783-4fc1-b9c3-daeaf5284146', 165.0, 275.0, 7.5, 12.5); -- Continental Regulars (220hp, avg 10)
