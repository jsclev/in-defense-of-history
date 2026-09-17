INSERT INTO sim_tower_range (id, tower_id, min_range, max_range) VALUES
(
    '7c1a52f0-6d3b-4e18-9a45-2f8c0b17e901',
    (
        SELECT id FROM tower
        WHERE tower_type_id = '7a10c1de-4b71-4f3d-9d34-5b7f1a2c9e01' AND tower_level = 1 AND branch = 1
    ),
    280,
    360
),
(
    '9e4d81b3-2c76-4a5f-8b30-6d19f2a4c802',
    (
        SELECT id FROM tower
        WHERE tower_type_id = '7a10c1de-4b71-4f3d-9d34-5b7f1a2c9e01' AND tower_level = 2 AND branch = 1
    ),
    320,
    410
);
