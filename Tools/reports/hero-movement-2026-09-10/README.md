# Hero path movement regression — September 10, 2026

The hero navigation graph clipped road samples to a rectangle inset for sprite visibility. Charleston's upper road leaves that rectangle and returns, breaking the only route from Henry Knox's assigned exit to several visible destinations. Kettle Creek had the same issue near an entrance. The movement command was accepted, but Dijkstra returned an empty route and the hero stayed still.

`LevelRunner.buildHeroRoads()` now samples each complete authored road and its exact endpoint. Rendering bounds no longer cut navigation connections. Existing junction and route-selection behavior is preserved.

Validation:
- `python3 Tools/check_hero_movement.py --output Tools/reports/hero-movement-2026-09-10/after`: 175 destinations along 35 roads in 15 campaign levels, including graph-edge validity. Before: four failures (three in Charleston, one in Kettle Creek). After: zero. Production graph/spawn/route methods are extracted unchanged and linked with Engine; generated sources, hashes, and results are in `before/` and `after/`.
- Physical iPhone 15 Pro, iOS 26.6.1, production LevelRunner with real Charleston data in a separate disposable app. For each HUD hero identity, select, command to the corresponding road's quarter-distance point, and advance 120 production hero ticks. Before: Knox accepted selection and destination but moved 0 units. After: Knox moved 677.41 units; Washington moved 446.78 units. Device results and the diagnostic app/runner helper are retained here.
- Ten focused Swift tests passed (presentation stack, runtime canvas, viewport stability).
- A native macOS SwiftUI pointer probe delivered the hero-selection-to-destination gesture through the production destination catcher and presentation layer. This does not prove iOS touch delivery.

The attempted physical-device XCTest UI test did not initialize because authentication was canceled. The successful device check exercises production selection, commands, and movement directly; it does not synthesize screen taps. No iOS Simulator was used.

The signed production game build succeeded, was installed on the connected iPhone, and launched successfully (`com.zippyzen.liberty-line`). Both disposable diagnostic apps were removed. The final build log and tested source hashes are retained alongside this report.
