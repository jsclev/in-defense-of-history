INSERT INTO hero (
    id, short_name, long_name, nickname, unlocked_at_level_wave_id,
    general_description, historical_description, historical_text,
    primary_image_name, details_image_name, icon_image_name, ability_icon_image_name,
    unit_image_name
) VALUES
(
    'dd5b7c53-5f26-4035-aa43-b78b5e177b08', 'William Prescott', 'Colonel William Prescott', NULL, (
        SELECT lw.id FROM level_wave AS lw
        INNER JOIN level_info AS li ON lw.level_info_id = li.id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE
            li.level_name = 'Kip''s Bay' AND c.campaign_name = 'The Fall of New York'
            AND lw.wave_index = 1
    ),
    'Holds fortifications long past the point anyone thought possible.',
    'Commander of the redoubt at Bunker Hill, where his militia twice threw back the British regulars before the powder ran out.',
    'The Massachusetts colonel who built the redoubt on Breed''s Hill overnight and commanded it through the battle, walking the parapet in his banyan under naval bombardment '
    || 'to steady his men.

His order to hold fire until the last moment made every round of scarce powder count, and twice threw the regulars back down the hill before the ammunition gave out.',
    'hero_william_prescott_card_16x15', 'hero_details_william_prescott', 'hero_icon_william_prescott', 'hero_ability_icon_william_prescott',
    'hero_unit_william_prescott'
);
