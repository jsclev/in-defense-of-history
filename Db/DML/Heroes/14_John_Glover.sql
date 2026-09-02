INSERT INTO hero (
    id, short_name, long_name, nickname, unlocked_at_level_wave_id,
    general_description, historical_description, historical_text,
    primary_image_name, details_image_name, icon_image_name, ability_icon_image_name,
    unit_image_name
) VALUES
(
    '1feb2d3f-815d-4139-9e47-b99aac112fc8', 'John Glover', 'Brigadier General John Glover', NULL, (
        SELECT lw.id FROM level_wave AS lw
        INNER JOIN level_info AS li ON lw.level_info_id = li.id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE
            li.level_name = 'Rhode Island' AND c.campaign_name = 'The French Alliance'
            AND lw.wave_index = 1
    ),
    'His mariners move whole armies across water no one else would cross.',
    'Marblehead fisherman whose amphibious regiment rowed Washington''s army to safety from Long Island and across the Delaware to Trenton.',
    'A Marblehead fisherman whose regiment of mariners saved the Revolution twice: rowing the beaten army off Long Island through fog and darkness without losing a man, and '
    || 'pulling Washington''s assault force through the ice-choked Delaware on Christmas night.

At Pell''s Point his seven hundred delayed four thousand British and Hessians for a full day.',
    'hero_john_glover_card_16x15', 'hero_details_john_glover', 'hero_icon_john_glover', 'hero_ability_icon_john_glover',
    'hero_unit_john_glover'
);
