INSERT INTO hero (
    id, short_name, long_name, nickname, unlocked_at_level_wave_id,
    general_description, historical_description, historical_text,
    primary_image_name, details_image_name
) VALUES
(
    '75a615ca-f880-44ca-8386-e28f72fe2f7f', 'Israel Putnam', 'Israel Old Put Putnam', 'Old Put', (
        SELECT lw.id FROM level_wave AS lw
        INNER JOIN level_info AS li ON lw.level_info_id = li.id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE
            li.level_name = 'Battle Road' AND c.campaign_name = 'Main'
            AND lw.wave_index = 4
    ),
    'A stubborn veteran who holds the line and rallies shaken militia.',
    'Connecticut general famed at Bunker Hill, where legend credits him with the order not to fire until you see the whites of their eyes.',
    'A veteran ranger who left his plow standing in the field when word of Lexington came. '
    || 'At Bunker Hill he helped hold Breed''s Hill and the rail fence, bellowing encouragement through the smoke.

Already a folk legend for crawling into a wolf''s den alone, Old Put embodied the rough courage of the New England militia until a stroke ended his field service in 1779.',
    'hero_old_put_card_16x15', 'hero_details_old_put'
);
