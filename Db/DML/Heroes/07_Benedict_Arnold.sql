INSERT INTO hero (
    id, short_name, long_name, nickname, unlocked_at_level_wave_id,
    general_description, historical_description, historical_text,
    primary_image_name, details_image_name, icon_image_name, ability_icon_image_name,
    unit_image_name
) VALUES
(
    '5c689e4f-5105-4bab-8dd9-63f61124bd35', 'Benedict Arnold', 'Benedict Dark Eagle Arnold', 'Dark Eagle', (
        SELECT lw.id FROM level_wave AS lw
        INNER JOIN level_info AS li ON lw.level_info_id = li.id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE
            li.level_name = 'Saratoga' AND c.campaign_name = 'Main'
            AND lw.wave_index = 1
    ),
    'A fearless battlefield leader who strikes where least expected.',
    'The Revolution''s most gifted field commander at Valcour Island and Saratoga, before his name became a byword for betrayal.',
    'The Revolution''s most dangerous field commander: he stormed Ticonderoga, marched an army through the Maine wilderness to Quebec, delayed a British fleet at Valcour '
    || 'Island, and broke the enemy line at Saratoga, wounded in the same leg twice.

Passed over, indebted, and embittered, he sold West Point to the enemy in 1780, and made his name a synonym for treason.',
    'hero_benedict_arnold_card_16x15', 'hero_details_benedict_arnold', 'hero_icon_benedict_arnold', 'hero_ability_icon_benedict_arnold',
    'hero_unit_benedict_arnold'
);
