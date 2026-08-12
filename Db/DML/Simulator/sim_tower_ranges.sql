INSERT INTO sim_tower_range (id, tower_id, min_range, max_range) VALUES
(
    '7c1a52f0-6d3b-4e18-9a45-2f8c0b17e901',
    (
        SELECT id FROM tower
        WHERE tower_name = 'Musketmen' AND tower_level = 1
    ),
    100,
    275
),
(
    '9e4d81b3-2c76-4a5f-8b30-6d19f2a4c802',
    (
        SELECT id FROM tower
        WHERE tower_name = 'Marksmen' AND tower_level = 2
    ),
    100,
    275
);
