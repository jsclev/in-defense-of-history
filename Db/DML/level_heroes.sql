INSERT INTO level_hero (id, level_info_id, hero_id, enemy_path_index) VALUES
(
    '7c1f9a20-0f4e-4a2e-9d55-2b6c0a51e001',
    (
        SELECT li.id FROM level_info AS li
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'
    ),
    (SELECT id FROM hero WHERE short_name = 'George Washington'),
    0
),
(
    '7c1f9a20-0f4e-4a2e-9d55-2b6c0a51e002',
    (
        SELECT li.id FROM level_info AS li
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'
    ),
    (SELECT id FROM hero WHERE short_name = 'Henry Knox'),
    1
);
