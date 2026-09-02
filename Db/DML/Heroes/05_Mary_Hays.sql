INSERT INTO hero (
    id, short_name, long_name, nickname, unlocked_at_level_wave_id,
    general_description, historical_description, historical_text,
    primary_image_name, details_image_name, icon_image_name, ability_icon_image_name,
    unit_image_name
) VALUES
(
    'ca5f165f-d3e1-44e4-a224-65c8a798c022', 'Mary Hays', 'Mary Molly Pitcher Hays', 'Molly Pitcher', (
        SELECT lw.id FROM level_wave AS lw
        INNER JOIN level_info AS li ON lw.level_info_id = li.id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE
            li.level_name = 'Princeton' AND c.campaign_name = 'Main'
            AND lw.wave_index = 1
    ),
    'Keeps the guns firing and the soldiers on their feet in the worst of it.',
    'Folk heroine of Monmouth, who carried water to the gun crews and took her fallen husband''s place at the cannon.',
    'At Monmouth, in hundred-degree heat, Mary Hays carried pitcher after pitcher of water to the gun crews while the army''s soldiers cried Molly, pitcher!

When her husband fell at his cannon she stepped into his place and served the piece through the rest of the battle. Pennsylvania later granted her a soldier''s pension for services rendered.',
    'hero_molly_pitcher_card_16x15', 'hero_details_molly_pitcher', 'hero_icon_molly_pitcher', 'hero_ability_icon_molly_pitcher',
    'hero_unit_molly_pitcher'
);
