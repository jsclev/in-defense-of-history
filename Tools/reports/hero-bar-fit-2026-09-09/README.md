# Hero and reinforcement button fit

The row was capped at the occlusion's own width and height even when the HUD
extended into space beside or below the map. `HeroBarLayout` now fits the three
equal square buttons and their two 10% gaps between the HUD's left/bottom edges
and the occlusion's right/top edges, clipped to the HUD bounds.

The 874 × 402 point phone fixture has a 750 × 382 point safe area. Its buttons
grow from 54.7533 to 58.446 points, exactly the reduced corner's full height.
The bottom and left anchors are preserved. The actual phone window geometry
was not measured; the fixture matches the previously captured phone-layout case.

Validation:

- All 91 Swift tests pass. New regressions cover space beside the map allowing
  full occlusion height and space below the map allowing additional height.
  Existing tests check actual map overlap, HUD containment, gaps, and gestures.
- Production SwiftUI row/button views render in six states at minimum, phone,
  and tablet sizes at 1×, 2×, and 3×. Fixture state and file-backed asset lookup
  replace the game runner and asset bundle; sizing uses the current Engine.
- The old layout is rendered alongside the current one. Exact RGBA comparison
  verifies the minimum and tablet fixtures remain identical. Phone artwork grows
  at every density. See `layout.json` and `raster-checks.json`.
- The existing readability lab was rerun on freshly rendered minimum-size
  controls; source hashes are saved in `source-hashes.json` and `lab/evidence.json`.
- The signed device build passed (`iphone-build.log`).

Visual review: inspected the native 1× row before enlargements, the lab's native
color/grayscale/silhouette plate, the phone before/after guides, 2× cooldown, and
3× selected state. Knox's brown hair/red coat/cannon and Washington's dark
tricorn/white side hair/blue coat remain distinct. Reinforcements retain crossed
weapons and grouped troops; the dark cooldown badge and white numbers are clear.
The selected white border is visible. In the constructed grass-map phone scene,
all three frames reach the occlusion top edge and remain inside the HUD bottom.
This is a familiar-agent visual pass for the inspected conditions, not a full
game capture or physical-device visual acceptance.

Small proof: [minimum row](minimum-ready@1x.png).
Geometry proof: [phone before](phone-before-guides@1x.png) and
[phone after](phone-guides@1x.png). Yellow marks HUD bounds, pink marks playable
bounds, and the blue tint marks the combined available rectangle.

Reproduce after `swift test --scratch-path /tmp/td-runtime-canvas-tests`:

```sh
python3 Tools/reports/hero-bar-fit-2026-09-09/generate-render.py
python3 ../in-defense-of-history-data/ArtReadability/build_readability_lab.py \
  --manifest Tools/reports/hero-bar-fit-2026-09-09/source-manifest.json \
  --output Tools/reports/hero-bar-fit-2026-09-09/lab
```

The lab interpreter requires Pillow. The SwiftUI renderer requires macOS graphics
services. The render script copies the game database before using the DAO.
