-- max two rows (selection_slot 1..2)
INSERT INTO player_selected_hero (id, hero_id, selection_slot) VALUES
(
    'e1a4f8c2-7b3d-4e59-a260-9c8f5d2b1a07',
    (
        SELECT id FROM hero
        WHERE short_name = 'Israel Putnam'
    ), 1
);
