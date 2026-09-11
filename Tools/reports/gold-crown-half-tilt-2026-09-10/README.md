# Crown half-tilt adjustment

The selected Gold Stamp now receives a centered perspective correction in `LevelExitMarkersView`: undo its approximate 20-degree clockwise roll, recover half the original face-normal tilt from 55 degrees to 27.5 degrees, then apply a 10-degree clockwise roll. The 25.6-point source frame, source PNGs and authored exit points are preserved. The revised view is less compressed and more upright.

The production iPhone build succeeded. [Build log](iphone-build.log) · [Asset preservation and native readability proof](../../../../in-defense-of-history-data/ArtReadability/reports/gold-crown-half-tilt-2026-09-10/README.md).

The isolated device check uses the production crown view and the compiled catalog from this build. It verifies all authored exits and renders normal and minimum-size gameplay without touching the user's game save. Completed device and installation results are recorded below.

- **PASS — physical iPhone:** all 26 authored exits across 15 levels preserve their source coordinates and 25.6-point minimum source frame. The production image loads from the compiled catalog. [Device results](exit-markers.json).
- **PASS — rendered geometry:** 52 checks at 1× and 3× match the corrected crown's expected alpha bounds; maximum error is 0.868 raster pixels. Six checks include expected clipping at authored viewport-edge positions. [Raster results](raster-checks.json).
- **PASS — familiar-agent visual review:** inspected minimum-size Battle Road, Trenton and Charleston captures at 604 × 340 points, plus the normal 852 × 393-point Charleston render. The cross and gold/red crown masses are easier to distinguish with less foreshortening. The snow/bridge and grass/path conditions retain those cues; troops can still partially overlap the crown, and authored edge exits remain clipped. This is not independent player recognition or user acceptance.
- **PASS — production installation and launch:** the updated app installed and launched on the connected iPhone. [Install receipt](install.json) · [Launch receipt](launch.json). No Simulator was used; the temporary verification app was removed.

Capture provenance: the minimum captures are correctly named. The normal capture named `level_01_battle_road-device@1x.png` shows Charleston (15-wave HUD), because the first requested map switch had not completed. It duplicates `level_15_charleston-device@1x.png`; this is one normal-size Charleston observation, not evidence for normal-size Battle Road. Minimum Battle Road and Trenton were identified visually before review.

[Minimum before/after proof](../../../../in-defense-of-history-data/ArtReadability/reports/gold-crown-half-tilt-2026-09-10/before-after-minimum.png). The approved catalog PNGs are unchanged; only the production view's perspective is corrected.
