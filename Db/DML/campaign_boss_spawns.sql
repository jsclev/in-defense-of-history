-- Add one major boss to the final authored wave at Dorchester Heights and Fort Ann.
-- Charleston's boss is generated alongside its SQL/GeoJSON/editor wave data by
-- Tools/generate_charleston_waves.py. Keep all existing spawn groups and budgets.
-- A new spawn index arrives six seconds after the preceding group begins.
INSERT INTO level_wave_enemy_spawn (
    id, level_wave_id, enemy_type_id, spawn_index,
    num_enemies, spawn_time_since_previous_spawn, spawn_interval, path_index
)
SELECT '361eafb8-8f9b-5305-be7e-b81de46a8328', wave.id,
       (SELECT id FROM enemy_type WHERE enemy_type_key = 'howe_assault'),
       (SELECT MAX(spawn_index) + 1 FROM level_wave_enemy_spawn WHERE level_wave_id = wave.id),
       1, 6.0, 1.0, 0
FROM level_wave AS wave
WHERE wave.level_info_id = '17914ebc-7052-490d-b606-afc1746da512'
  AND wave.wave_index = (SELECT MAX(wave_index) FROM level_wave WHERE level_info_id = wave.level_info_id);

INSERT INTO level_wave_enemy_spawn (
    id, level_wave_id, enemy_type_id, spawn_index,
    num_enemies, spawn_time_since_previous_spawn, spawn_interval, path_index
)
SELECT '408551a0-786d-598f-ba7b-6fad3344a799', wave.id,
       (SELECT id FROM enemy_type WHERE enemy_type_key = 'hill_rearguard'),
       (SELECT MAX(spawn_index) + 1 FROM level_wave_enemy_spawn WHERE level_wave_id = wave.id),
       1, 6.0, 1.0, 0
FROM level_wave AS wave
WHERE wave.level_info_id = '42e95fce-6da1-416d-bf69-24f70bb4dc52'
  AND wave.wave_index = (SELECT MAX(wave_index) FROM level_wave WHERE level_info_id = wave.level_info_id);
