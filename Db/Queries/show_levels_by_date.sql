SELECT
    l.level_name AS 'Battle',
    c.campaign_name AS 'Campaign',
    CASE strftime('%w', l.started_at)
        WHEN '0' THEN 'Sunday'
        WHEN '1' THEN 'Monday'
        WHEN '2' THEN 'Tuesday'
        WHEN '3' THEN 'Wednesday'
        WHEN '4' THEN 'Thursday'
        WHEN '5' THEN 'Friday'
        ELSE 'Saturday'
    END
    || ', '
    || CASE strftime('%m', l.started_at)
        WHEN '01' THEN 'January' WHEN '02' THEN 'February' WHEN '03' THEN 'March'
        WHEN '04' THEN 'April' WHEN '05' THEN 'May' WHEN '06' THEN 'June'
        WHEN '07' THEN 'July' WHEN '08' THEN 'August' WHEN '09' THEN 'September'
        WHEN '10' THEN 'October' WHEN '11' THEN 'November' ELSE 'December'
    END
    || strftime(' %e, %Y ', l.started_at)
    || ltrim(strftime('%I', l.started_at), '0')
    || strftime(' %P', l.started_at) AS "Start",
    CASE strftime('%w', l.ended_at)
        WHEN '0' THEN 'Sunday'
        WHEN '1' THEN 'Monday'
        WHEN '2' THEN 'Tuesday'
        WHEN '3' THEN 'Wednesday'
        WHEN '4' THEN 'Thursday'
        WHEN '5' THEN 'Friday'
        ELSE 'Saturday'
    END
    || ', '
    || CASE strftime('%m', l.ended_at)
        WHEN '01' THEN 'January' WHEN '02' THEN 'February' WHEN '03' THEN 'March'
        WHEN '04' THEN 'April' WHEN '05' THEN 'May' WHEN '06' THEN 'June'
        WHEN '07' THEN 'July' WHEN '08' THEN 'August' WHEN '09' THEN 'September'
        WHEN '10' THEN 'October' WHEN '11' THEN 'November' ELSE 'December'
    END
    || strftime(' %e, %Y ', l.ended_at)
    || ltrim(strftime('%I', l.ended_at), '0')
    || strftime(' %P', l.ended_at) AS "End",
    printf('%.2f', julianday(l.ended_at) - julianday(l.started_at)) || ' days' AS duration_in_days
FROM
    level_info AS l
INNER JOIN
    campaign AS c
    ON l.campaign_id = c.id
ORDER BY
    c.parent_campaign_id,
    l.started_at,
    c.campaign_name;
