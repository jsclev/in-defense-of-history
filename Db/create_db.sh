#!/bin/sh
set -e
cd "$(dirname "$0")" || exit 1

if [ "$#" -ne 0 ]; then
    echo "Usage: $0" >&2
    exit 2
fi

database=in_defense_of_history.sqlite
if lsof "$database" >/dev/null 2>&1; then
    echo "ERROR: $database is currently open in another process:" >&2
    lsof "$database" >&2
    echo "Close that connection, then re-run create_db.sh." >&2
    exit 1
fi
rm -f "$database" "$database-wal" "$database-shm" "$database-journal"
trap 'rm -f "$database" "$database-wal" "$database-shm" "$database-journal"' EXIT
trap 'exit 1' HUP INT TERM

sqlite3 -bail "$database" < DDL/create_tables.sql
sqlite3 -bail "$database" < DDL/create_combat_rules.sql

# Add all the data
sqlite3 -bail "$database" < DML/combat_rules.sql
sqlite3 -bail "$database" < DML/virtual_canvas.sql
sqlite3 -bail "$database" < DML/campaigns.sql
sqlite3 -bail "$database" < DML/Levels/level_01_battle_road.sql
sqlite3 -bail "$database" < DML/Levels/level_02_bunker_hill.sql
sqlite3 -bail "$database" < DML/Levels/level_03_great_bridge.sql
sqlite3 -bail "$database" < DML/Levels/level_04_moores_creek_bridge.sql
sqlite3 -bail "$database" < DML/Levels/level_05_dorchester_heights.sql
sqlite3 -bail "$database" < DML/Levels/level_06_sullivans_island.sql
sqlite3 -bail "$database" < DML/Levels/level_07_long_island.sql
sqlite3 -bail "$database" < DML/Levels/level_08_trenton.sql
sqlite3 -bail "$database" < DML/Levels/level_09_princeton.sql
sqlite3 -bail "$database" < DML/Levels/level_10_fort_ann.sql
sqlite3 -bail "$database" < DML/Levels/level_11_saratoga.sql
sqlite3 -bail "$database" < DML/Levels/level_12_kettle_creek.sql
sqlite3 -bail "$database" < DML/Levels/level_13_new_haven.sql
sqlite3 -bail "$database" < DML/Levels/level_14_savannah.sql
sqlite3 -bail "$database" < DML/Levels/level_15_charleston.sql
sqlite3 -bail "$database" < DML/Levels/level_16_kips_bay.sql
sqlite3 -bail "$database" < DML/Levels/level_17_harlem_heights.sql
sqlite3 -bail "$database" < DML/Levels/level_18_pells_point.sql
sqlite3 -bail "$database" < DML/Levels/level_19_white_plains.sql
sqlite3 -bail "$database" < DML/Levels/level_20_fort_washington.sql
sqlite3 -bail "$database" < DML/Levels/level_21_monmouth.sql
sqlite3 -bail "$database" < DML/Levels/level_22_rhode_island.sql
sqlite3 -bail "$database" < DML/Levels/level_23_stony_point.sql
sqlite3 -bail "$database" < DML/Levels/level_24_savannah.sql
sqlite3 -bail "$database" < DML/Levels/level_25_flamborough_head.sql
sqlite3 -bail "$database" < DML/Levels/level_26_quebec.sql
sqlite3 -bail "$database" < DML/Levels/level_27_valcour_island.sql
sqlite3 -bail "$database" < DML/Levels/level_28_hubbardton.sql
sqlite3 -bail "$database" < DML/Levels/level_29_fort_stanwix.sql
sqlite3 -bail "$database" < DML/Levels/level_30_oriskany.sql
sqlite3 -bail "$database" < DML/Levels/level_31_bennington.sql
sqlite3 -bail "$database" < DML/Levels/level_32_coochs_bridge.sql
sqlite3 -bail "$database" < DML/Levels/level_33_brandywine.sql
sqlite3 -bail "$database" < DML/Levels/level_34_paoli.sql
sqlite3 -bail "$database" < DML/Levels/level_35_germantown.sql
sqlite3 -bail "$database" < DML/Levels/level_36_white_marsh.sql
sqlite3 -bail "$database" < DML/Levels/level_37_camden.sql
sqlite3 -bail "$database" < DML/Levels/level_38_kings_mountain.sql
sqlite3 -bail "$database" < DML/Levels/level_39_cowpens.sql
sqlite3 -bail "$database" < DML/Levels/level_40_guilford_courthouse.sql
sqlite3 -bail "$database" < DML/Levels/level_41_eutaw_springs.sql
sqlite3 -bail "$database" < DML/level_tower_unlocks.sql
sqlite3 -bail "$database" < DML/enemy_types.sql
sqlite3 -bail "$database" < DML/difficulties.sql
sqlite3 -bail "$database" < DML/selected_difficulty.sql
sqlite3 -bail "$database" < DML/hud_layout.sql
sqlite3 -bail "$database" < DML/player_settings.sql
sqlite3 -bail "$database" < DML/tower_types.sql
sqlite3 -bail "$database" < DML/towers.sql
sqlite3 -bail "$database" < DML/melee_units.sql
sqlite3 -bail "$database" < DML/reinforcement_config.sql
sqlite3 -bail "$database" < DML/level_waves.sql
sqlite3 -bail "$database" < DML/level_wave_enemy_spawns.sql
sqlite3 -bail "$database" < DML/level_02_bunker_hill_waves.sql
sqlite3 -bail "$database" < DML/level_12_kettle_creek_waves.sql
sqlite3 -bail "$database" < DML/level_13_new_haven_waves.sql
sqlite3 -bail "$database" < DML/level_15_charleston_waves.sql
sqlite3 -bail "$database" < DML/Heroes/01_Israel_Putnam.sql
sqlite3 -bail "$database" < DML/Heroes/02_Henry_Knox.sql
sqlite3 -bail "$database" < DML/Heroes/03_Louis_Duportail.sql
sqlite3 -bail "$database" < DML/Heroes/04_George_Washington.sql
sqlite3 -bail "$database" < DML/Heroes/05_Mary_Hays.sql
sqlite3 -bail "$database" < DML/Heroes/06_Daniel_Morgan.sql
sqlite3 -bail "$database" < DML/Heroes/07_Benedict_Arnold.sql
sqlite3 -bail "$database" < DML/Heroes/08_Friedrich_von_Steuben.sql
sqlite3 -bail "$database" < DML/Heroes/09_Francis_Marion.sql
sqlite3 -bail "$database" < DML/Heroes/10_Nathanael_Greene.sql
sqlite3 -bail "$database" < DML/Heroes/11_William_Prescott.sql
sqlite3 -bail "$database" < DML/Heroes/12_Thaddeus_Kosciuszko.sql
sqlite3 -bail "$database" < DML/Heroes/13_Salem_Poor.sql
sqlite3 -bail "$database" < DML/Heroes/14_John_Glover.sql
sqlite3 -bail "$database" < DML/Heroes/15_Horatio_Gates.sql
sqlite3 -bail "$database" < DML/hero_combat.sql
sqlite3 -bail "$database" < DML/level_heroes.sql
sqlite3 -bail "$database" < DML/selected_heroes.sql
sqlite3 -bail "$database" < DML/unlocked_heroes.sql

# Add the simulator data
sqlite3 -bail "$database" < DML/Simulator/sim_enemy_types.sql
sqlite3 -bail "$database" < DML/Simulator/sim_enemy_type_bounty.sql
sqlite3 -bail "$database" < DML/Simulator/sim_melee_units.sql
sqlite3 -bail "$database" < DML/Simulator/sim_tower_ranges.sql
sqlite3 -bail "$database" < DML/Simulator/sim_tower_sweep.sql

test "$(sqlite3 "$database" 'PRAGMA integrity_check;')" = ok
test -z "$(sqlite3 "$database" 'PRAGMA foreign_key_check;')"
trap - EXIT HUP INT TERM
echo "Database rebuilt and validated."
