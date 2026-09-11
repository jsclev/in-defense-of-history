# Tower sprite height

Ranged alone ignored `TowerKind.spriteHeight`: `LevelMapView` calculated the
height but rendered that family from slot dimensions × `slotTowerScale` instead.
The separate branch and its sizing/placement constants are removed. Every tower
now uses the same image frame and position, with its height set in
`Engine/Models/TowerKind.swift`.

The user's current values are preserved: ranged 15, melee 75, artillery 75,
special 80. These are reference-map image heights, including transparent padding.
At the minimum playable height, ranged's image is now 7.786 points tall. The
[native proof](native-size-proof.png) shows that this value is very small and
does not pass upgrade recognition; it is preserved as the user's tuning value.
This change repairs the control rather than choosing a new art size.

Validation:

- Engine package and iOS app build passed (`swift-build.log`, `ios-build.log`).
- 84 actual SwiftUI raster checks cover all 21 shipped tower images at 340-point
  playable height in 1×/2×/3× and at 900 points in 1×. Doubling the requested
  height increases both visible dimensions to approximately twice their size
  (four raster pixels of tolerance for alpha-threshold/resampling edges).
- Doubling slot dimensions leaves the current tower output pixel-identical.
- Melee, artillery and special remain pixel-identical to their previous output.
- 24 pre-fix ranged cases reproduce the bug: doubling the requested height
  leaves the rendered image pixel-identical.

`Tools/check_tower_sprite_height.py` extracts the production SwiftUI tower block;
it substitutes only file-based asset loading and a fixture that varies the
requested height. It also runs the existing readability lab for source hashes,
native color/grayscale/silhouette proofs and real terrain crops. The saved
`review.json` records the visual findings and limits. Desktop SwiftUI is measured;
phone appearance and independent recognition are not measured.

Reproduce after building the package to `/tmp/td-tower-sprite-tests`:

```sh
python3 Tools/check_tower_sprite_height.py \
  --output Tools/reports/tower-sprite-height-2026-09-09 \
  --before-view Tools/reports/tower-sprite-height-2026-09-09/before-LevelMapView.swift
```

The Python interpreter needs Pillow, and the renderer needs macOS graphics
services. `--measure-only` reruns assertions on already generated images.
