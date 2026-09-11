Charleston has four explicit enemy routes and 15 waves totaling 424 enemies.
Each route is an `enemy_route` GeoJSON `LineString` with a zero-based
`pathIndex`, a name, and `entranceID`/`exitID` references to authored markers.
Wave groups reference these route indices. The two entrance call buttons
cover routes `[0, 2]` and `[1, 3]` respectively.

| Route | Road | Entrance | Exit |
| --- | --- | --- | --- |
| 0 | Western lower road | Left `(495.65, 1221.96)` | Bottom `(1587, 549)` |
| 1 | Northern upper road | Top `(1224, 1495)` | Right `(2370, 1235)` |
| 2 | Western upper flank | Left `(495.65, 1221.96)` | Right `(2370, 1235)` |
| 3 | Northern central flank | Top `(1224, 1495)` | Bottom `(1587, 549)` |

The offline authoring tool follows the native map's road centerlines and uses
the production `HeroMovementArea` model to route around erased ground. It
checks every complete segment, including corners and polygon holes, before
saving the route. Runtime `LevelLoader` reads these GeoJSON routes directly;
malformed explicit routes fail loading instead of falling back to stale SQL.
Levels without explicit routes retain their existing SQL paths. Enemy routes
do not enlarge the movement area.

Native map save/load and GeoJSON import/export preserve routes and all four
wave route indices. Erasing ground beneath a route causes export validation
to fail until that route is repaired or regenerated. The generator preserves
the authored area, markers, 18 tower slots, hero configuration, and embedded
artwork.

Times below are game time from the manual first-wave call, assuming no early
calls. Later waves reveal their call buttons 13 seconds before the listed
start. Calling a wave early shifts the following schedule from its actual
start and awards the existing fixed 13 coins. Wave 1 awards no early-call bonus.

| Wave | Start | Route 0 | Route 1 | Route 2 | Route 3 | Focus |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| 1 | 0:00 | 16 | 0 | 0 | 0 | Left approach |
| 2 | 0:32 | 4 | 16 | 0 | 0 | Northern advance |
| 3 | 1:06 | 8 | 12 | 0 | 0 | Both roads |
| 4 | 1:40 | 6 | 9 | 8 | 0 | Skirmisher rush |
| 5 | 2:15 | 17 | 9 | 0 | 0 | Drums and bayonets |
| 6 | 2:51 | 8 | 8 | 4 | 8 | Infiltration |
| 7 | 3:28 | 12 | 6 | 0 | 6 | Cavalry screen |
| 8 | 4:06 | 11 | 11 | 6 | 0 | Highland assault |
| 9 | 4:45 | 12 | 4 | 0 | 10 | Grenadiers and riders |
| 10 | 5:25 | 10 | 14 | 8 | 0 | Officer-led columns |
| 11 | 6:06 | 11 | 12 | 0 | 6 | Siege train |
| 12 | 6:48 | 5 | 9 | 10 | 8 | The guards arrive |
| 13 | 7:31 | 10 | 6 | 8 | 10 | Relentless pursuit |
| 14 | 8:15 | 10 | 16 | 5 | 5 | Invest the city |
| 15 | 9:00 | 14 | 14 | 11 | 11 | Final assault |

The opening introduces infantry and each main entrance before adding the
alternate roads. Fast flanking groups and spies interrupt the infantry
progression, followed by grenadiers, officers, artillery, and guards. The final
assault uses all four routes, with 25 enemies per entrance. Starting gold is
500 and lives are 20. Combat difficulty still needs a full player run; route
travel times and tower choices affect the actual pressure.

Edit `PLAN`, `STARTS`, and the route variants in
[the generator](generate_charleston_waves.py), then run from the repository root:

```sh
python3 Tools/generate_charleston_waves.py
sh Db/create_db.sh --bundle-only
```

The generator uses [the Swift authoring tool](GenerateCharlestonRoutes.swift)
and writes the [path SQL](../Db/DML/Levels/level_15_charleston.sql),
[wave SQL](../Db/DML/level_15_charleston_waves.sql),
[GeoJSON](../Db/level_15_charleston.geojson), and
[native map](../Db/level_15_charleston.tdmap) together. Wave IDs remain stable
for hero unlock references. SQL paths are generated copies of the GeoJSON
routes, never independently maintained geometry.

`create_db.sh` builds a temporary database, checks integrity and foreign keys,
then replaces the bundled database. Its default invocation also updates the
desktop Documents copy; `--bundle-only` allows phone builds while the editor
has its Documents database open. The wave generator alone does not rebuild
the database.

Verification on September 10, 2026:

- All 184 host Swift tests passed, including production loader tests, every
  Charleston segment and densely sampled traversal, all wave assignments, and
  native/GeoJSON persistence. Tests also reject shortcuts across polygon holes
  and prove stale SQL cannot override explicit GeoJSON routes.
- The required 79 Level Editor regression checks and macOS build passed.
- Regenerating all four content files produced byte-for-byte identical output.
- The signed iPhone game build passed. A separate probe on the physical iPhone
  passed 12 real `LevelRunner` loads, compared runtime and SQL paths with the
  GeoJSON, validated all route segments, and checked every automatic wave
  deadline, entrance button count, and all 424 queued enemies.
  [Device evidence](reports/charleston-enemy-routes/device/hero-exits.json).
- The game was installed and launched on John's iPhone. Its live Documents
  database was copied back and its Level 15 record, paths, waves, and spawns
  exactly matched the rebuilt database; integrity and foreign-key checks
  passed. The signed app's GeoJSON and database also matched the source files.
  [Deployment verification](reports/charleston-enemy-routes/verification.json).
  [Route diagram](reports/charleston-enemy-routes/routes.png).
- These are model, persistence, and device runtime checks, not a full combat
  playthrough or an interactive Level Editor UI review.
