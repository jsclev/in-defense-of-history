rm redcoat_raid.sqlite 2>/dev/null
sqlite3 redcoat_raid.sqlite ""

sqlite3 redcoat_raid.sqlite < DDL/create_tables.sql
sqlite3 redcoat_raid.sqlite < DML/campaigns.sql
sqlite3 redcoat_raid.sqlite < DML/level_tower_slots.sql
sqlite3 redcoat_raid.sqlite < DML/level_tower_unlocks.sql
sqlite3 redcoat_raid.sqlite < DML/enemy_types.sql
sqlite3 redcoat_raid.sqlite < DML/tower_types.sql
sqlite3 redcoat_raid.sqlite < DML/towers.sql
sqlite3 redcoat_raid.sqlite < DML/level_waves.sql
sqlite3 redcoat_raid.sqlite < DML/level_wave_spawns.sql
sqlite3 redcoat_raid.sqlite < DML/heroes.sql
sqlite3 redcoat_raid.sqlite < DML/selected_heroes.sql
sqlite3 redcoat_raid.sqlite < DML/unlocked_heroes.sql
sqlite3 redcoat_raid.sqlite < DML/level_paths.sql
sqlite3 redcoat_raid.sqlite < DML/great_bridge_level.sql
sqlite3 redcoat_raid.sqlite < DML/dorchester_heights_level.sql
sqlite3 redcoat_raid.sqlite < DML/sullivans_island_level.sql
sqlite3 redcoat_raid.sqlite < DML/fort_ann_level.sql
sqlite3 redcoat_raid.sqlite < DML/saratoga_level.sql
sqlite3 redcoat_raid.sqlite < DML/kettle_creek_level.sql
sqlite3 redcoat_raid.sqlite < DML/new_haven_level.sql
sqlite3 redcoat_raid.sqlite < DML/savannah_level.sql
sqlite3 redcoat_raid.sqlite < DML/standardized_campaign_levels.sql
sqlite3 redcoat_raid.sqlite < DML/charleston_yorktown_v3_override.sql
sqlite3 redcoat_raid.sqlite < DML/level_map_images.sql
sqlite3 redcoat_raid.sqlite < DML/savannah_kr_complexity_override.sql
sqlite3 redcoat_raid.sqlite < DML/savannah_bastion_v7.sql
sqlite3 redcoat_raid.sqlite < DML/tower_unlock_experiment.sql
sqlite3 redcoat_raid.sqlite < DML/lexington_design_constraints.sql
sqlite3 redcoat_raid.sqlite < DML/savannah_design_constraints.sql
sqlite3 redcoat_raid.sqlite < DML/level_wave_counts.sql
sqlite3 redcoat_raid.sqlite < DML/sim_stat_bounds.sql
sqlite3 redcoat_raid.sqlite < DML/sim_enemy_types.sql
sqlite3 redcoat_raid.sqlite < DML/sim_enemy_type_bounty.sql
sqlite3 redcoat_raid.sqlite < DML/sim_melee_units.sql

# cp redcoat_raid.sqlite "../Tests App/Resources/Db/test_redcoat_raid.sqlite"

# Simulator
cp -f redcoat_raid.sqlite ~/Documents/redcoat_raid.sqlite
# cp -f redcoat_raid.sqlite ~/Documents/redcoat-raid-simulations.sqlite
