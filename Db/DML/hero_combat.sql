INSERT INTO hero_combat (
    id, hero_id, attack_rating, defense_rating, hp,
    attack_interval, respawn_seconds, heal_per_second, move_speed
) VALUES
(
    '9b3d5e40-1a72-4c8b-8f31-4d6e2a90c001',
    (SELECT id FROM hero WHERE short_name = 'George Washington'),
    14.0, 0.40, 340.0, 1.1, 20.0, 5.0, 180.0
),
(
    '9b3d5e40-1a72-4c8b-8f31-4d6e2a90c002',
    (SELECT id FROM hero WHERE short_name = 'Henry Knox'),
    12.0, 0.35, 300.0, 1.2, 20.0, 5.0, 180.0
);
