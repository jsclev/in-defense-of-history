# Liberty Line Web

The browser port starts here. The web version opens **level 15 (Charleston)** and includes tower placement, radial menus and tower firing, alongside interactive HUD controls for heroes, reinforcements, waves and a shared battle clock. Phaser renders canonical artwork; SQLite supplies player settings, budgets, schedules, tower prices, unlocks and tuning. This remains a partial game port: remaining special abilities, GA playback and campaign progression still need porting. Fifteen maps have artwork, but existing wave-count inconsistencies currently prevent ten of those levels from starting. Empty map names explicitly identify campaign rows without a battlefield.

| Control | Current behavior |
| --- | --- |
| Hero portraits / on-map heroes | Select or deselect a deployed living hero; tap a reachable road point to issue a movement order. Manual orders disable AI for that attempt, matching iOS. Deployment count and exact starts come from GeoJSON. |
| Reinforcements | Arm/cancel placement; deploy on a valid route; show the authored cooldown only after successful placement. Militia form up, engage enemies and expire on the native schedule. |
| Wave horn | Tap to select an entrance, tap again to confirm. Later waves count down automatically; early calls award the authored bonus once. |
| Speed | Double the common battle speed, using the native clock limits. |
| Pause | Freeze the simulation; return, restart from the authored budget, open settings, or exit to battle selection. Browser hiding and Facebook host pause use the same paused state. |
| Settings / haptics | Write the same in-memory SQLite settings and hero-AI rows. Layout guides, simulation readout, debug border and life-loss vibration respond immediately where supported. The GA preference is stored, but GA playback is not ported. |
| Inventory | Flash on activation, matching the current iOS handler, which has no inventory action. |
| Empty tower slots | Use the same plain stone-ring artwork as iOS, with a transparent, left-facing iron-and-wood hammer cursor; open the five-choice radial menu. Select a kind to preview its authored description/range, then confirm the purchase. A different build choice clears the first selection, matching iOS. |
| Placed towers | Show a gold upward-arrow upgrade cursor and open tier/specialization/rank upgrades. Prices, meta discounts, unlocks, descriptions and upgrade effects come from the DAL; insufficient funds and maximum ranks follow native command behavior. |
| Placement flag | Move melee rally points, engineer abatis or sapper charge sites with the native circle/ellipse and nearest-road calculations. Melee garrisons update their formations. Engineers use road-clipped canonical brush artwork and slow enemies. New sapper charges start ready/unplaced; moving an existing site starts preparation. Planted charges automatically explode just before an enemy exits the circular blast area along its actual route, then begin preparation again. |

Enemies follow authored routes; heroes and militia can block, fight, heal, die and respawn. Lives, bounties and victory/defeat drive the live HUD. This supporting simulation does not yet reproduce the complete native combat engine. Main campaign currently opens a battle selector, not the native campaign map.

## Run and build

Requires Node 20.15+ and macOS with Xcode command-line tools, `sqlite3`, `lsof` and `sips`. The tests compile the actual Swift geometry with the normal `xcrun swiftc` to check web/native parity. The current HEIC conversion uses Apple's normal image tool; the resulting site runs on other platforms. `LibertyLineWeb` lives at the root of the code repository. Keep `in-defense-of-history-data` beside that repository.

```sh
cd /Users/john/projects/td/in-defense-of-history/LibertyLineWeb
npm ci
npm run dev
```

To serve the existing website build at **http://127.0.0.1:4174/**, run the launcher
from the code repository root:

```sh
./start_web_server.sh
```

The launcher calls `npm run preview -- --port 4174 --strictPort` inside
`LibertyLineWeb`. Keep the Terminal open; Ctrl-C stops the server. It fails if
the port is occupied instead of silently switching URLs. It serves the last
website build, so run `npm run build` in `LibertyLineWeb` after source/content
changes, or use `npm run dev` above for development.

| Command | Result |
| --- | --- |
| `npm run check` | Strict TypeScript checking, all unit tests and coverage gates |
| `npm run test:coverage` | Coverage with enforced 95% lines/functions and 85% branches |
| `npm run build` | Checked website build and `releases/website.zip` |
| `npm run build:facebook` | Checked Instant Games build and `releases/facebook.zip` |
| `npm run build:all` | Checks once, prepares content once, then packages both targets |
| `npm run preview` | Serves the website production build locally |

