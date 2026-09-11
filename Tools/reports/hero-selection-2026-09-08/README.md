# Hero portrait selection — September 8, 2026

Both HUD portraits resolve the displayed hero by UUID at the time of the tap, then invoke the same selection method as the map sprite. This keeps the mapping attached to the hero identity and rechecks availability when the action runs.

The production SwiftUI portrait buttons were exercised with macOS pointer events. Their resulting runner state matched direct map selection for the first hero, switching to the second hero, toggling selection off, selecting again, and issuing a destination command. The checks also cover dismissing tower menus, cancelling reinforcement placement, rejecting a disabled/dead portrait and unknown identity, retaining the second hero's index when the first sprite disappears, and selecting the first hero after respawn.

- Button interaction regression: PASS. See `results.json` for production source hashes and method coverage.
- Existing hero HUD gesture-exclusion, presentation, and viewport tests: 11 passed, 0 failures.
- Unsigned iPhone app build: SUCCEEDED.
- Physical-device touch delivery: not measured. The interaction probe uses production views/methods with fixture level state in a macOS window.

Reproduce with `python3 Tools/check_hero_selection.py --output Tools/reports/hero-selection-2026-09-08` after building the Engine module with `swift test --scratch-path /tmp/td-presentation-tests`.
