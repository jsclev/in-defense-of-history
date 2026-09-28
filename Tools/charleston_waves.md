Charleston uses two entrances, two exits, six explicit enemy routes, 19 tower
slots, and 15 waves. Each route is an `enemy_route` GeoJSON `LineString` with a
zero-based `pathIndex` and authored entrance/exit references. Entrance buttons
cover routes `[0, 2, 4]` and `[1, 3, 5]`.

| Route | Entrance | Road | Exit |
| --- | --- | --- | --- |
| 0 | 0 | Lower | 1 |
| 1 | 1 | Upper | 0 |
| 2 | 0 | Upper | 0 |
| 3 | 1 | Central | 1 |
| 4 | 0 | Central | 0 |
| 5 | 1 | Right | 1 |

The first seven waves introduce all six routes. Later waves send simultaneous,
compact regular-infantry columns from both entrances. Small groups of guards,
grenadiers, artillery, officers, and fast flankers maintain jobs for direct fire
and blocking. Light Dragoons retain their `rideDown` blocking immunity.

The balance goal is a winning defense with no tower family exceeding half the
built towers, and at least two artillery towers. Dense infantry exposes the
limited throughput of direct fire and rewards overlapping artillery coverage.
Regulars can be suppressed; replacing much of the late, highly disciplined
elite pressure makes morale more useful. Special explosives retain their HP
damage but inflict only a small morale shock, keeping artillery's role distinct.
These are combat incentives, not construction quotas. Validate unrestricted,
majority-ranged, and zero/one-artillery searches against the same full engine;
count completed purchases and use held-out seeds. Finite searches cannot prove
that every possible winning defense meets the goal.

Wave starts, in game time from the manual first call, are `0, 32, 66, 100, 135,
171, 208, 246, 285, 325, 366, 408, 451, 495, 540` seconds. Later waves reveal their
buttons 13 seconds before their automatic starts. An early call shifts the
following schedule from that actual start and awards 13 coins; wave 1 awards no
early-call bonus. Campaign starting money remains the SQL-authored 670 coins,
loaded through `LevelInfoDAO`. Map-editor starting gold is not a campaign budget.

Edit `PLAN` and `STARTS` in [the generator](generate_charleston_waves.py), then
regenerate wave content without changing any map geometry:

```sh
python3 Tools/generate_charleston_waves.py --waves-only
sh Db/create_db.sh
```

This updates [wave SQL](../Db/DML/level_15_charleston_waves.sql), the `waves` array
in [GeoJSON](../Db/level_15_charleston.geojson), and the saved
[native map](../Db/level_15_charleston.tdmap). Wave IDs remain stable for hero
unlock references. Geometry, markers, tower slots, hero placements and embedded
artwork remain intact.

For a deliberate route edit, first use
[GenerateCharlestonRoutes](GenerateCharlestonRoutes.swift) on the current native
map, then pass its two outputs with `--routes <routes.json> --geojson-base
<fresh.geojson>` instead of `--waves-only`. That mode also regenerates path SQL.
Do not maintain an independent second geometry in SQL. Runtime loading validates
explicit GeoJSON routes against the movement area; routes do not enlarge it.

`Db/create_db.sh` is the only database authoring path and checks integrity and
foreign keys. Close database connections before rebuilding. The wave generator
alone does not rebuild SQLite. `CharlestonWaveTests` checks loader/SQL/editor
parity, path traversal, timing, and route assignments. Full combat searches use
the native Simulator CLI and keep their databases and reports outside the repo;
see [the CLI reference](simulator_cli_reference.md).