Extract the website ZIP on an ordinary static HTTPS host. Its relative URLs work in a subdirectory. Serve `.wasm` as `application/wasm`. Opening `index.html` with `file://` is not supported. Each archive has `index.html` at its root and contains its JavaScript, CSS, SQLite WASM, bundled seed database, GeoJSON and all packaged artwork. The Facebook archive also has `fbapp-config.json` and the platform bootstrap. No upload or publication is performed by these commands.

## One source of truth

| Source | Build use |
| --- | --- |
| `../../in-defense-of-history-data/LibertyLineAssets.xcassets` | Discover every canonical `.imageset` from its `Contents.json`; no hand-maintained web catalog |
| `../../in-defense-of-history-data/Web/favicon.png` | Washington portrait adapted from the iOS icon for tiny tabs; export matching 16/32/48-pixel PNGs and a multi-resolution ICO |
| `../../in-defense-of-history-data/Levels` | Package every PNG/HEIC resource and resolve SQLite map names with the existing layer naming convention |
| `../Db/*.geojson` | Copy authored geometry byte for byte |
| `../Db/create_db.sh`, `DDL`, `DML` | Run the original seed builder unchanged |
| `../GameName.xcconfig` | Read the existing game display name |
| Native `HeroSpriteProfile`, `UnitFacing`, `MapSpriteSizing`, `TowerKind`, `TowerMenuLayout`, `ArtilleryFacing` | Execute original Swift definitions to export pose/frame names, tower artwork mappings, menu dimensions/inset, touch targets, ground anchors, atlas dimensions and sprite/health sizes |
| Native `HeroMovementArea` and authored GeoJSON | Export the actual unioned road boundaries for browser navigation |

**There are no authored images, SQL copies, tuning catalogs or copied Swift files in this project.** `generated/`, `dist/` and `releases/` are disposable build products and are ignored. They contain the necessary deployment copies inside this directory, so the ZIP is self-contained without creating a second editable asset collection. Do not edit these outputs; edit the original source and rebuild.

Multi-density image sets use their 2x rendition. Single-density sets keep their sole 1x/unscaled image. Missing required densities fail the build. Catalog images use the smaller of original PNG and lossless WebP; HEIC map layers become lossless WebP after native decoding. Packaged pixels are never cropped, resized or lossily recompressed. The manifest also records nonzero-alpha bounds; menu rendering uses those bounds and the original image URL to match native `TowerMenuIcon` cropping and the one shared inset. No second menu-image file is created. The 43-pixel build and upgrade mouse cursors and clipped engineer textures are transient render products from canonical images. SHA-256 filenames deduplicate identical encoded bytes, while the generated manifest retains canonical names, source paths and source/output hashes. Native app icons and colorsets are excluded. The native `Levels` resource folder is mirrored, including shared terrain and its existing auxiliary images; historical art and reviews outside those two native resource locations are excluded. Each canonical animation frame is included even before its gameplay is ported. The browser loads only the selected battlefield's textures initially.

The working native database contains large simulator histories. The web builder **never opens or changes it**. Instead, it makes a temporary directory with symlinks to the original `create_db.sh`, `DDL` and `DML`, executes that same script there, and packages its fresh SQLite result. This reuses the one generation implementation and exact authored player seeds. It does not derive gameplay content from simulator records or introduce a second database-generation algorithm. Native build scripts and Xcode settings are unchanged.

Every browser launch opens a fresh in-memory database from bundled bytes. SQLite DAOs validate required rows and fields and report content errors. There is no localStorage, IndexedDB, UserDefaults import, cloud save merge, or Facebook player-data restore. Starting money comes from `level_info.starting_money`. Build and archive errors fail the command. ZIP verification reads back every entry and checks its bytes and all manifest references.

## Web data access

`src/data/contracts.ts` defines the asynchronous `GameDataAccess` interface. Content reads and the two player-settings write operations use the same adapter. The app receives an `openData` dependency; only the bootstrap chooses `loadSqliteData` and initializes SQLite WASM. The current adapter downloads the bundled database with `cache: 'no-store'`, copies its bytes into an independent in-memory connection, checks integrity and foreign keys, decodes all game-content tables, validates required catalogs/player state, and closes the connection on a failed load. Calling `close()` releases it and is safe to repeat.

