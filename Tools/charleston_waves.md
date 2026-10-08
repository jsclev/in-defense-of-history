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

The first seven waves introduce all six routes, then the second half combines
compact infantry columns with distinct specialist attacks. Enemy counts rise
gradually: `18, 22, 28, 34, 40, 46, 54, 62, 70, 80, 88, 96, 108, 116, 129`.
The 991 authored enemies exclude reserves: seven officers can each dispatch at
most four additional regulars, for a ceiling of 1,019 enemies.

| Waves | Defensive problem |
| --- | --- |
| 1–4 | Establish both fronts; meet covered skirmishers and central-road infantry. |
| 5–7 | Reveal a small concealed group with a hero, support blockers against hard-hitting infantry, then cover the cavalry road. |
| 8–10 | Interrupt one officer's reserve signal before facing separated officers and mixed assault groups. |
| 11–12 | Sustain damage against slow siege crews and guards while dealing with spaced fast flanks. |
| 13–14 | Handle relief columns, reserves, and the final cavalry push through established routes. |
| 15 | Engage Clinton's siege detachment to stop bombardment while escort pulses use all six roads. |

Routes 1 and 3 are much shorter than route 4. First encounters with concealed
troops and cavalry use longer approaches, and specialist groups are staggered
instead of arriving simultaneously at both entrances. Clinton enters route 4
eight seconds into the final wave; escort spawns continue through second 50.
The final wave has no concealed troops competing for the boss's blocking force.

Compact regulars reward artillery and morale damage, covered skirmishers and
disciplined elites reward direct fire, and officers and the boss reward timely
blocking. Dragoons bypass blocking troops. Rangers are immune while concealed
until revealed by a nearby living hero. Officers call finite reserves from their
own entrance; blocking interrupts the signal. Only Clinton has active siege
bombardment here. Drummer rallies, officer auras, ordinary artillery bombardment,
and spy sabotage are not implemented and are not assumed by this wave design.

These are design intentions, not a demonstrated winning strategy or a tower
quota. Content/parity regressions do not establish difficulty or win rates;
that requires playtesting or a new shared-engine study with held-out seeds.
Existing GA demonstrations of older waves are incompatible with this content.

Wave starts, in game time from the manual first call, are `0, 32, 66, 102, 140,
180, 222, 266, 312, 358, 406, 454, 502, 550, 600` seconds. Later waves reveal their
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
