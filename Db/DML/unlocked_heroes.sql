-- a hero is locked unless listed here
INSERT INTO player_unlocked_hero (id, hero_id) VALUES
('b7d3e91c-2a48-4a6d-9e10-3c5b8a2f7d64',
 (SELECT id FROM hero WHERE short_name = 'Israel Putnam'));
