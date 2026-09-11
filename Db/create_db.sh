#!/bin/sh
set -e
cd "$(dirname "$0")" || exit 1

# Phone builds need only the bundled database; the desktop editor may keep
# its own Documents copy open. Default behavior still updates both copies.
sync_documents=true
case "${1:-}" in
    --bundle-only) sync_documents=false ;;
    "") ;;
    *) echo "Usage: $0 [--bundle-only]" >&2; exit 2 ;;
esac
set -- in_defense_of_history.sqlite
if [ "$sync_documents" = true ]; then
    set -- "$@" "$HOME/Documents/in_defense_of_history.sqlite"
fi
for db in "$@"; do
    if lsof "$db" >/dev/null 2>&1; then
        echo "ERROR: $db is currently open in another process:" >&2
        lsof "$db" >&2
        echo "Close that connection, then re-run create_db.sh." >&2
        exit 1
    fi
done

# Build and validate separately so a failed seed cannot destroy the last DB.
build_db=$(mktemp "${TMPDIR:-/tmp}/td-content-db.XXXXXX")
trap 'rm -f "$build_db"' EXIT HUP INT TERM
sqlite3 "$build_db" ""

sqlite3 -bail "$build_db" < DDL/create_tables.sql

# Add all the data
sqlite3 -bail "$build_db" < DML/virtual_canvas.sql
sqlite3 -bail "$build_db" < DML/campaigns.sql
sqlite3 -bail "$build_db" < DML/Levels/level_01_battle_road.sql
sqlite3 -bail "$build_db" < DML/Levels/level_02_bunker_hill.sql
sqlite3 -bail "$build_db" < DML/Levels/level_03_great_bridge.sql
sqlite3 -bail "$build_db" < DML/Levels/level_04_moores_creek_bridge.sql
sqlite3 -bail "$build_db" < DML/Levels/level_05_dorchester_heights.sql
sqlite3 -bail "$build_db" < DML/Levels/level_06_sullivans_island.sql
sqlite3 -bail "$build_db" < DML/Levels/level_07_long_island.sql
sqlite3 -bail "$build_db" < DML/Levels/level_08_trenton.sql
sqlite3 -bail "$build_db" < DML/Levels/level_09_princeton.sql
sqlite3 -bail "$build_db" < DML/Levels/level_10_fort_ann.sql
sqlite3 -bail "$build_db" < DML/Levels/level_11_saratoga.sql
sqlite3 -bail "$build_db" < DML/Levels/level_12_kettle_creek.sql
sqlite3 -bail "$build_db" < DML/Levels/level_13_new_haven.sql
sqlite3 -bail "$build_db" < DML/Levels/level_14_savannah.sql
sqlite3 -bail "$build_db" < DML/Levels/level_15_charleston.sql
sqlite3 -bail "$build_db" < DML/Levels/level_16_kips_bay.sql
sqlite3 -bail "$build_db" < DML/Levels/level_17_harlem_heights.sql
sqlite3 -bail "$build_db" < DML/Levels/level_18_pells_point.sql
sqlite3 -bail "$build_db" < DML/Levels/level_19_white_plains.sql
sqlite3 -bail "$build_db" < DML/Levels/level_20_fort_washington.sql
sqlite3 -bail "$build_db" < DML/Levels/level_21_monmouth.sql
sqlite3 -bail "$build_db" < DML/Levels/level_22_rhode_island.sql
sqlite3 -bail "$build_db" < DML/Levels/level_23_stony_point.sql
sqlite3 -bail "$build_db" < DML/Levels/level_24_savannah.sql
sqlite3 -bail "$build_db" < DML/Levels/level_25_flamborough_head.sql
sqlite3 -bail "$build_db" < DML/Levels/level_26_quebec.sql
sqlite3 -bail "$build_db" < DML/Levels/level_27_valcour_island.sql
sqlite3 -bail "$build_db" < DML/Levels/level_28_hubbardton.sql
sqlite3 -bail "$build_db" < DML/Levels/level_29_fort_stanwix.sql
sqlite3 -bail "$build_db" < DML/Levels/level_30_oriskany.sql
sqlite3 -bail "$build_db" < DML/Levels/level_31_bennington.sql
sqlite3 -bail "$build_db" < DML/Levels/level_32_coochs_bridge.sql
sqlite3 -bail "$build_db" < DML/Levels/level_33_brandywine.sql
sqlite3 -bail "$build_db" < DML/Levels/level_34_paoli.sql
sqlite3 -bail "$build_db" < DML/Levels/level_35_germantown.sql
sqlite3 -bail "$build_db" < DML/Levels/level_36_white_marsh.sql
sqlite3 -bail "$build_db" < DML/Levels/level_37_camden.sql
sqlite3 -bail "$build_db" < DML/Levels/level_38_kings_mountain.sql
sqlite3 -bail "$build_db" < DML/Levels/level_39_cowpens.sql
sqlite3 -bail "$build_db" < DML/Levels/level_40_guilford_courthouse.sql
sqlite3 -bail "$build_db" < DML/Levels/level_41_eutaw_springs.sql
sqlite3 -bail "$build_db" < DML/level_tower_unlocks.sql
sqlite3 -bail "$build_db" < DML/enemy_types.sql
sqlite3 -bail "$build_db" < DML/difficulties.sql
sqlite3 -bail "$build_db" < DML/selected_difficulty.sql
sqlite3 -bail "$build_db" < DML/hud_layout.sql
sqlite3 -bail "$build_db" < DML/tower_types.sql
sqlite3 -bail "$build_db" < DML/towers.sql
sqlite3 -bail "$build_db" < DML/melee_units.sql
sqlite3 -bail "$build_db" < DML/reinforcement_config.sql
sqlite3 -bail "$build_db" < DML/level_waves.sql
sqlite3 -bail "$build_db" < DML/level_wave_enemy_spawns.sql
sqlite3 -bail "$build_db" < DML/level_02_bunker_hill_waves.sql
sqlite3 -bail "$build_db" < DML/level_12_kettle_creek_waves.sql
sqlite3 -bail "$build_db" < DML/level_13_new_haven_waves.sql
sqlite3 -bail "$build_db" < DML/level_15_charleston_waves.sql
sqlite3 -bail "$build_db" < DML/Heroes/01_Israel_Putnam.sql
sqlite3 -bail "$build_db" < DML/Heroes/02_Henry_Knox.sql
sqlite3 -bail "$build_db" < DML/Heroes/03_Louis_Duportail.sql
sqlite3 -bail "$build_db" < DML/Heroes/04_George_Washington.sql
sqlite3 -bail "$build_db" < DML/Heroes/05_Mary_Hays.sql
sqlite3 -bail "$build_db" < DML/Heroes/06_Daniel_Morgan.sql
sqlite3 -bail "$build_db" < DML/Heroes/07_Benedict_Arnold.sql
sqlite3 -bail "$build_db" < DML/Heroes/08_Friedrich_von_Steuben.sql
sqlite3 -bail "$build_db" < DML/Heroes/09_Francis_Marion.sql
sqlite3 -bail "$build_db" < DML/Heroes/10_Nathanael_Greene.sql
sqlite3 -bail "$build_db" < DML/Heroes/11_William_Prescott.sql
sqlite3 -bail "$build_db" < DML/Heroes/12_Thaddeus_Kosciuszko.sql
sqlite3 -bail "$build_db" < DML/Heroes/13_Salem_Poor.sql
sqlite3 -bail "$build_db" < DML/Heroes/14_John_Glover.sql
sqlite3 -bail "$build_db" < DML/Heroes/15_Horatio_Gates.sql
sqlite3 -bail "$build_db" < DML/hero_combat.sql
sqlite3 -bail "$build_db" < DML/level_heroes.sql
sqlite3 -bail "$build_db" < DML/selected_heroes.sql
sqlite3 -bail "$build_db" < DML/unlocked_heroes.sql

