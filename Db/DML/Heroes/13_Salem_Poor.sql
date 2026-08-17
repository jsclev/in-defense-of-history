INSERT INTO hero (
    id, short_name, long_name, nickname, unlocked_at_level_wave_id,
    general_description, historical_description, historical_text,
    primary_image_name, details_image_name, icon_image_name, ability_icon_image_name
) VALUES
(
    '90048c5e-9113-4b6e-987f-047d95f3590a', 'Salem Poor', 'Private Salem Poor', NULL, (
        SELECT lw.id FROM level_wave AS lw
        INNER JOIN level_info AS li ON lw.level_info_id = li.id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE
            li.level_name = 'White Marsh' AND c.campaign_name = 'The Philadelphia Campaign'
            AND lw.wave_index = 1
    ),
    'A steady soldier whose courage under fire steels those around him.',
    'Formerly enslaved man who bought his freedom, and fought so bravely at Bunker Hill that fourteen officers petitioned to honor him.',
    'Born enslaved in Andover, he purchased his freedom in 1769 for the price of a year''s wages.

At Bunker Hill he fought with such conspicuous courage that fourteen officers petitioned the Massachusetts legislature to honor him as a brave and gallant soldier, a distinction accorded no other man that day. He went on to serve at Valley Forge and White Plains.',
    'hero_salem_poor_card_16x15', 'hero_details_salem_poor', 'hero_icon_salem_poor', 'hero_ability_icon_salem_poor'
);
