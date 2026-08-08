INSERT INTO hero (
    id, short_name, long_name, nickname, unlocked_at_level_wave_id,
    general_description, historical_description, historical_text,
    primary_image_name, details_image_name
) VALUES
(
    'c418c84b-0eb0-46a6-badb-ea0302ca89a7', 'Daniel Morgan', 'Daniel Morgan, the Old Wagoner', 'The Old Wagoner', (
        SELECT lw.id FROM level_wave AS lw
        INNER JOIN level_info AS li ON lw.level_info_id = li.id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE
            li.level_name = 'Fort Ann' AND c.campaign_name = 'Main'
            AND lw.wave_index = 1
    ),
    'Leads crack riflemen whose aimed fire cuts down officers first.',
    'The Old Wagoner, commander of the rifle corps and architect of the double envelopment at Cowpens.',
    'A backcountry teamster who survived five hundred British lashes and never forgave them.

His Virginia riflemen picked off officers at Quebec and Saratoga, and at Cowpens in 1781 he laid the war''s most perfect trap, using his militia''s weakness as bait to destroy Tarleton''s legion. Gout-ridden and aching, the Old Wagoner won and went home to his farm.',
    'hero_daniel_morgan_card_16x15', 'hero_details_daniel_morgan'
);
