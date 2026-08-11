INSERT INTO player_selected_difficulty (
    id, difficulty_id, selection_slot
) VALUES (
    'd1ff5e1c-0000-4000-8000-000000000001',
    (
        SELECT id FROM difficulty
        WHERE difficulty_level = 4
    ),
    1
);
