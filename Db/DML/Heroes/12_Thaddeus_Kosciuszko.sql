INSERT INTO hero (
    id, short_name, long_name, nickname, unlocked_at_level_wave_id,
    general_description, historical_description, historical_text,
    primary_image_name, details_image_name
) VALUES
(
    '4e290eb7-6af2-4e3e-8bd6-ff0759b1b13d', 'Thaddeus Kosciuszko', 'Colonel Thaddeus Kosciuszko', NULL, (
        SELECT lw.id FROM level_wave AS lw
        INNER JOIN level_info AS li ON lw.level_info_id = li.id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE
            li.level_name = 'Hubbardton' AND c.campaign_name = 'The Northern Campaign'
            AND lw.wave_index = 1
    ),
    'A master engineer whose defenses decide battles before they begin.',
    'Polish engineer whose fortifications at Bemis Heights shaped the victory at Saratoga, and who later fortified West Point.',
    'A Polish engineer who offered his sword in 1776 and became the Revolution''s finest military architect.

He chose and fortified Bemis Heights, the ground that made Saratoga unwinnable for Burgoyne, and spent three years building the fortress at West Point. He went home to lead Poland''s own fight for liberty in 1794.',
    'hero_thaddeus_kosciuszko_card_16x15', 'hero_details_thaddeus_kosciuszko'
);
