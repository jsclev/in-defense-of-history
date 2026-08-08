INSERT INTO hero (
    id, short_name, long_name, nickname, unlocked_at_level_wave_id,
    general_description, historical_description, historical_text,
    primary_image_name, details_image_name
) VALUES
(
    '1d9dba5f-e46a-4ca6-ac50-d62b22e7bd1b', 'Friedrich von Steuben', 'Baron von Steuben, the Drillmaster of Valley Forge', 'The Drillmaster of Valley Forge', (
        SELECT lw.id FROM level_wave AS lw
        INNER JOIN level_info AS li ON lw.level_info_id = li.id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE
            li.level_name = 'New Haven' AND c.campaign_name = 'Main'
            AND lw.wave_index = 1
    ),
    'The Prussian drillmaster hardens nearby troops into disciplined regulars.',
    'Prussian officer whose Valley Forge drills and Blue Book turned the Continental Army into a professional force.',
    'A Prussian captain with an inflated resume and a genuine genius for soldiering. '
    || 'Arriving at Valley Forge in 1778 speaking no English, he drilled a model company in person, swearing magnificently in German and French while aides translated.

His Blue Book of regulations turned the Continental Army into a professional force and remained the Army''s manual for decades.',
    'hero_baron_von_steuben_card_16x15', 'hero_details_baron_von_steuben'
);
