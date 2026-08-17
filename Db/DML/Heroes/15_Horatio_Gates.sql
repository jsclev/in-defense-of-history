INSERT INTO hero (
    id, short_name, long_name, nickname, unlocked_at_level_wave_id,
    general_description, historical_description, historical_text,
    primary_image_name, details_image_name, icon_image_name, ability_icon_image_name
) VALUES
(
    'a8c1a230-8fb2-421e-bd22-4aadf6770c3a', 'Horatio Gates', 'Horatio Granny Gates', 'Granny Gates', (
        SELECT lw.id FROM level_wave AS lw
        INNER JOIN level_info AS li ON lw.level_info_id = li.id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE
            li.level_name = 'Camden' AND c.campaign_name = 'The Southern Campaign'
            AND lw.wave_index = 1
    ),
    'A careful organizer whose defenses grind assaults to a halt.',
    'Commanding general at Saratoga, the victory that brought France into the war.',
    'A former British officer who organized the northern army into the force that surrounded Burgoyne at Saratoga, the victory that brought France into the war and the '
    || 'greatest American triumph before Yorktown.

His soldiers called him Granny Gates for his fussing care of them. Camden, in 1780, unmade his reputation as thoroughly as Saratoga had made it.',
    'hero_horatio_gates_card_16x15', 'hero_details_horatio_gates', 'hero_icon_horatio_gates', 'hero_ability_icon_horatio_gates'
);
