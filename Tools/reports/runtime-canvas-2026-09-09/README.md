# Runtime canvas verification

[Read the full audit](../../runtime_canvas_audit.md).

| Check | Result | Evidence |
| --- | --- | --- |
| Swift suite | 81 tests passed | [tests.log](tests.log) |
| Complete iOS device build | Passed, unsigned Debug | [ios-device-build.log](ios-device-build.log) |
| Live UIKit geometry | Window/safe-area resize, restored origin, stable state passed | [uikit-results.json](uikit-results.json) |
| Production-view capture | Seven screens, two canvas conditions, 1×/3× | [screen-capture.log](screen-capture.log), screenshots below |
| Visual layout review | Reviewed conditions passed; remaining limits recorded | [visual-review.json](visual-review.json) |
| Source coverage | 168 source/configuration files | [source-inventory.json](source-inventory.json) |
| Done minimum artwork | 35.65pt height, exact HudSizing conversion | [lab](done-lab/index.html), [asset hashes](done-lab/evidence.json) |

The captures use production SwiftUI views and built artwork inside a separate simulator sandbox. The 340pt fixtures have a synthetic canvas with no safe insets; they are a minimum-size layout stress test. The phone fixtures use the actual 874×402pt window. Full-game Metal rendering and physical-device interaction were not measured.

Minimum-size Heroes screen, with its navigation footer clear of the last card:

![Heroes at the 340pt reference canvas](/Users/john/projects/td/in-defense-of-history/Tools/reports/runtime-canvas-2026-09-09/screens/minimum-heroes@1x.png)

Minimum-size briefing, with complete difficulty descriptions and no footer overlap:

![Briefing at the 340pt reference canvas](/Users/john/projects/td/in-defense-of-history/Tools/reports/runtime-canvas-2026-09-09/screens/minimum-briefing@1x.png)

Other minimum captures: [hero details](screens/minimum-hero-details@1x.png), [encyclopedia](screens/minimum-encyclopedia@1x.png), [settings](screens/minimum-settings@1x.png), [HUD configuration](screens/minimum-hud-layout@1x.png), and [gameplay UI](screens/minimum-level@1x.png). The same directory contains phone-window captures and all 3× raster exports.

The `before` directory contains intermediate captures that revealed the hero-footer overlap and difficulty truncation. They are pre-correction evidence, not untouched-repository baseline captures. The wide Done plaque overlaps the generic readability lab's narrow roster cells; use the unclipped plaque in the production-view captures as the complete minimum-size visual proof.
