# Level 15 path centering verification

126 Swift tests passed. The physical iPhone probe passed 12 real LevelRunner loads (pair, solo, swapped rankings; four viewport layouts) with bounds, path-center, exit/HUD/foliage clearance, resize, and actual respawn checks. A separate host geometry check placed all 15 heroes at both exits at three sizes (90 cases).

`hero-exits.json` contains the measured positions, full sprite rectangles, margins, and cross-section endpoints/directions. `device-documents/level-15-*.png` are production LevelMapView ImageRenderer outputs rendered on the iPhone at 1× and 3×; `device` uses that iPhone's measured window/safe bounds. `verified-HeroExitRuntimeProbe.swift` is the test entry point used for this run. The later tool-only run-ID safeguard does not change placement or rendering.

The game builds successfully. The probe uses a separate installed app and copied database; the regular game's save is unaffected. The art review and rebuilt calibrated lab are in the sibling asset repository under `ArtReadability/reports/hero-path-centering-2026-09-09/`.
