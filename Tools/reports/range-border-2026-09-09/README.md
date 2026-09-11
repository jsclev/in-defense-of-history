# Range overlay border review — 2026-09-09

The previous overlay tinted the entire ellipse and used a dark backing stroke.
The production view now keeps the fill transparent through 92% of its elliptical
radius, fades rapidly to green over the remaining 8%, and finishes with a
2-point green stroke at 95% opacity inside the boundary. Upgrade previews keep
their dashed boundary and use a lighter edge fade.

## Evidence and results

- **PASS, visual self-review:** [native-size-proof.png](native-size-proof.png)
  was inspected first at its native size. At a 393-point-wide portrait fit
  (221.0625-point playable height), the smallest range is a 130.623375 ×
  91.4363625-point ellipse. Its interior shows the original terrain colors;
  the narrow green edge remains distinguishable on Battle Road vegetation,
  Great Bridge water/grass, and Trenton snow. The dashed upgrade ring remains
  distinct from the solid current ring. These are constructed terrain scenes.
- **PASS, density self-review:** [density-proof.png](density-proof.png) shows
  1×, 2×, and 3× production SwiftUI renders at a 340-point playable height,
  displayed at the same logical size. The edge is continuous and the center
  clear on all three terrains. Pillow resampling is used only to present the
  higher-density rasters at logical size on this desktop proof.
- **PASS, raster observations:** [alpha-review.json](alpha-review.json) records
  zero alpha throughout the inner 90% for all nine combinations of playable
  heights 221.0625 / 340 / 900 and densities 1× / 2× / 3×. Peak boundary alpha
  is 250–251 / 255 after the fill and border composite. Equal-range upgrade
  output is byte-identical to the current ring, preserving duplicate removal.
- **PASS, compilation:** Swift compiled the actual production view together
  with the current `VirtualCanvas`, `RuntimeCanvas`, and `TowerRangeOverlay`
  sources. `git diff --check` passed.
- **NOT MEASURED:** physical iPhone appearance, independent human review, and
  a full app build/run. The actual SwiftUI view was rendered with macOS
  `ImageRenderer`; this is not an iOS runtime capture. Animation and directional
  artwork do not apply to this static overlay change.

The existing [readability lab](lab/index.html) was run with a custom manifest
containing the production overlay rasters at the compact portrait size. Its
[evidence](lab/evidence.json) records raster and terrain hashes; the
[input manifest](input-manifest.json) records production source hashes.
[geometry.json](geometry.json) records every rendered size. The lab's clamp is
fixed to that fixture size because scaling a captured raster would incorrectly
scale the runtime's constant 2-point stroke. Larger sizes were rendered anew
using SwiftUI and are recorded separately.

Reproduce the render and lab from the repository root using the bundled Python
runtime (Pillow required):

```sh
/Users/john/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 Tools/reports/range-border-2026-09-09/render_review.py
```

Failure and correction: a uniform translucent fill can obscure the requested
clear center even when the outline is visible. For this range overlay, review
the unmodified terrain through the center and the short fade into the boundary
at the same gameplay scale; a large isolated ellipse alone does not establish
the intended appearance.
