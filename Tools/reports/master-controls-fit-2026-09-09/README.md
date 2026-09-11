# Speed-up and back control fit

The old row chose the larger nominal control-area dimension, halved it, and
applied a 90% factor. It did not compute the actual rectangle available between
the HUD and the corner occlusion, or constrain both dimensions.

`MasterControlsLayout` now mirrors the hero-row rule at the upper-right corner:
HUD top/right edges, projected occlusion bottom/left edges, clipped to the HUD.
It fits two equal square buttons plus a 10% gap. `HudMasterControlsView` uses
that size and spacing, with an explicit row frame. The speed and exit handlers,
glyphs, their 60% padding policy, and configured HUD alignment are preserved.

| Fixture | Previous button | New button | Limiting dimension |
| --- | ---: | ---: | --- |
| 340pt minimum playable height, no safe insets | 40.800pt | 37.418pt | Width |
| 874×402pt phone, 750×382pt safe area | 45.840pt | 50.806pt | Height |
| 1024×768pt tablet, 1024×724pt safe area | 69.120pt | 63.390pt | Width |

The phone row reaches the corner's bottom edge at Y=58.446pt from the HUD top
at Y=7.64pt. The minimum/tablet rows previously extended left of their reserved
corner; fitting both dimensions corrects that overflow. Phone dimensions are
a geometry fixture, not a measurement of the installed iPhone's window.

Validation:

- All 96 Swift tests passed. New coverage checks phone gutter use, fitting both
  buttons and the gap in narrow widths, extra space above the map, zero available
  space, HUD anchoring, and map overlap/gesture exclusion across four screen cases.
- The signed iOS device build passed. See `iphone-build.log`.
- Current and previous production SwiftUI control views were rendered at
  minimum, phone, and tablet sizes at 1×/2×/3×. The geometry scene uses the same
  top-trailing HUD overlay as `HudView`. See `layout.json`, the PNGs, and hashes.
- The existing readability lab was rerun with freshly rendered minimum-size
  buttons. See `lab/evidence.json` and `readability.log`.

Visual review: inspected the native 1× pair before enlargements, the lab's
color/grayscale/silhouette plate, minimum and phone map scenes with guides,
then the 2×/3× pair. The speed icon has two separate right-pointing triangles;
the back control retains its two separate pause bars. The cream symbols stand
out from the brown interiors in both color and grayscale. Frame silhouettes
alone do not distinguish these controls. Both frames remain separate and clear
on the constructed grass scene, and the phone pair reaches the lower pink guide
without crossing it. These inspected conditions pass familiar-agent review;
physical-device appearance, touch usability, and independent recognition were
not measured. The minimum fixture's 37.418pt frame-sized tap targets remain
below 44pt; enlarging them within this narrow rectangle would not fit both
buttons and their gap.

Small proof: [minimum controls](minimum-after@1x.png).
Geometry proof: [phone before](phone-before-guides@1x.png) and
[phone after](phone-guides@1x.png). Yellow marks HUD bounds, pink marks playable
bounds, and the blue tint marks the combined available rectangle.

Reproduce after `swift test --scratch-path /tmp/td-master-controls-tests`:

```sh
python3 Tools/reports/master-controls-fit-2026-09-09/generate-render.py
python3 ../in-defense-of-history-data/ArtReadability/build_readability_lab.py \
  --manifest Tools/reports/master-controls-fit-2026-09-09/source-manifest.json \
  --output Tools/reports/master-controls-fit-2026-09-09/lab
```

The lab interpreter needs Pillow; the renderer needs macOS graphics services.
The renderer copies the game database before reading it through the DAO.
