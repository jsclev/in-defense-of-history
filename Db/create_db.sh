rm redcoat_raid.sqlite 2>/dev/null
sqlite3 redcoat_raid.sqlite ""

sqlite3 redcoat_raid.sqlite < DDL/create_tables.sql

# Add all the data
sqlite3 redcoat_raid.sqlite < DML/campaigns.sql
sqlite3 redcoat_raid.sqlite < DML/levels.sql
sqlite3 redcoat_raid.sqlite < DML/level_tower_unlocks.sql
sqlite3 redcoat_raid.sqlite < DML/enemy_types.sql
sqlite3 redcoat_raid.sqlite < DML/tower_types.sql
sqlite3 redcoat_raid.sqlite < DML/towers.sql
sqlite3 redcoat_raid.sqlite < DML/level_waves.sql
sqlite3 redcoat_raid.sqlite < DML/level_wave_enemy_spawns.sql
sqlite3 redcoat_raid.sqlite < DML/heroes.sql
sqlite3 redcoat_raid.sqlite < DML/selected_heroes.sql
sqlite3 redcoat_raid.sqlite < DML/unlocked_heroes.sql
sqlite3 redcoat_raid.sqlite < DML/fort_ann_level.sql
sqlite3 redcoat_raid.sqlite < DML/kettle_creek_level.sql
sqlite3 redcoat_raid.sqlite < DML/level_01_path_points.sql
sqlite3 redcoat_raid.sqlite < DML/level_tower_slots.sql
sqlite3 redcoat_raid.sqlite < DML/level_map_images.sql
sqlite3 redcoat_raid.sqlite < DML/savannah_bastion_v7.sql
sqlite3 redcoat_raid.sqlite < DML/level_wave_counts.sql

# Add the simulator data
sqlite3 redcoat_raid.sqlite < DML/Simulator/sim_stat_bounds.sql
sqlite3 redcoat_raid.sqlite < DML/Simulator/sim_enemy_types.sql
sqlite3 redcoat_raid.sqlite < DML/Simulator/sim_enemy_type_bounty.sql
sqlite3 redcoat_raid.sqlite < DML/Simulator/sim_melee_units.sql

# cp redcoat_raid.sqlite "../Tests App/Resources/Db/test_redcoat_raid.sqlite"

# Simulator
cp -f redcoat_raid.sqlite ~/Documents/redcoat_raid.sqlite
# cp -f redcoat_raid.sqlite ~/Documents/redcoat-raid-simulations.sqlite
