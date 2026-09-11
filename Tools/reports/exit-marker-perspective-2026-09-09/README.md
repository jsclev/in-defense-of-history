The exit X is now foreshortened vertically in `LevelExitMarkersView` with
`TowerRangeOverlay.verticalFraction` (0.7), matching the existing ground-plane
range rings. Its source artwork, horizontal size, draw order, and authored center
are unchanged. The minimum 32-point source box renders 32 × 22.4 points.

The old marker read clearly as an X but was presented face-on. Small-size
recognition alone did not verify its placement in the map's perspective.
The corrected view keeps four distinct arms and a broad red shape while laying
it on the ground plane. Familiar-agent visual review passed at minimum size on
grass, woodland/river, and snow, in color, grayscale, silhouette, and three values.
The existing art lab generated `lab/roster-minimum.png` and hashed its diagnostic
inputs; `diagnostic-renders` approximates the view transform without editing any
production PNG. Browser checks used 2× and 3× exports with nearby troops.

A separate probe app built and ran on the physical iPhone. It checked 26 authored
exits across all 15 levels and saved actual SwiftUI marker layers and gameplay
captures at 1× and 3×. All 52 raster bounds checks passed within two pixels,
including the shared 0.7 vertical ratio. Existing viewport clipping at manually
authored points was not changed by this rendering-only correction.

`comparison-minimum.png` uses unscaled crops from actual iPhone 1× captures
before and after the change. See `review.json`, `exit-markers.json`, and
`raster-checks.json` for evidence. Independent human recognition is not measured.
