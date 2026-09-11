# Hero starting coordinates come only from GeoJSON

The game now assigns `deployment.spawn.position` directly. Removed
`HeroExitPlacement`, `HeroOcclusionMask`, placement modes, exit insets, road
projection and occupancy-based relocation. The movement graph receives a node
at the exact authored point; initial deployment and respawns use that node.
No hero identity, sprite size, viewport or scenery can alter the point.

The loader requires one `hero_spawn` Point per enabled role and rejects missing
points or legacy exit role assignments. All 15 bundled maps now contain explicit
points (25 total); exits have no hero roles. Map geometry, waves and other data
are preserved. `map-migration.json` records the earlier measured starts used to
seed the points, including the corrected Charleston positions.

The editor exports only explicit points and reports missing enabled starts.
Removing a start clears it, and moving/deleting exits has no effect. Compatibility
import copies existing assigned exit coordinates once into independent points;
that conversion is confined to the editor and invents no missing points.

## Checks

- 124 host tests passed: exact fractional coordinates, role ordering, missing or
  duplicate starts, all 15 bundled maps, round trips, removal, exit independence,
  legacy editor import and undo/redo. See `tests.log`.
- macOS editor build passed. See `editor-build.log`.
- Signed diagnostic game built, installed and ran on the physical iPhone.
  `device/hero-exits.json` reports 54 successful actual LevelRunner loads across
  all 15 levels, pair/solo/ranking changes, exact initial positions, respawns,
  and resize invariance. Charleston additionally checks four viewport inputs.
- In the disposable diagnostic app only, Charleston used primary
  `[1520.25, 1100.75]` and secondary `[1700.5, 900.125]`. The probe compared both
  literal file coordinates and runtime positions, including after ranking
  changes. Neither the production maps nor the player's save use these test
  overrides.
- No Simulator was used. This is functional coordinate verification; no new
  artwork was created and no art recognition claim is made.

The obsolete algorithm tests were removed with the algorithm. Earlier reports
of inside-exit placement describe superseded behavior.

## Production delivery

The signed production game build passed, installed successfully, and launched on
the physical iPhone. See `game-build.log`, `production-install.json`, and
`production-launch.json`. All 15 GeoJSON files in the installed build were
verified byte-for-byte against the production source files; test coordinate
overrides are absent (`bundled-map-checks.json`).