The database uses the same schema and authored SQL as iOS. There is no web database schema, secondary content catalog, hardcoded money or tuning, or persistent player-state overlay. `src/data/records.ts` defines typed validation contracts corresponding to native `AuthoredRow` and the Swift DAOs. JSON traits, upgrade effects, tower layouts and grapeshot angles are decoded into typed values. All other column names are preserved. Validation errors identify the table, record and field; disabled capabilities and nullable fields must be explicitly authored. Returned objects are detached values, so changing them cannot mutate the database.

| DAL entry point | Returned content |
| --- | --- |
| `campaigns.getAll()` / `get(id)` | Campaign metadata and parent relationships |
| `levels.getAll()` / `get(id)` / `getForCampaign(id)` | Complete level metadata with campaign names and authored starting budgets |
| `towers.getAll()` | Types and level/branch layouts; every tier's tuning/capabilities, history, optional melee stats, upgrade paths and ranks |
| `enemies.getAll()` | Enemy stats, morale responses, decoded traits, artwork keys and encyclopedia content |
| `heroes.getAll()` | Hero descriptions/artwork, combat stats, AI settings, controls, unlock wave and current unlock status |
| `waves.getForLevel(id)` / `get(id, waveNumber)` | Ordered waves and spawns; cumulative delays count each simultaneous spawn group once, matching native `WaveDAO`. Entering a battle requires its complete validated wave catalog. |
| `paths.getForLevel(id)` | Ordered SQLite path points in canonical map coordinates |
| `unlocks.getForLevel(id)` | Explicit maximum level for every tower kind, including authored zero/locked values |
| `levelHeroes.getForLevel(id)` | Authored SQLite hero/path associations |
| `configuration.get()` | Full virtual canvas/HUD dimensions, combat rules, reinforcement settings, all play speeds/difficulties and encyclopedia demo settings |
| `metaUpgrades.get()` | Tracks, prerequisites, costs, descriptions, icons and authored effect parameters |
| `player.get()` | Settings, selected difficulty/heroes, unlocked heroes, AI controls, HUD layout and active meta-upgrade state |
| `player.getMetaUpgrades('active' \| 'level15')` | Complete selections and level-star ledger, with earned/spent/available stars |
| `player.setSetting(key, enabled)` / `setHeroAI(id, enabled)` | Transactional updates to existing required player rows; validate the resulting state and roll back on failure. Changes last only for this page launch. |

For example, a caller with a `GameDataAccess` instance can use:

```ts
const levels = await data.levels.getAll();
const arsenal = await data.towers.getAll();
const player = await data.player.get();
const config = await data.configuration.get();
// When entering a level, validate/load its actual wave content:
const waves = await data.waves.getForLevel(levelId);
```

Some existing campaign rows have `num_waves` values that disagree with their authored wave rows (including Great Bridge: 10 declared, 8 present when this DAL was added). Entering an inconsistent level stops with the level identity and `num_waves` diagnostic. The DAL neither fills missing waves nor changes shared SQL to conceal those inconsistencies. Startup checks row validity, required catalogs and player state; level-specific completeness is checked when that data is requested.

The battle assembler follows native `LevelLoader` precedence: explicit GeoJSON routes and hero deployment geometry take priority; legacy maps use SQLite routes. Invalid starts, route references and malformed required data fail. Tower purchases are battle-session commands against DAO content and do not persist across attempts. Simulator studies, recordings and replay storage are outside this DAL milestone.

A later backend adapter can implement `GameDataAccess` through an HTTP API backed by PostgreSQL without exposing database connections or SQL to browser callers. PostgreSQL, server endpoints and player-state persistence are not implemented in this version.

## Code boundaries and further work

The whole browser viewport acts as the native physical screen. The play rectangle is fitted uniformly and centered inside browser safe-area insets, using `virtual_canvas` from the shared SQLite database (currently 1920 × 1080, or 16:9). The full 2868 × 2064 illustration extends outside that play rectangle and is clipped only at the physical viewport, matching native `RuntimeCanvas` / `LevelMapProjection`. Preview controls and status are overlays, so their size never changes the map's scale or center. Resizing recalculates the same projection for art and slots without restarting the level. There is no separate web aspect-ratio constant or device-specific layout catalog.

