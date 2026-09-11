# GeoJSON exit markers — 2026-09-09

The approved rounded red X is installed in `LibertyLineAssets.xcassets/path_exit_rounded_x.imageset`. `LevelRunner` loads every `goal_point` through the existing GeoJSON DAO. `LevelExitMarkersView` projects each canonical coordinate through the same `LevelMapProjection` as the map. It does not filter by hero assignment, snap positions, or intercept touches. The 26 features across 15 levels include coincident exits in New Haven; coincident features intentionally overlap.

The marker layer immediately follows `art.occlusion`, the final map-art layer, in `LevelMapView`. An initial physical-device capture showed that placing markers above only the base map let endpoint foliage obscure Battle Road's exit. The corrected capture shows the X above that foliage. The initial evidence is retained in `initial-under-foliage/`.

The minimum source box is 32 × 32 points at playable height 340. A concurrent view edit added the existing ground-plane vertical fraction of 0.7, producing a 32 × 22.4-point box without changing its center or width. That edit was preserved in the final build installed and launched on John's iPhone 15 Pro.

## Verification

- `host-tests.log`: 17 existing host tests passed, covering exit configuration, wave buttons, and runtime canvas geometry.
- `device-build.log`, `install.log`, `launch.log`: final iPhone build succeeded, installed, and launched. No iOS Simulator was used.
- `exit-markers.json`: a temporary separate probe app ran production level loading and views on the physical iPhone. All 26 exit coordinates matched independently parsed bundled GeoJSON across all 15 levels.
- `raster-checks.json`: 52 marker bounds checks passed at 1× and 3× on physical-device SwiftUI captures, within two raster pixels of projected positions. This capture predates the concurrent 0.7 perspective edit and verifies the square version's placement and sizing.
- `device-documents/`: real map hierarchy captures for Battle Road, Trenton, and Charleston were inspected at native size after the layer correction. The `minimum` captures use a constructed 340-point-high canvas running on the physical phone; the `device` captures use its actual window size. These captures also predate the perspective edit.
- `lab/`: the existing readability lab was run with the shipping catalog exports and retained source PNG maps. Native-size familiar-agent shape checks passed. This lab proof displays the square source and does not model the view's later perspective transform.
- `ground-plane@1x.png`, `ground-plane@2x.png`, `ground-plane@3x.png`, `ground-plane-checks.json`: the final perspective-adjusted production view was rendered through macOS SwiftUI with only its image loader replaced by NSImage. At minimum size the visible body measures approximately 28–29.3 × 20 points and retains the four-arm X identity in the inspected 1× proof. This is host evidence, not a physical-iPhone capture of the final perspective.
- `asset-checks.json`: the approved catalog exports were preserved and the compiled asset was found in the app.

The familiar-agent small-size shape review is PASS. Independent player interpretation is NOT MEASURED. Physical-device re-capture of the final perspective adjustment is NOT MEASURED; the final version was built, installed, and launched successfully. Authored coordinates near viewport edges can be partially clipped at the smallest constructed layout; coordinates were preserved rather than moved away from the exits.

`review.json` records the scope of each result and current source hashes. Probe sources and scripts are archived here; they do not change the production app's entry point. `check_raster_bounds.py` checks the archived square captures and must be adjusted for a new capture using the perspective transform.
