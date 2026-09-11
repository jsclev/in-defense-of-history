# Level Editor files

On macOS, startup reopens the most recently modified `.tdmap` from Open Recent.
Missing or unreadable files are skipped; with no usable recent map, the editor
opens a new untitled document. Opening an existing file closes pristine untitled
documents, while keeping edited documents and recovered autosaves open.

Select the hand-shaped **Pan** tool and drag to move the viewport at its current
zoom. Panning never changes map coordinates or the saved document. **Fit on
Screen** (Command-0) recenters the map, including after panning at Fit zoom.
Selected tower ranges use bright green, 3-point dashed outlines; the valid tower
placement boundary also uses a 3-point dashed outline at every zoom.

**Open / Save / Save As use `.tdmap`.** Use **Import GeoJSON…** and
**Export GeoJSON…** in the toolbar or File menu for interchange. Export is also
available with Shift-Command-E. An export does not replace the open document or
change its editable paths.

The **Eraser** removes the path surface inside its red circle as you drag,
including the edges of wide roads, painted dabs and imported GeoJSON areas.
Releasing commits the entire stroke as one undo step. Native road waypoints and
wave assignments remain editable: each road or paint stroke stores its combined
cutouts in an optional `erasedArea` geometry. New paint can fill those cutouts.
Native saves retain them; GeoJSON exports bake them into the final path outline.

The native JSON document has `format: "com.zippyzen.td.map"`, `version: 1`,
`canvas`, and `draft`. It preserves individual road names and waypoints, paint,
entrances/exits, hero capacity, primary/secondary starting positions, call-wave button
centers, slots, waves and their original road assignments, gold/lives,
the intended solution, image opacities, layer visibility, and embedded image
bytes. Background, guide and occlusion images travel with the file. Original
image paths are retained as labels and for migrating older documents; embedded
bytes take precedence when reopening. Undo history and temporary tool/zoom
state are session state, not saved document data.

Unversioned `.tdmap` documents still open. The next save embeds their referenced
images and writes the versioned format. A missing referenced image must be
located using its layer's Choose button or removed before saving, so a native
save cannot silently produce an incomplete document. Unsupported future native
versions are rejected.

## Flattened GeoJSON (formatVersion 2)

`LevelGeoJSON` owns an immutable, validated `FeatureCollection`. Its throwing
initializer and decoder enforce the same rules. `data()` serializes it and
`dump(to:)` atomically writes it to a URL. The SwiftUI `GeoJSONFile` adapter
uses this class for the export save panel.

- Exactly one `enemy_path` feature contains the union of every road and paint
  stroke (and any imported flattened area). Overlaps are merged; roads and paint
  are not emitted as separate features. Display visibility does not omit roads.
- A connected area uses `Polygon`; disconnected regions use one `MultiPolygon`
  geometry in that same feature. Holes remain holes. No artificial connecting
  segments are inserted. Curves are approximated to 0.25 canonical units.
- At least one explicit `spawn_point` and one explicit `goal_point` are required.
  The exporter never invents them from road endpoints. Entrance/exit features
  reference the flattened area with `pathIndex: 0`. Wave lines in imported
  flattened maps retain their incoming gameplay route indices (zero-based,
  bounded by the entrance count), including after painting or erasing the area.
  The wave inspector lets you select those routes. Exporting legacy native roads
  still flattens their wave references to route 0 without modifying the draft.
- Wave objects preserve optional `callButtonDelay`, `autoStartCountdown`, and
  `earlyCallBonus` through native saves and GeoJSON imports/exports. Supply all
  three together, with nonnegative values. Interactive timing measures delay
  plus countdown from the previous wave's actual start. The legacy `breather`
  measures time after the previous wave's last spawn instead. Charleston's
  generator authors both schedules consistently; see [wave plan](charleston_waves.md).