- `src/data`: asynchronous game DAL contract, typed record validation, and SQLite DAO implementation for all current game-content/player-state tables.
- `src/content`: low-level SQLite ownership and shared row decoding, plus strict manifest and GeoJSON readers. Gameplay/browser consumers use the DAL contract.
- `src/game`: coordinate projection, level assembly, navigation, fixed-tick battle sessions, unit state machines and a thin Phaser renderer. Simulation is independent of Phaser; commands, schedules and results can be tested without a browser. Both hosts use this one implementation.
- `src/hud`: native corner reservations, fixed-template stats, square button rows, canonical image composition, cooldown/selection states, authored wave markers, menus and debug guides. The accessible DOM overlay uses the same physical viewport and projection as Phaser; it never controls map layout. `HudState` and input callbacks mirror native `LevelHUDState`/`LevelHUDInput` and receive live session state. Rendering preserves button identity and keyboard focus across ticks.
- `src/platform`: one small lifecycle adapter. Both hosts run exactly the same app and game code. Facebook initializes first, receives loading progress, then starts after required textures are ready. SDK errors are surfaced, not converted into website mode.
- `tools`: discover/encode shared art, call the original seed builder, configure Vite, and verify ZIP packages.
- `tests`: real authored SQL through the original builder; DAO reads and in-memory mutations; required-field coverage against SQLite's actual schema; map geometry/placement; rendering contract; browser bootstrap; host lifecycle; asset discovery/encoding; and archive integrity. No handwritten copy of production SQL is used as a test fixture. GPU drawing and real Meta acceptance still require browser/device testing.

Port next in small tested increments: the remaining combat and special-ability systems, then campaign progression and replay. Reuse existing authored content and shared behavioral fixtures for Swift/TypeScript parity, instead of maintaining separate tuning or scenario catalogs. Do not replace or relocate the Swift engine as part of this foundation.

This folder is part of the code repository alongside `Engine`, `Db` and the native app. Its source and tests belong in the same Git repository; dependencies and generated deployment products remain ignored. Shared artwork stays in the external data repository.

## Battle state and input

`BattleStore` wraps the single `BattleSession`; it does not copy game state. All
HUD, tower, map, settings and host-lifecycle actions dispatch typed commands.
Completed commands and simulation ticks notify subscribers synchronously. The
Phaser scene handles `battle-state-changed` to update the HUD, cursor and world
hit targets together. Only Phaser's frame update advances the fixed game clock;
clicks, resize and rendering cannot advance it. Cooldown availability still uses
the native tick schedule and authored SQLite values, with no separate UI timer.

The DOM stack is canvas, world targets, tower menu, then HUD. Persistent HUD
controls also outrank wave markers. Decorative cooldown layers do not receive
pointer input. `overflow: clip` prevents browser focus from scrolling the game
coordinate space. Interactive button nodes stay attached across refreshes, and
canvas gestures must both start and finish on the canvas. Scene shutdown removes
the store subscription and pointer handlers. Regression tests exercise cooldown
completion, immediate cross-surface updates, paused input, held clicks, resize,
tower affordability changes and shutdown.

## HUD parity and layout guides

`src/hud/layout.ts` ports `HudPlayArea`, `VirtualCanvas`, `HudButtonRowLayout`, `HudStatsView` and `CallWaveButtonLayout`. Database fractions define four fixed corner reservations; `player_hud_layout` assigns each HUD group to one corner. The 2% margins, 90% reservation height, row spacing, fitted stats template, frame rim normalization, portrait outline and icon insets follow the native views. Values, selected portraits and debug-guide visibility come through the DAL. No CSS breakpoint or minimum button override alters those calculations.

The normal checks compile original native sources into temporary host-side reference executables. They compare corner frames, all button rows, wave geometry, tower button/seat centers, slot touch targets, label avoidance/scrolling and point membership in the path/tap/slot guide regions across 12 viewport/content scenarios. The menu and slot-guide clearance consume the same exported Swift geometry. Additional parity checks compare native road containment/routes, wave confirmation/countdowns and reinforcement schedules. SQL mutation tests prove that HUD locations, dimensions, budgets, portraits, settings and tower/unit tuning propagate, and missing required content fails. The seven debug guides follow the same colors, dashes and cutouts; visibility starts from `player_settings.show_debug_layout_guides`.

Tower artwork uses the native height clamps, foot anchoring and artillery atlas frame calculation. Sapper artwork uses projected slot width and the native readiness pulse. The radial menu is anchored on the authored slot, with no web-only repositioning. Descriptions use measured browser text with the native 20/17-point type sizes, safe inset, obstacle clearance and scrolling policy. Browser font metrics can differ from UIKit. Existing Battle Road edge slots can place menu controls outside a short landscape viewport (observed at 605 × 340, including slot 2); matching geometry does not fix invalid authored placement. Correct that through shared GeoJSON/layout rules, not browser-specific offsets.

