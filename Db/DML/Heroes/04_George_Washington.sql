INSERT INTO hero (
    id, short_name, long_name, nickname, unlocked_at_level_wave_id,
    general_description, historical_description, historical_text,
    primary_image_name, details_image_name, icon_image_name, ability_icon_image_name,
    unit_image_name
) VALUES
(
    'fac6c094-9cbc-474a-975e-8d2a170e07da', 'George Washington', 'General George Washington', NULL, (
        SELECT lw.id FROM level_wave AS lw
        INNER JOIN level_info AS li ON lw.level_info_id = li.id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE
            li.level_name = 'Trenton' AND c.campaign_name = 'Main'
            AND lw.wave_index = 1
    ),
    'The commander-in-chief inspires every soldier fighting near him.',
    'Commander of the Continental Army through eight years of war, from the siege of Boston to the victory at Yorktown.',
    'The Virginia planter who took command of a rabble around Boston in 1775 and, through eight years of defeat, retreat, and privation, never let the Revolution die.

He struck back across the Delaware at Trenton, held the army together at Valley Forge, and trapped Cornwallis at Yorktown. Then, with the war won, he gave his power back and went home.',
    'hero_george_washington_card_16x15', 'hero_details_george_washington', 'hero_icon_george_washington', 'hero_ability_icon_george_washington',
    'hero_unit_george_washington'
);
