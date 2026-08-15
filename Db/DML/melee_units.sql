INSERT INTO melee_unit (
    id, tower_id, soldier_count,
    attack_rating, defense_rating, hp, rally_point_radius,
    attack_interval, respawn_seconds, heal_per_second
) VALUES
-- Militia
('a1e5c010-0000-4000-8000-000000000001', '3d7e4f95-1c6b-4ac0-ae53-9b8d2f1a0c04', 3,
 2.0, 0.0, 50.0, 160.0,
 1.2, 12.0, 4.0),
-- Minutemen
('a1e5c010-0000-4000-8000-000000000002', '4e8f5a06-2d7c-4bd1-bf64-0c9e3a2b1d05', 3,
 4.0, 0.1, 80.0, 160.0,
 1.2, 11.0, 4.0),
-- Continental Line
('a1e5c010-0000-4000-8000-000000000003', '5f9a6b17-3e8d-4ce2-c075-1d0f4b3c2e06', 3,
 6.5, 0.2, 120.0, 160.0,
 1.2, 10.0, 4.0),
-- Continental Regulars
('a1e5c010-0000-4000-8000-000000000004', '9c1aa74b-b783-4fc1-b9c3-daeaf5284146', 3,
 10.0, 0.3, 220.0, 160.0,
 1.2, 9.0, 4.0),
-- Continental Light Infantry
('a1e5c010-0000-4000-8000-000000000005', '634b9957-dce1-4b53-8665-1017904ad89d', 3,
 10.0, 0.3, 220.0, 160.0,
 1.2, 9.0, 4.0),
-- Maryland Line
('a1e5c010-0000-4000-8000-000000000006', '550638ec-0f26-4329-9719-2d3f2e697238', 3,
 10.0, 0.3, 220.0, 160.0,
 1.2, 9.0, 4.0);
