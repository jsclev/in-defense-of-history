# Hero movement model and regression coverage

Hero movement now loads the authored `enemy_path` area from GeoJSON through `LevelGeoJSONDAO.getHeroMovementArea`. Polygon/MultiPolygon boundaries and holes are authoritative. Legacy LineStrings use their own `widthPx`, with the virtual canvas path width only when the export omits it. Database enemy waypoints, sprite dimensions and HUD rectangles do not decide where a hero can walk.

`Engine/Models/HeroMovementArea.swift` owns containment and routing. Routes validate every complete segment, preserve disconnected regions, and finish at the requested point. A cached grid accelerates routing; boundary visibility handles narrow passages without making grid spacing a movement restriction.

`Engine/Models/HeroMovement.swift` owns orders, route progress, exact arrival and respawning using the real `MilitiaUnit` and `MilitiaAI`. `LevelRunner` invokes it for player orders, combat pursuit and return movement. Invalid/outside/unreachable commands preserve the current order. The old sampled-node graph and its empty-route stall are removed.

`HeroMapLayer` owns hero rendering. `HeroDestinationView` and `MapDestinationInputView` own input delivery, using the tested `MapDestinationInput` projection and delegating movement to the model. The existing hero sprite presentation is preserved.

Eight existing hero starts were outside their road widths. Their GeoJSON coordinates were moved to one map unit inside the nearest road edge. Exact before/after coordinates are recorded in [spawn-corrections.json](spawn-corrections.json). The model preserves valid authored starts and rejects invalid ones instead of silently relocating heroes at runtime.

## Run the movement checks

From the project directory:

```sh
swift test --filter HeroMovement
# Or save results and source/data hashes:
python3 Tools/check_hero_movement.py --output Tools/reports/hero-movement
```

The script runs the actual Swift test targets. It no longer extracts or copies the runner's movement implementation into a generated harness.

## Verification

- **13 new tests passed**: eight focused model regressions and five integrations, with no SwiftUI/UIKit test dependency.
- The campaign integrations load **all 15 shipped GeoJSON files**, traverse all **33 legacy roads**, walk across lane widths, test **25 authored hero starts** and respawns, and visit destinations throughout Charleston's polygon while rejecting holes/outside points.
- Tests cover exact nearby destinations (including less than two map units), commands during a step, invalid/dead/unreachable commands, combat pursuit/return, thin holes, narrow bent passages, reexported geometry and RuntimeCanvas projection/resizing.
- **iPhone Debug build succeeded**, using `generic/platform=iOS`; no Simulator was launched.
- The existing portrait-selection probe passed after being updated to use the new movement model.
- Full existing suite: **179 test cases; 177 passed, two failed with 46 assertions**. Both failing cases are in `CharlestonWaveTests`: `testDatabaseRoutesSpawnsAndAutomaticStartsMatchAuthoredWaves` and `testEditorPreservesBothRoutesAndAllWaveTiming`. They compare the current polygon export's endpoints/wave indices against older database routes or require both indices `[0, 1]` where the export uses `[0]`. These cases and the Charleston GeoJSON/native/database files were not modified by this work. Details are in [full-suite.log](full-suite.log). Existing keyboard tests pass in the normal macOS window session.

See [tests.log](tests.log), [results.json](results.json), [iphone-build.log](iphone-build.log), and [selection-check.json](selection-check.json). This verification proves model movement and app compilation; physical iPhone touch delivery was not exercised.
