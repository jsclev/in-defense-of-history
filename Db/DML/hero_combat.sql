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
),
(
    '9b3d5e40-1a72-4c8b-8f31-4d6e2a90c003',
    (SELECT id FROM hero WHERE short_name = 'Daniel Morgan'),
    12.0, 0.35, 300.0, 1.2, 20.0, 5.0, 180.0
),
(
    '9b3d5e40-1a72-4c8b-8f31-4d6e2a90c004',
    (SELECT id FROM hero WHERE short_name = 'Salem Poor'),
    12.0, 0.35, 300.0, 1.2, 20.0, 5.0, 180.0
),
(
    '9b3d5e40-1a72-4c8b-8f31-4d6e2a90c005',
    (SELECT id FROM hero WHERE short_name = 'Israel Putnam'),
    12.0, 0.35, 300.0, 1.2, 20.0, 5.0, 180.0
),
(
    '9b3d5e40-1a72-4c8b-8f31-4d6e2a90c006',
    (SELECT id FROM hero WHERE short_name = 'Friedrich von Steuben'),
    12.0, 0.35, 300.0, 1.2, 20.0, 5.0, 180.0
);

-- Provisional baseline for the rest of the selectable roster. Runtime now
-- deploys the player's choices, so every hero needs database-backed stats.
INSERT INTO hero_combat (
    id, hero_id, attack_rating, defense_rating, hp,
    attack_interval, respawn_seconds, heal_per_second, move_speed
)
SELECT h.id, h.id, 12.0, 0.35, 300.0, 1.2, 20.0, 5.0, 180.0
FROM hero h
WHERE NOT EXISTS (SELECT 1 FROM hero_combat hc WHERE hc.hero_id = h.id);
