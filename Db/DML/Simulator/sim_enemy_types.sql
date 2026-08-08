-- Simulator-only brackets per enemy: the ranges the simulator may explore
-- for speed and max HP. Seeded at ±25% around the designed enemy_type values
-- (rounded), so each bracket midpoint is the shipped value; adjust per enemy
-- as design intent firms up. The game never reads this table.
INSERT INTO sim_enemy_type (id, enemy_type_id, min_speed, max_speed, min_hp, max_hp) VALUES
('5e0e0001-0000-4000-8000-000000000001', 'c972308d-7313-45ae-8cb4-04d2d5b78046', 45.0, 75.0, 40.0, 65.0),     -- Loyalist Militia (60 / 50hp)
('5e0e0001-0000-4000-8000-000000000002', '369e4cb5-38dc-4857-8701-e6c1320c52bc', 45.0, 75.0, 45.0, 75.0),     -- Regimental Drummer (60 / 60hp)
('5e0e0001-0000-4000-8000-000000000003', '86175b06-0f08-4407-bac0-0aa95cde3f52', 45.0, 75.0, 70.0, 115.0),    -- Redcoat Regular (60 / 90hp)
('5e0e0001-0000-4000-8000-000000000004', '59cffa58-a230-4b83-b6e4-00cd84175ad1', 65.0, 105.0, 55.0, 90.0),    -- Light Infantry (85 / 70hp)
('5e0e0001-0000-4000-8000-000000000005', 'e8e182d1-c209-4cdd-8f8d-8d95de3fe167', 65.0, 105.0, 50.0, 80.0),    -- Hessian Jäger (85 / 65hp)
('5e0e0001-0000-4000-8000-000000000006', '7c014dae-5896-4b32-896e-f95555833e1e', 45.0, 75.0, 85.0, 140.0),    -- Hessian Fusilier (60 / 110hp)
('5e0e0001-0000-4000-8000-000000000007', 'b3e0cd5e-0128-46eb-a2c3-fe193d728228', 90.0, 150.0, 45.0, 75.0),    -- Native Warrior (120 / 60hp)
('5e0e0001-0000-4000-8000-000000000008', '414fd1af-c633-4780-b513-b70f13018cd3', 65.0, 105.0, 100.0, 165.0),  -- Highlander (85 / 130hp)
('5e0e0001-0000-4000-8000-000000000009', 'ef3a782a-58db-4ac8-b372-0745a27669b0', 90.0, 150.0, 105.0, 175.0),  -- Light Dragoon (120 / 140hp)
('5e0e0001-0000-4000-8000-00000000000a', '9ba1961d-cb79-4e0b-a6cd-6806d115813e', 65.0, 105.0, 35.0, 55.0),    -- Spy (85 / 45hp)
('5e0e0001-0000-4000-8000-00000000000b', '5392e3d1-c1c6-40d0-b54d-2be8aa4dc277', 30.0, 50.0, 180.0, 300.0),   -- Grenadier (40 / 240hp)
('5e0e0001-0000-4000-8000-00000000000c', 'f00dd278-0466-4bd5-b454-9c5a3dc964ec', 20.0, 30.0, 225.0, 375.0),   -- Royal Artillery (25 / 300hp)
('5e0e0001-0000-4000-8000-00000000000d', '48cf0732-a2a6-4271-b631-232a70c263ce', 65.0, 105.0, 135.0, 225.0),  -- Mounted Officer (85 / 180hp)
('5e0e0001-0000-4000-8000-00000000000e', '8dc553a0-c688-470d-ae0a-f2a0cfa04f45', 30.0, 50.0, 375.0, 625.0);   -- Foot Guards (40 / 500hp)
