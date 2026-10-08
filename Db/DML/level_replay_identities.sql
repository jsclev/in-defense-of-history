-- Preserve presentation names in historical replay fingerprints. New levels
-- initially use their authored name; renamed levels retain their original one.
INSERT INTO level_replay_identity (level_info_id, level_name)
SELECT id, level_name FROM level_info;

UPDATE level_replay_identity
SET level_name = 'Charleston'
WHERE level_info_id = '4ca73a47-98f6-41b6-815d-c2c797aa746e';
