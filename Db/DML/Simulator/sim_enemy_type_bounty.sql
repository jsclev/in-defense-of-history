-- Simulator-only bounty brackets, seeded at ±25% around the designed
-- enemy_type.bounty (rounded); bracket midpoint = shipped value.
INSERT INTO sim_enemy_type_bounty (id, enemy_type_id, min_bounty, max_bounty) VALUES
('5e0eb001-0000-4000-8000-000000000001', 'c972308d-7313-45ae-8cb4-04d2d5b78046', 6.0, 10.0),   -- Loyalist Militia (8)
('5e0eb001-0000-4000-8000-000000000002', '369e4cb5-38dc-4857-8701-e6c1320c52bc', 15.0, 25.0),  -- Regimental Drummer (20)
('5e0eb001-0000-4000-8000-000000000003', '86175b06-0f08-4407-bac0-0aa95cde3f52', 11.0, 19.0),  -- Redcoat Regular (15)
('5e0eb001-0000-4000-8000-000000000004', '59cffa58-a230-4b83-b6e4-00cd84175ad1', 14.0, 23.0),  -- Light Infantry (18)
('5e0eb001-0000-4000-8000-000000000005', 'e8e182d1-c209-4cdd-8f8d-8d95de3fe167', 17.0, 28.0),  -- Hessian Jäger (22)
('5e0eb001-0000-4000-8000-000000000006', '7c014dae-5896-4b32-896e-f95555833e1e', 15.0, 25.0),  -- Hessian Fusilier (20)
('5e0eb001-0000-4000-8000-000000000007', 'b3e0cd5e-0128-46eb-a2c3-fe193d728228', 15.0, 25.0),  -- Native Warrior (20)
('5e0eb001-0000-4000-8000-000000000008', '414fd1af-c633-4780-b513-b70f13018cd3', 23.0, 38.0),  -- Highlander (30)
('5e0eb001-0000-4000-8000-000000000009', 'ef3a782a-58db-4ac8-b372-0745a27669b0', 26.0, 44.0),  -- Light Dragoon (35)
('5e0eb001-0000-4000-8000-00000000000a', '9ba1961d-cb79-4e0b-a6cd-6806d115813e', 19.0, 31.0),  -- Spy (25)
('5e0eb001-0000-4000-8000-00000000000b', '5392e3d1-c1c6-40d0-b54d-2be8aa4dc277', 34.0, 56.0),  -- Grenadier (45)
('5e0eb001-0000-4000-8000-00000000000c', 'f00dd278-0466-4bd5-b454-9c5a3dc964ec', 45.0, 75.0),  -- Royal Artillery (60)
('5e0eb001-0000-4000-8000-00000000000d', '48cf0732-a2a6-4271-b631-232a70c263ce', 38.0, 63.0),  -- Mounted Officer (50)
('5e0eb001-0000-4000-8000-00000000000e', '8dc553a0-c688-470d-ae0a-f2a0cfa04f45', 56.0, 94.0);  -- Foot Guards (75)
