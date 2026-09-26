# Liberty Line Web

The browser port starts here. The current milestone is a working **battlefield preview**: choose among the 15 maps with authored art, load their SQLite metadata, and render the existing terrain, overlays, occlusion and tower slots in Phaser. Combat, tower purchases/upgrades, heroes, waves, progression and the gameplay HUD are **not implemented yet**. The campaign's other rows remain in SQLite; rows explicitly authored with an empty map name have no preview.

## Run and build

Requires Node 20.15+ and macOS with `sqlite3`, `lsof` and `sips`. The current HEIC conversion uses Apple's normal image tool; the resulting site runs on other platforms. `LibertyLineWeb` lives at the root of the code repository. Keep `in-defense-of-history-data` beside that repository.

```sh
cd /Users/john/projects/td/in-defense-of-history/LibertyLineWeb
npm ci
npm run dev
```

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
| `../../in-defense-of-history-data/Levels` | Package every PNG/HEIC resource and resolve SQLite map names with the existing layer naming convention |
| `../Db/*.geojson` | Copy authored geometry byte for byte |
| `../Db/create_db.sh`, `DDL`, `DML` | Run the original seed builder unchanged |
| `../GameName.xcconfig` | Read the existing game display name |

**There are no authored images, SQL copies, tuning catalogs or copied Swift files in this project.** `generated/`, `dist/` and `releases/` are disposable build products and are ignored. They contain the necessary deployment copies inside this directory, so the ZIP is self-contained without creating a second editable asset collection. Do not edit these outputs; edit the original source and rebuild.

Multi-density image sets use their 2x rendition. Single-density sets keep their sole 1x/unscaled image. Missing required densities fail the build. Catalog images use the smaller of original PNG and lossless WebP; HEIC map layers become lossless WebP after native decoding. No cropping, resizing, alternate artwork, or lossy recompression is performed. SHA-256 filenames deduplicate identical encoded bytes, while the generated manifest retains canonical names, source paths and source/output hashes. Native app icons and colorsets are excluded. The native `Levels` resource folder is mirrored, including shared terrain and its existing auxiliary images; historical art and reviews outside those two native resource locations are excluded. Each canonical animation frame is included even before its gameplay is ported. The browser loads only the selected battlefield's textures initially.

The working native database contains large simulator histories. The web builder **never opens or changes it**. Instead, it makes a temporary directory with symlinks to the original `create_db.sh`, `DDL` and `DML`, executes that same script there, and packages its fresh SQLite result. This reuses the one generation implementation and exact authored player seeds. It does not derive gameplay content from simulator records or introduce a second database-generation algorithm. Native build scripts and Xcode settings are unchanged.

Every browser launch opens a fresh in-memory database from bundled bytes. SQLite DAOs validate required rows and fields and report content errors. There is no localStorage, IndexedDB, UserDefaults import, cloud save merge, or Facebook player-data restore. Starting money comes from `level_info.starting_money`. Build and archive errors fail the command. ZIP verification reads back every entry and checks its bytes and all manifest references.

## Code boundaries and further work

The whole browser viewport acts as the native physical screen. The play rectangle is fitted uniformly and centered inside browser safe-area insets, using `virtual_canvas` from the shared SQLite database (currently 1920 × 1080, or 16:9). The full 2868 × 2064 illustration extends outside that play rectangle and is clipped only at the physical viewport, matching native `RuntimeCanvas` / `LevelMapProjection`. Preview controls and status are overlays, so their size never changes the map's scale or center. Resizing recalculates the same projection for art and slots without restarting the level. There is no separate web aspect-ratio constant or device-specific layout catalog.

- `src/content`: SQLite ownership/DAOs, strict manifest and GeoJSON readers. Add further DAOs as their systems are ported; never insert gameplay defaults into TypeScript.
- `src/game`: coordinate projection, a renderer-independent display plan, and a thin Phaser renderer. The unavoidable coordinate port references its Swift counterpart. Keep the future battle simulation independent of Phaser so deterministic unit tests can exercise commands, ticks and results.
- `src/platform`: one small lifecycle adapter. Both hosts run exactly the same app and game code. Facebook initializes first, receives loading progress, then starts after required textures are ready. SDK errors are surfaced, not converted into website mode.
- `tools`: discover/encode shared art, call the original seed builder, configure Vite, and verify ZIP packages.
- `tests`: real authored SQL through the original builder, in-memory mutation tests, map geometry/placement, rendering contract, browser bootstrap, host lifecycle, asset discovery/encoding, and archive integrity. No handwritten copy of the production SQL is used as a test fixture. GPU drawing and real Meta acceptance still require browser/device testing.

Port next in small tested increments: wave/path/enemy DAOs and deterministic movement; tower commands and combat rules; hero/reinforcement systems; then the gameplay HUD and campaign flow. Reuse existing authored content and shared behavioral fixtures for Swift/TypeScript parity, instead of maintaining separate tuning or scenario catalogs. Do not replace or relocate the Swift engine as part of this foundation.

This folder is part of the code repository alongside `Engine`, `Db` and the native app. Its source and tests belong in the same Git repository; dependencies and generated deployment products remain ignored. Shared artwork stays in the external data repository.

## Engine and platform research — September 26, 2026

Phaser is a good fit for this sprite-based 2D game: it provides rendering, scenes, loading, input and scaling for desktop/mobile browsers, with TypeScript definitions and WebGL/Canvas support. This project pins **Phaser 4.2.1**, the current published release verified for this work. See [Phaser's scope](https://docs.phaser.io/phaser/getting-started/what-is-phaser) and the [4.2.1 release](https://phaser.io/download/release/v4.2.1).

Phaser's older [Instant Games tutorial](https://phaser.io/tutorials/getting-started-facebook-instant-games) targets SDK 6.2. The new project uses its own small adapter for **SDK 8.0**, consistent with [Meta's current official plugin](https://github.com/facebook/meta-instant-games-unity-plugin) and [HTML bootstrap](https://github.com/facebook/meta-instant-games-unity-plugin/blob/main/Assets/WebGLTemplates/FB/index.html). The engine does not depend on the older Phaser Facebook plugin.

Meta's official tooling describes building, zipping and uploading a WebGL bundle. Its [configuration template](https://github.com/facebook/meta-instant-games-unity-plugin/blob/main/Assets/WebGLTemplates/FB/fbapp-config.json) uses `RICH_GAMEPLAY` and `NAV_FLOATING`. The Facebook SDK remains an external script, as required by the platform integration; all **game artwork** and game code are bundled. The website target has no Facebook dependency.

Meta's main developer documentation was inaccessible during research. Current app eligibility, upload/initial-load limits and review requirements remain to be checked in the actual app dashboard. These local archives are development builds, not proof of Meta acceptance. Full-catalog packaging and lossless maps are deliberately conservative about art fidelity; measure startup, memory, bundle limits and real mobile performance before release. Native Xcode compilation, physical-iPhone gameplay and a real Facebook session are outside this first web milestone.
