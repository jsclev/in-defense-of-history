-- Design-lab constraints for Savannah: no special towers, on every level_info
-- row of that name. Runs after tower_unlock_experiment.sql so the playtest
-- unlock-everything override cannot re-add them.
DELETE FROM level_tower_unlock WHERE tower_kind = 'special' AND level_info_id IN
    (SELECT id FROM level_info WHERE level_name = 'Savannah');
