# Single-line range overlay — September 10, 2026

The range indicator is now **blue-violet #5842C7**, a distinct cool accent
against the predominantly yellow-green grass. Each range has one opaque
2-point boundary, with the same hue fading to transparent immediately inside.
The dark companion stroke has been removed. The fade occupies at most the outer
10% of the elliptical radius and is capped at 6 vertical points including the
border, so it stays short on larger displays. The interior remains clear.

The solid current boundary and dashed potential-upgrade boundary still convey
different ranges. Their separate ellipses do not represent doubled styling on
a single boundary. Equal current and upgrade ranges still render only once.

## Dota 2 guidance consulted

Re-read the project's small-game-art research and the official
[Valve Dota 2 Character Art Guide](https://help.steampowered.com/en/faqs/view/0688-7692-4D5A-1935#saturation).
The browser exposed the full Color and Saturation, Color Schemes, and Context
sections when the text-only web reader did not. Visually inspected the guide's
color wheel and its complementary-color discussion.

The directly relevant advice is to avoid map-dominant colors, select related
hues deliberately, reserve strong saturation for small focal areas, and review
value and color in the actual game view. The [color-scheme examples](https://help.steampowered.com/en/faqs/view/0688-7692-4D5A-1935#colorschemes)
include complementary and split-complementary relationships.

Our application is a blue-violet accent against yellow-green turf, with a darker
value to aid separation. The hue and exact shade are our choice for this map;
Valve does not prescribe this color for range indicators. This overlay conveys
the selected tower's coverage or militia rally limit. It uses a non-red color
because the user explicitly wants to avoid error signaling. Its shape, position
and solid/dashed state provide context for the meaning.

The preceding green treatment was rejected: preserving the background's color
family and adding a dark separator produced the unwanted appearance of two
lines. The project research notes now preserve that correction.

## Evidence and review

- **PASS — compact visual self-review:** inspected
  [native-size-proof.png](native-size-proof.png) before any enlargement.
  At the 393-point portrait fit, playable height is 221.0625 points and the
  smallest range ellipse is approximately 130.62 × 91.44 points. The single
  blue-violet contour stays traceable on grass and composed Battle Road; it
  also remains visible across most of the detailed Trenton scene. Its inward
  blend has no dark secondary edge. Snow is a secondary stress condition;
  grass is the palette's primary design background.
- **PASS — calibrated lab:** ran the [existing lab](lab/index.html) with actual
  SwiftUI range rasters. Inspected current range at 2× and upgrade range at 3×
  in color, grayscale and silhouette on the grass. The line remains a continuous
  contour and upgrade dashes remain distinct. The lab's compact-size clamp is
  fixed because rescaling a captured raster would change its stroke width.
  [Lab evidence](lab/evidence.json) records input hashes and dimensions.
- **PASS — physical iPhone:** the separate review app built and ran the current
  production `TowerRangeOverlayView` over production `LevelMapView`. Saved
  before/current/upgrade/clear captures at 852 × 393 device points and the
  604.44 × 340-point fixture, at 1×, 2× and 3×. Inspected the minimum current
  capture and the normal-size upgrade capture. The boundary separates from
  grass without a second line, and the center leaves terrain and tower slots
  untinted. The range position is set explicitly in this constructed review
  state; this does not test selection gestures. See
  [native iPhone comparison](iphone-native-comparison.png),
  [capture metadata](range-check.json), and [probe build log](probe-build.log).
- **PASS — raster observations:** at 221.0625 / 340 / 900 playable heights,
  each at 1× / 2× / 3×, the center has zero alpha and the outward radial sample
  crosses one opaque band. Equal-range upgrade output matches a single ring.
  [alpha-profile.json](alpha-profile.json) preserves the profiles and sampling
  results. These observations support geometry and transparency; visual review
  establishes the absence of the previous two-color edge.
- **PASS — source compilation:** actual SwiftUI view compiled on macOS and in
  the iPhone review build; `git diff --check` passed.
- **NOT MEASURED:** independent human recognition, color-vision-deficiency
  simulation, and physical screen appearance under varied ambient light.
  Grayscale self-review is not equivalent to those measurements.

[Palette analysis](palette-analysis.json) compares candidate specified colors
against the grass at gameplay scale. The selected color has approximately
2.86:1 median sRGB luminance contrast against that sample. Hue separation and
visual inspection are essential here; this figure alone is not an acceptance
criterion or an accessibility certification.

[Source evidence](source-evidence.json) records the view, geometry and terrain
hashes. The final main-app [build](iphone-build.log) passed, its signature
verified, and the game [installed](install.json) and [launched](launch.json)
successfully on the iPhone. The temporary review app was removed after its
captures were saved. Production terrain and other artwork were not changed.
