# Hero starts from GeoJSON

The game uses each role's `hero_spawn` Point coordinates verbatim. There is no
exit inset, road projection, boundary clamping, scenery/occlusion search, or
hero separation adjustment. `HeroSpawn` contains only role, feature ID and
position. `LevelRunner` reads `deployment.spawn.position`, connects a node at
that exact position to the movement graph, and uses it for initial deployment
and every respawn. Resizing changes only the projection. Hero identity or sprite
size cannot alter starting coordinates.

```json
{
  "type": "FeatureCollection",
  "heroCount": 2,
  "features": [
    {
      "type": "Feature",
      "id": "gameplay.hero_spawn.primary",
      "geometry": { "type": "Point", "coordinates": [1520.25, 1100.75] },
      "properties": { "kind": "hero_spawn", "heroRoles": ["primary"] }
    },
    {
      "type": "Feature",
      "id": "gameplay.hero_spawn.secondary",
      "geometry": { "type": "Point", "coordinates": [1700.5, 900.125] },
      "properties": { "kind": "hero_spawn", "heroRoles": ["secondary"] }
    }
  ]
}
```

This example shows hero fields only; complete editor exports also include path,
entrance, exit, button, slot and level metadata. Coordinates are canonical game
units, origin lower left, positive Y up.

Each available role must occur exactly once in an explicit Point with a unique
ID and finite coordinates. The game rejects missing/duplicated roles and legacy
role assignments on `goal_point` exits. There is no fallback. Levels 1–5 have one
hero; levels 6–15 have two. Current chosen-hero rankings determine primary and
secondary. A player with one chosen hero deploys only primary even on a two-hero
map; the unused secondary start remains in the map.

The primary (person + 1) and secondary (person + 2) editor tools set these points.
Clicking again repositions the one start for that role; drag, keyboard nudge,
X/Y editing, removal and undo/redo are supported. Disabled roles retain their
native draft coordinates but are excluded from export. Every enabled role needs
a point before export. Exits are completely independent.

Editor import compatibility copies an older document's explicitly assigned exit
coordinates into independent starts once. This happens only on import: no
insetting, repair of missing assignments, or runtime migration. Resaving emits
native position fields; GeoJSON export always emits `hero_spawn` points.

All 15 bundled maps have explicit points. The migration reused previously
recorded pair/minimum positions for levels 1–14 and the corrected Charleston
positions, verifying their source exit coordinates against each map. Provenance
and coordinates are recorded in
`reports/hero-geojson-only-2026-09-10/map-migration.json`. Historical placement
algorithms and their reports are superseded.

## Verification

`swift test` covers exact fractional coordinates, role ranking, capacity, missing
or duplicate starts, all bundled maps, native/GeoJSON round trips, legacy editor
migration, exit deletion independence and undo/redo.

The physical-device probe uses the actual runner in a separate app with its own
save. It checks all levels, pair/solo/ranking changes, exact initial positions,
respawns, and resize invariance. `--custom-starts` modifies only its temporary
Charleston copy to use fractional off-road coordinates, proving those authored
points are honored. No Simulator is used.

```sh
python3 Tools/check_hero_exits_on_device.py --device PHYSICAL_IPHONE_ID \
  --all-levels --custom-starts --output Tools/reports/hero-geojson-only/device
```