- Use the **Primary hero (1)** and **Secondary hero (2)** person tools to place
  starting positions anywhere on the map. Clicking again moves that role's single
  start. Placing primary enables at least one hero; placing secondary enables two.
  The yellow **1** and cyan **2** map badges point to the exact starting coordinates.
  Drag a badge, nudge it with arrow keys, or select it to edit X/Y in the inspector.
  Both tools automatically show the **Hero Starts** layer; hiding it does not omit
  the saved starts. The badges stay readable at every zoom and separate when starts
  overlap. Placement, moves and removal support undo/redo.
  Native files preserve `primaryHeroPosition` and `secondaryHeroPosition`.
  GeoJSON writes one `hero_spawn` Point per authored role, with `heroRoles` containing
  exactly that role and no `pathIndex`. Gameplay starts and respawns at these exact
  coordinates, including off-road points. Re-export the level and include that
  GeoJSON in the game bundle to use the new starts in gameplay.
- **Available heroes** can still be set to 0, 1, or 2 in the **Heroes** inspector.
  Disabled roles retain their draft positions but are not displayed or exported.
  **Remove** (or Delete on a selected hero badge) removes its starting point.
  Export requires an explicit starting point for every available role, written
  as a `hero_spawn` feature with `heroRoles: ["primary"]` or `["secondary"]`.
  Primary means the higher-ranked chosen hero; the map never stores hero IDs.
  Moving or deleting exits has no effect on hero starts. Missing points are
  reported as validation errors; neither the editor nor game invents positions.
  Importing an older native file or GeoJSON copies each explicitly assigned
  exit's coordinates into an independent hero start once. This compatibility
  conversion exists only in the editor; the game requires `hero_spawn` features.
- Place call-wave buttons with the megaphone tool or **Add Call Wave Button** in
  the inspector. Drag them, nudge with the arrow keys, or select one and enter
  exact X/Y coordinates. The **Call Wave Buttons** layer is above occlusion and
  menu previews. Its visibility is an editing aid and does not omit exports.
- Each center exports as a `call_wave_button` Point with `layer: 100` and no
  single `pathIndex`. Its optional `pathIndices` array identifies gameplay routes
  that use the button. Only buttons matching the **upcoming** wave's spawn routes
  appear; one control can serve multiple routes sharing an entrance. A missing
  `pathIndices` means a level-wide button shown for every wave. Select a button
  and use **Show for** in the inspector to set its routes (displayed from 1;
  stored from 0). This controls visibility independently of its exact X/Y center.
  Native files store centers and route assignments in `draft.callWaveButtons`.
  Old files without buttons still open, but export requires
  at least one explicit button so the player can start the first wave.
- The class checks finite 2D coordinates, closed nondegenerate rings, geometry
  types, unique matching IDs, contiguous slot numbering, canvas/play-area
  dimensions, level settings, wave timing/counts and path references.
- Coordinates retain the game's local Cartesian convention: lower-left origin,
  positive Y up. The format is not WGS84 longitude/latitude.

GeoJSON imports support both legacy centerline files and version 2. A legacy
import retains separate editable roads; a version 2 import has one flattened
area that can be painted and erased. Flattening does not preserve navigational
waypoints: use the native document for route editing and playtesting.

**Consumer compatibility:** the existing `sync_level_*_sql.py` scripts in the
asset workspace consume legacy `LineString` routes. Version 2 area exports are
not input to those scripts; a downstream area-to-route conversion is needed
before importing them into the game's waypoint database.

**Road artwork is a separate export.** Updating GeoJSON does not update the
game's `Levels/<map>_path.png`. The asset workspace's
`Tools/render_level_path_image.py` supports version-2 Polygon/MultiPolygon
areas with holes, as well as legacy centerlines and paint/erase strokes. Supply
the painted material separately so the exported geometry determines the exact
road footprint. For Charleston, from the workspace root:

