INSERT INTO hero (
    id, short_name, long_name, nickname, unlocked_at_level_wave_id,
    general_description, historical_description, historical_text,
    primary_image_name, details_image_name, icon_image_name, ability_icon_image_name
) VALUES
(
    '4f5ea61b-2be4-46b1-ad0b-21c1a80ab8e4', 'Louis Duportail', 'General Louis Duportail, Father of the Army Corps of Engineers', 'Father of the Army Corps of Engineers', (
        SELECT lw.id FROM level_wave AS lw
        INNER JOIN level_info AS li ON lw.level_info_id = li.id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE
            li.level_name = 'Sullivan''s Island' AND c.campaign_name = 'Main'
            AND lw.wave_index = 1
    ),
    'Chief engineer whose fieldworks turn any ground into a fortress.',
    'French engineer who became the Continental Army''s chief of engineers and planned the siege works at Yorktown.',
    'A French royal engineer slipped into America in 1777, a year before the alliance was official.

As chief engineer he laid out the defenses at Valley Forge, professionalized the army''s engineering corps, and planned the siege approaches that closed the trap at Yorktown. He returned to France to serve as minister of war in its own revolution.',
    'hero_louis_duportail_card_16x15', 'hero_details_louis_duportail', 'hero_icon_louis_duportail', 'hero_ability_icon_louis_duportail'
);