Exact parity also preserves native limits: at a 360-pixel portrait viewport, the 16:9 play area is 202.5 pixels high, hero buttons are about 29 pixels and counter text about 9 pixels. Authored wave centers are never nudged; the minimum 44-pixel horn can extend past a narrow viewport. These dimensions are verified geometry, not a claim of comfortable portrait play. A future sizing change should address both platforms through their common layout rules.

The HUD reuses every portrait/frame/icon from the existing asset manifest. No artwork, SQL or GeoJSON is copied into web source. Browser font rendering uses the platform rounded system font; glyph rasterization can differ from iOS. The haptic toggle uses a simple inline phone symbol corresponding to the native system icon. Menu markup and keyboard focus handling are web presentation code.

## Engine and platform research — September 26, 2026

Phaser is a good fit for this sprite-based 2D game: it provides rendering, scenes, loading, input and scaling for desktop/mobile browsers, with TypeScript definitions and WebGL/Canvas support. This project pins **Phaser 4.2.1**, the current published release verified for this work. See [Phaser's scope](https://docs.phaser.io/phaser/getting-started/what-is-phaser) and the [4.2.1 release](https://phaser.io/download/release/v4.2.1).

Phaser's older [Instant Games tutorial](https://phaser.io/tutorials/getting-started-facebook-instant-games) targets SDK 6.2. The new project uses its own small adapter for **SDK 8.0**, consistent with [Meta's current official plugin](https://github.com/facebook/meta-instant-games-unity-plugin) and [HTML bootstrap](https://github.com/facebook/meta-instant-games-unity-plugin/blob/main/Assets/WebGLTemplates/FB/index.html). The engine does not depend on the older Phaser Facebook plugin.

Meta's official tooling describes building, zipping and uploading a WebGL bundle. Its [configuration template](https://github.com/facebook/meta-instant-games-unity-plugin/blob/main/Assets/WebGLTemplates/FB/fbapp-config.json) uses `RICH_GAMEPLAY` and `NAV_FLOATING`. The Facebook SDK remains an external script, as required by the platform integration; all **game artwork** and game code are bundled. The website target has no Facebook dependency.

The adapter also connects the host pause callback described in Meta's [official API reference](https://github.com/facebook/meta-instant-games-unity-plugin/blob/main/documentation/API_REFERENCE.md). Host callbacks are unit-tested with an SDK test double; a real Facebook session remains unverified.

Meta's main developer documentation was inaccessible during research. Current app eligibility, upload/initial-load limits and review requirements remain to be checked in the actual app dashboard. These local archives are development builds, not proof of Meta acceptance. Full-catalog packaging and lossless maps are deliberately conservative about art fidelity; measure startup, memory, bundle limits and real mobile performance before release. Native Xcode compilation and physical-iPhone gameplay are outside this web milestone.

### Tower combat

`src/game/combat.ts` follows `BattleEngine.updateCombat` and `updateProjectiles`:
elliptical targeting at enemy feet, body-offset aim, continuous artillery tracking,
fixed tick reload, direct homing shots, fixed-destination shells, swept grapeshot
(one hit per enemy per volley), and penetrating solid shot (one hit per enemy per
ball). Blast damage uses circular body distance and authored cover piercing;
falloff applies to morale, not HP damage. Launched shots retain their original
stats across purchases. Kill rewards, strongest-only supply speed/healing,
selected meta upgrades, engineer fire lanes and rank reload rescaling share the
same battle clock. Morale integrates delayed recovery and speed-threshold crossings.

Projectiles use the original iOS art and build-time exported native sprite heights.
Artillery uses its live heading for the existing directional atlas. Impact effects,
explosion frame blending, body flinch and the continuous cyan morale arc reproduce
the native view calculations, including the browser's reduced-motion preference.
No new artwork copies or tuning catalogs are authored in the web folder.

The web unit suite invokes the normal SwiftPM `WebCombatReferenceTests/testExport`
test in a disposable system-temporary build directory to compare combat math
against the original engine helpers. That reference test skips when run without
the web suite's input/output environment variables. Unit tests also exercise real
purchases, firing, damage, cooldowns, pause, batched ticks and rendering geometry.
