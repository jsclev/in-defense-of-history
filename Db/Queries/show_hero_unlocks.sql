SELECT
    c.campaign_name AS 'Campaign',
    l.level_name AS 'Level',
    w.wave_index AS 'Wave',
    h.long_name AS 'Hero'
FROM
    hero AS h
INNER JOIN
    level_wave AS w
    ON h.unlocked_at_level_wave_id = w.id
INNER JOIN
    level_info AS l
    ON w.level_info_id = l.id
INNER JOIN
    campaign AS c
    ON l.campaign_id = c.id
ORDER BY
    c.parent_campaign_id,
    l.started_at,
    w.wave_index;
