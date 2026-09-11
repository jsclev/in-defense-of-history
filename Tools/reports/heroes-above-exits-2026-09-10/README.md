# Heroes above exit icons — September 10, 2026

Moved the existing hero rendering block immediately after `LevelExitMarkersView`
in the map's SwiftUI ZStack. Hero images, selection rings and health bars all
render above the exit symbols and endpoint foliage. HUD and presentation layers
remain above map content. Hero artwork, sizing, coordinates, tap behavior and
health-bar rendering were preserved unchanged.

## Verification

- Signed physical-iPhone game build passed (`game-build.log`).
- A separate diagnostic app placed both Charleston heroes directly on the two
  exit points, without modifying the production level or the player's save.
- 12 actual runner checks passed across pair/solo/ranking changes and viewport
  inputs, retaining exact GeoJSON positions and respawns (`device/hero-exits.json`).
- Inspected the complete 604 × 340 one-density minimum gameplay capture before
  the 852 × 393 physical-device capture. Both heroes' bodies and legs cover the
  exit crowns where they intersect; crowns remain visible around their feet.
  The HUD is unobscured. Evidence: `device/device-documents/level-15-minimum.png`
  and `device/device-documents/level-15-device.png`.
- No Simulator or new artwork was used. This verifies compositing of existing
  assets; it is not a new artwork or independent recognition study.
