# Cropped crown with flat contrast outline

The unoutlined crown blended into the path. The final image preserves the approved gold/red face and reduced angle, adds a symmetric dark plum contour, and is cropped to its artwork. `LevelExitMarkersView` now displays that baked asset directly using crop-aware dimensions and anchor offsets. The temporary runtime color shader and transform chain have been removed.

- Production physical-iPhone build: **PASS**, [build log](iphone-build.log).
- Compiled cropped canvas: **PASS**, 89 × 92 logical pixels, checked by the device probe. [Catalog hash](compiled-catalog.json).
- Authored exit positions: **PASS**, 26 exits across all 15 maps. [Device results](exit-markers.json).
- Actual rendered bounds: **PASS**, 78 checks at 1×, 2× and 3×, within two raster pixels. [Results](raster-checks.json). Authored viewport-edge clipping remains expected.
- Familiar-agent visual review: minimum Battle Road and Trenton plus normal Charleston. The crown's shoulders, cross and red inset remain distinct, including on tan path colors. [Review, iterations and native proof](../../../../in-defense-of-history-data/ArtReadability/reports/gold-crown-contrast-2026-09-10/README.md).
- Tight transparent crop: **PASS**, all nonzero-alpha pixels retained in the 533 × 546 standalone PNG. The 1×/2×/3× catalog exports share a consistent logical canvas. [Crop checks](../../../../in-defense-of-history-data/Images/Path-Exit-Crown-Proposals/2026-09-10-outlined/crop-checks.json).

The verification app used the exact production catalog and view, and was removed after capture. The production game save was preserved. No Simulator was used. Independent player recognition and user acceptance remain unmeasured.

Production installation and launch: **PASS** on the connected iPhone. [Install receipt](install.json) · [Launch receipt](launch.json). The first launch returned a LaunchServices registration mismatch; refreshing the app list and relaunching succeeded. The initial failure is preserved in `launch-first-attempt.json`.