```sh
python3 in-defense-of-history-data/Tools/render_level_path_image.py 15 \
  in-defense-of-history/Db/level_15_charleston.geojson \
  in-defense-of-history-data/Levels/level_15_charleston_path.png \
  --material 'in-defense-of-history-data/Images/Level Maps/15/Path Revisions/2026-09-10-geojson/painted-soil-material.png' \
  --feather 4
```

The exporter writes a `.render.json` record with source, geometry, material and
output hashes. Use the authoritative `Db` GeoJSON, review the minimum-size
result, then rebuild and install the game; an already installed app retains
its bundled image. A flat editor tracing fill will differ in material from the
painted game road, but their outlines must agree.

**Tower slots are exclusively GeoJSON data.** `LevelGeoJSONDAO.getTowerSlots`
loads their exact coordinates in `slotIndex` order (or legacy `slotNumber`
order). `LevelLoader` is the shared gameplay and balancing entry point; it
combines those slots with database metadata, routes and waves. `LevelInfoDAO`
returns metadata only. There is no SQLite tower-slot DAO, table, seed data or
fallback. Missing or malformed GeoJSON fails loading; an explicitly empty slot
list remains empty. Re-export and rebuild/install to update the bundled map.
Native editor drafts still hold their editable slot positions before export.
The command-line balancing tool reads the checkout’s `Db` GeoJSON directory;
set `LIBERTY_LINE_GEOJSON_DIRECTORY` when running with exports elsewhere.

`TowerSlotLoadingTests` checks all bundled maps, stable ordering and identity,
invalid input, missing files, and re-exporting through the actual shared loader
with no SQL slot table. Physical-iPhone evidence for this migration is in
`reports/tower-slots-geojson-2026-09-10`.

The game reads button centers directly from the bundled GeoJSON through
`LevelGeoJSONDAO`. `CallWaveButtonLayout` projects canonical coordinates through
`RuntimeCanvas` and resolves size through the shared `HudScale`/`HudSizing`
rules (44-point minimum). It never shifts authored centers to avoid other UI.
`CallWaveButtonView` renders that layout; `CallWaveButtonLayer` is the last,
explicitly raised layer in `LevelMapView`, above HUD, menus and map art. Buttons
retain double-tap activation and the existing database-driven countdown/bonus.
All fifteen bundled GeoJSON maps include editable centers associated with their
incoming routes. Charleston starts with only its path-0 button; later waves
show only their incoming route buttons. Missing centers produce a level-loading error instead of an
unstartable first wave or an invented runtime position. Hero roles and capacity
are also read at each level load; see [hero start configuration](hero_exit_spawns.md).

## Verification

For every editor change, run `Tools/check_level_editor.sh`. This runs the fixed
editor regression fixtures, including 28 eraser unit/integration tests, keyboard
movement, document lifecycle, GeoJSON, hero starts and call-wave markers. Run it
from a normal macOS session because the keyboard tests use hidden AppKit windows.
It neither opens user maps nor changes the database.

`EditorEraserTests` checks the visible circular footprint across brush sizes,
wide road edges, painted dabs, sparse drags, imported holes/islands, repeated
erasing, repainting, malformed input and persistence. `EditorEraserIntegrationTests`
drives the same `EditorPaintGesture` used by the canvas through coordinate
conversion, preview, release, cancellation, document edits, undo/redo, and real
native/GeoJSON file round trips. It also verifies that towers, hero starts,
markers, embedded images and wave assignments survive erasing. These are host
integration tests; they do not automate OS mouse/touch dispatch or the live UI.

Run `swift test` from the app repository. The Swift package compiles the actual
editor format code and shared engine types without launching the app or opening
the user's database. Tests cover validation, decoding, file output, road/paint
union, disconnected regions, holes/islands, erasing imported area, legacy
imports, native data/image preservation and native format migration.

Build the editor with:

```sh
xcodebuild -project InDefenseOfHistory.xcodeproj -scheme LevelEditor \
  -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```
