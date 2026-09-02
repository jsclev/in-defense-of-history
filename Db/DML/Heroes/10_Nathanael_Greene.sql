INSERT INTO hero (
    id, short_name, long_name, nickname, unlocked_at_level_wave_id,
    general_description, historical_description, historical_text,
    primary_image_name, details_image_name, icon_image_name, ability_icon_image_name,
    unit_image_name
) VALUES
(
    '31f3c69a-094a-4923-8dd0-a7411216d3cb', 'Nathanael Greene', 'Nathanael Greene, the Fighting Quaker', 'The Fighting Quaker', (
        SELECT lw.id FROM level_wave AS lw
        INNER JOIN level_info AS li ON lw.level_info_id = li.id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE
            li.level_name = 'Charleston' AND c.campaign_name = 'Main'
            AND lw.wave_index = 1
    ),
    'A patient strategist who wears the enemy down and never stays beaten.',
    'The Quaker general whose Southern Campaign lost battles but won the war, bleeding Cornwallis all the way to Yorktown.',
    'A self-taught Quaker ironmaster expelled from meeting for drilling with the militia.

After the disaster at Camden he took command of the southern army and waged a masterful campaign of retreat and riposte, declaring he would fight, get beat, rise, and fight again. He bled Cornwallis white at Guilford Courthouse and won back the South without winning a battle.',
    'hero_nathanael_greene_card_16x15', 'hero_details_nathanael_greene', 'hero_icon_nathanael_greene', 'hero_ability_icon_nathanael_greene',
    'hero_unit_nathanael_greene'
);
