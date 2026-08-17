INSERT INTO hero (
    id, short_name, long_name, nickname, unlocked_at_level_wave_id,
    general_description, historical_description, historical_text,
    primary_image_name, details_image_name, icon_image_name, ability_icon_image_name
) VALUES
(
    'a72abee1-88a6-4856-a5d4-da460a2233b9', 'Francis Marion', 'Francis Marion, the Swamp Fox', 'The Swamp Fox', (
        SELECT lw.id FROM level_wave AS lw
        INNER JOIN level_info AS li ON lw.level_info_id = li.id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE
            li.level_name = 'Savannah' AND c.campaign_name = 'Main'
            AND lw.wave_index = 1
    ),
    'The Swamp Fox ambushes from the marshes and vanishes without a trace.',
    'South Carolina partisan whose swamp raids kept resistance alive in the occupied South.',
    'A South Carolina partisan who struck from the swamps with a few dozen riders and vanished before the redcoats could form ranks.

From his hidden camp on Snow''s Island he cut supply lines, freed prisoners, and kept resistance alive in an occupied colony. The exasperated British colonel Tarleton gave him his name: that damned old fox.',
    'hero_francis_marion_card_16x15', 'hero_details_francis_marion', 'hero_icon_francis_marion', 'hero_ability_icon_francis_marion'
);
