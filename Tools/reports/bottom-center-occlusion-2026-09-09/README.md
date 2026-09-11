# Bottom-center play-area occlusion

Added September 9, 2026. Landscape calibration only, as requested.

The rectangle is centered horizontally on the play area and flush with its bottom edge. Its height is 20% of the lower-left corner occlusion: **33.048 canonical units**, or 3.06% of play-area height. Lower-left, lower-right, and upper-right retain equal heights of 165.24 units.

Its width is **315 / 1133 = 27.80229479% of the full screen width**, converted into map coordinates using the live runtime scale. The width is clamped to the play-area width for extreme window proportions. The authored/editor reference uses the full virtual canvas width. Existing saved canvas documents need no new serialized fields.

## Measurement evidence

Apple's [layout guidance](https://developer.apple.com/design/human-interface-guidelines/layout) and [design resources](https://developer.apple.com/design/resources/) did not provide a numeric, device-by-device landscape home-indicator width table. The figures below are direct raster measurements of the system-drawn home indicator in Apple's installed simulators, using a separate, disposable UIKit probe. No indicator drawing or private API was added to the game.

The release window considered was September 9, 2021 through September 9, 2026. The largest verified fraction in this sample belongs to the iPad mini (6th generation), which [Apple released on September 24, 2021](https://www.apple.com/newsroom/2021/09/apple-unveils-new-ipad-mini-with-breakthrough-performance-in-stunning-new-design/).

| Device | Simulator OS | Landscape width (pt) | Measured indicator (pt) | Screen width fraction |
| --- | --- | ---: | ---: | ---: |
| iPad mini (6th generation) | 18.6 | 1133 | 315 | **27.8023%** |
| iPad Pro 11-inch (4th generation) | 18.6 | 1194 | 315 | 26.3819% |
| iPhone 17 Pro | 26.5 | 874 | 225 | 25.7437% |
| iPhone 13 mini | 26.5 | 812 | approximately 208.90 | 25.7265% |

The other sampled devices also fall within the window: [iPhone 13 mini, September 2021](https://www.apple.com/newsroom/2021/09/apple-introduces-iphone-13-and-iphone-13-mini/), [M2 iPad Pro, October 2022](https://www.apple.com/newsroom/2022/10/apple-introduces-next-generation-ipad-pro-supercharged-by-the-m2-chip/), and [iPhone 17 Pro, September 2025](https://www.apple.com/newsroom/2025/09/apple-unveils-iphone-17-pro-and-iphone-17-pro-max/).

This is the largest **verified** landscape fraction among the sample, not a guarantee covering every hardware/OS/display-mode combination. Newer iPad simulator attempts (including M5 13-inch and A16) produced portrait or letterboxed system displays despite the probe reporting a landscape application window. Those measurements were rejected. Simulator UI control was not approved, so no manual rotation check was performed. Earlier captures with no visible indicator were also rejected.

`measurements.json` contains the successful results with raw screenshot bounds and geometry. The original PNG screenshots and per-device geometry JSON files are retained. Some rejected captures remain alongside them; only entries in `measurements.json` are accepted evidence. `measure-home-indicator.py` and `HomeIndicatorProbe.swift` reproduce the measurement workflow using temporary simulators that the script removes afterward.

Screenshots are normalized from the native portrait framebuffer when necessary. The white-background probe detects the dark system pill in the central bottom strip and rejects implausible thickness or centering. The first iPhone 13 mini capture used a black background and a brightness threshold instead; its fractional result accounts for the mini's downsampled native framebuffer. Raster antialiasing creates sub-point measurement uncertainty. The chosen 315 pt iPad result is larger than either phone measurement by more than that uncertainty.

## Implementation and checks

- `VirtualCanvas`: adds the derived bottom cutout to play-area subtraction, tower-centre constraints, and tower-footprint constraints.
- `RuntimeCanvas`: resolves the width from the full physical screen, then projects all five occlusions into screen coordinates.
- `TowerMenuLayout`: reserves the new region with menu clearance.
- `HeroStartingPositionManager`: avoids all runtime occlusions while preserving other HUD obstacles.
- Debug layout guides already draw the runtime play path, so the new notch appears automatically.

All **114 Swift tests passed**. New tests cover the 20% height relationship, centering, bottom alignment, full-screen width ratio, phone/tablet safe insets, coordinate origins, slot/menu clearance, saved-canvas compatibility, and extreme widths. Existing hero placement tests include bottom-edge exits and pass with the new cutout.

The signed iPhone build succeeded. Deployment evidence is in `install.json` and `launch.json` after deployment. No art asset or control size was changed by this patch.

The geometry-only proofs were rendered from the production canvas paths at their native logical sizes and inspected directly. All three show the shallow centered notch and the corresponding tower clearance. These are layout diagrams, not in-game screenshots or art-readability acceptance renders.

- [Phone geometry](phone-geometry.png): 874 × 402 fixture, cutout 242.992 × 11.689 pt.
- [Minimum geometry](minimum-geometry.png): 604.444 × 340 fixture, cutout 168.049 × 10.404 pt.
- [iPad mini geometry](ipad-mini-geometry.png): 1133 × 744 fixture, cutout 315 × 19.502 pt.

`layout.json`, `source-hashes.json`, `swift-tests.log`, and `iphone-build.log` retain the detailed results.
