-- Choose one or two heroes. Ranking assigns primary (slot 1) and secondary
-- (slot 2); UUID breaks equal-ranking ties consistently with HeroSelection.
WITH choices(selection_id, short_name) AS (
    VALUES
        ('e1a4f8c2-7b3d-4e59-a260-9c8f5d2b1a07', 'Henry Knox'),
        ('f2b5a9d3-8c4e-4f6a-b371-0d9a6e3c2b18', 'George Washington')
)
INSERT INTO player_selected_hero (id, hero_id, selection_slot)
SELECT choices.selection_id, h.id,
       ROW_NUMBER() OVER (ORDER BY h.ranking DESC, h.id COLLATE NOCASE)
FROM choices
INNER JOIN hero h ON h.short_name = choices.short_name;
