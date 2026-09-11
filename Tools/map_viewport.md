# Map viewport stability

The map must never translate, resize, or recenter because a wave button, HUD counter, debug panel, or popup appears, changes, or disappears. The measured RuntimeCanvas screen is the size authority; UI content cannot participate in sizing the map.

LevelMapView uses LevelViewport, whose fixed screen rectangle independently proposes the same size to map, interface, and presentation overlays. PresentationStack still creates and removes individual popup subtrees in opening order. Do not put conditional full-screen controls back into the map's sizing ZStack.

The regression reproduced a 59pt horizontal and 17pt vertical jump with the previous shared ZStack when an 852×393pt screen received a 734×359pt parent proposal. Removing its full-screen wave-control child changed the required root size, which caused the centered parent to relocate the map. LevelViewport keeps the same screen-sized root and map proposal in both states.

Run `swift test --filter LevelViewportTests`. These tests render map markers across wave-control appearance/removal/reappearance, full and smaller parent proposals, oversized HUD and popup content, and unspecified/zero/larger proposals. They compare actual SwiftUI raster marker bounds and viewport dimensions, not only projection arithmetic.

Evidence: `reports/map-viewport-2026-09-08/results.json`, `tests.log`, and before/after reproduction PNGs. Both viewport tests and the unsigned Debug iPhone build passed. Physical-device tapping was not measured.

## Absolute window origin

The fixed viewport also needs ScreenCanvas at the app composition root. A centered root with fixed-size content was still centered within the shorter iPhone safe area despite an outer ignoresSafeArea modifier. On the iPhone 17 Pro simulator (874×402pt, 20pt bottom inset), this placed the map and HUD at window Y = -10; the top controls extended past the screen edge. ScreenCanvas uses a full-screen GeometryReader as a top-leading layout anchor. It does not remeasure or modify RuntimeCanvas, map projection, or HUD margins.

The initial raster tests established stability but did not establish the correct absolute origin. `python3 Tools/check_screen_origin.py --device <booted-iOS-26.5-simulator-udid>` now checks UIKit window coordinates using the production ScreenCanvas and LevelViewport. It requires map/HUD/root frames to equal the physical window at (0,0), checks intended marker and top-control positions, and toggles wave controls off and on. The separate probe app uses no game data. Evidence is in `reports/screen-origin-2026-09-08/uikit-results.json`. This is a simulator root/layout probe, not a full-game device capture.
