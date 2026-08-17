-- max two rows (selection_slot 1..2)
INSERT INTO player_selected_hero (id, hero_id, selection_slot) VALUES
(
    'e1a4f8c2-7b3d-4e59-a260-9c8f5d2b1a07',
    (
        SELECT id FROM hero
        WHERE short_name = 'Henry Knox'
    ), 1
),
(
    'f2b5a9d3-8c4e-4f6a-b371-0d9a6e3c2b18',
    (
        SELECT id FROM hero
        WHERE short_name = 'George Washington'
    ), 2
);
