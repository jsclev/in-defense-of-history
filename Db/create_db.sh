#!/bin/sh
cd "$(dirname "$0")" || exit 1

for db in redcoat_raid.sqlite "$HOME/Documents/redcoat_raid.sqlite"; do
    if lsof "$db" >/dev/null 2>&1; then
        echo "ERROR: $db is currently open in another process:" >&2
        lsof "$db" >&2
        echo "Close that connection, then re-run create_db.sh." >&2
        exit 1
    fi
done

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
sqlite3 redcoat_raid.sqlite < DML/Heroes/01_Israel_Putnam.sql
sqlite3 redcoat_raid.sqlite < DML/Heroes/02_Henry_Knox.sql
sqlite3 redcoat_raid.sqlite < DML/Heroes/03_Louis_Duportail.sql
sqlite3 redcoat_raid.sqlite < DML/Heroes/04_George_Washington.sql
sqlite3 redcoat_raid.sqlite < DML/Heroes/05_Mary_Hays.sql
sqlite3 redcoat_raid.sqlite < DML/Heroes/06_Daniel_Morgan.sql
sqlite3 redcoat_raid.sqlite < DML/Heroes/07_Benedict_Arnold.sql
sqlite3 redcoat_raid.sqlite < DML/Heroes/08_Friedrich_von_Steuben.sql
sqlite3 redcoat_raid.sqlite < DML/Heroes/09_Francis_Marion.sql
sqlite3 redcoat_raid.sqlite < DML/Heroes/10_Nathanael_Greene.sql
sqlite3 redcoat_raid.sqlite < DML/Heroes/11_William_Prescott.sql
sqlite3 redcoat_raid.sqlite < DML/Heroes/12_Thaddeus_Kosciuszko.sql
sqlite3 redcoat_raid.sqlite < DML/Heroes/13_Salem_Poor.sql
sqlite3 redcoat_raid.sqlite < DML/Heroes/14_John_Glover.sql
sqlite3 redcoat_raid.sqlite < DML/Heroes/15_Horatio_Gates.sql
sqlite3 redcoat_raid.sqlite < DML/selected_heroes.sql
sqlite3 redcoat_raid.sqlite < DML/unlocked_heroes.sql
sqlite3 redcoat_raid.sqlite < DML/fort_ann_level.sql
sqlite3 redcoat_raid.sqlite < DML/kettle_creek_level.sql
sqlite3 redcoat_raid.sqlite < DML/level_path_points.sql
sqlite3 redcoat_raid.sqlite < DML/level_tower_slots.sql
sqlite3 redcoat_raid.sqlite < DML/savannah_bastion_v7.sql

# Add the simulator data
sqlite3 redcoat_raid.sqlite < DML/Simulator/sim_enemy_types.sql
sqlite3 redcoat_raid.sqlite < DML/Simulator/sim_enemy_type_bounty.sql
sqlite3 redcoat_raid.sqlite < DML/Simulator/sim_melee_units.sql

# cp redcoat_raid.sqlite "../Tests App/Resources/Db/test_redcoat_raid.sqlite"

# Simulator
cp -f redcoat_raid.sqlite ~/Documents/redcoat_raid.sqlite.tmp
mv -f ~/Documents/redcoat_raid.sqlite.tmp ~/Documents/redcoat_raid.sqlite
# cp -f redcoat_raid.sqlite ~/Documents/redcoat-raid-simulations.sqlite