# Add the simulator data
sqlite3 -bail "$build_db" < DML/Simulator/sim_enemy_types.sql
sqlite3 -bail "$build_db" < DML/Simulator/sim_enemy_type_bounty.sql
sqlite3 -bail "$build_db" < DML/Simulator/sim_melee_units.sql
sqlite3 -bail "$build_db" < DML/Simulator/sim_tower_ranges.sql

# cp in_defense_of_history.sqlite "../Tests App/Resources/Db/test_in_defense_of_history.sqlite"

test "$(sqlite3 "$build_db" 'PRAGMA integrity_check;')" = ok
test -z "$(sqlite3 "$build_db" 'PRAGMA foreign_key_check;')"
cp "$build_db" in_defense_of_history.sqlite.tmp
mv -f in_defense_of_history.sqlite.tmp in_defense_of_history.sqlite

# Desktop balancing/editor data is optional for phone-only deployments.
if [ "$sync_documents" = true ]; then
    cp -f in_defense_of_history.sqlite "$HOME/Documents/in_defense_of_history.sqlite.tmp"
    mv -f "$HOME/Documents/in_defense_of_history.sqlite.tmp" "$HOME/Documents/in_defense_of_history.sqlite"
fi
echo "Database rebuilt and validated."
# cp -f in_defense_of_history.sqlite ~/Documents/liberty-line-simulations.sqlite
