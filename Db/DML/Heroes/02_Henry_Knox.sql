INSERT INTO hero (
    id, short_name, long_name, nickname, unlocked_at_level_wave_id,
    general_description, historical_description, historical_text,
    primary_image_name, details_image_name, icon_image_name, ability_icon_image_name
) VALUES
(
    '43b37067-8f24-4f3e-ba9b-3c7f10cc629d', 'Henry Knox', 'Colonel Henry Knox', NULL, (
        SELECT lw.id FROM level_wave AS lw
        INNER JOIN level_info AS li ON lw.level_info_id = li.id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE
            li.level_name = 'Dorchester Heights' AND c.campaign_name = 'Main'
            AND lw.wave_index = 1
    ),
    'Master of artillery whose guns rain down thunderous barrages.',
    'Boston bookseller turned artillery chief who hauled the guns of Ticonderoga three hundred miles through winter to free Boston.',
    'A Boston bookseller who taught himself gunnery from the volumes he sold. '
    || 'In the winter of 1775 he dragged sixty tons of captured Ticonderoga cannon three hundred miles by ox sled to the heights above Boston, forcing the British fleet to '
    || 'sail away.

As chief of artillery he directed the guns at Trenton, Monmouth, and Yorktown, and became the new republic''s first Secretary of War.',
    'hero_henry_knox_card_16x15', 'hero_details_henry_knox', 'hero_icon_henry_knox', 'hero_ability_icon_henry_knox'
);
