# Button padding without new icon artwork

`HudSizing.paintedButtonIconFraction = 0.72` gives the approved gun, ranged choices, sack and reinforcement swords interior clearance. The gun/sack/ranged choices previously used 0.80; swords used 0.75. Tower frames and placement are unchanged. The editor shares the ranged menu sizing.

`CallWaveArtwork` reuses the original flattened PNG in separate display layers, holding its rim fixed while scaling the interior to 90%. Its extra red space is a view background. The saved horn PNG and its exact artwork remain unchanged. The call-wave behavior, pulse and countdown are retained.

- `iphone-build.log` and `editor-build.log`: successful builds.
- `ranged-check.json`: physical iPhone at 373 pt and minimum 340 pt playable height; six ranged build/upgrade variants and confirmations passed.
- `device-documents/`: actual private tower-menu components, live menus, and before/after production HUD renders at 1×/2×/3×.
- `unchanged-art-hashes.json`: 32 original artwork/config files checked unchanged.
- `tested-source-hashes.json`: 51 source/catalog files matched after the device fixture.
- `probe-uninstall.json`, `install.json`, `launch.json`: temporary fixture removal and normal game installation/launch receipts.

The fixture is isolated in a temporary app. It grants money/unlocks and invokes production build actions; it does not automate physical taps. No iOS Simulator was used. `preview-horn.swift` is an initial macOS SwiftUI geometry check, superseded by the physical-iPhone captures.

The data-side review is `ArtReadability/reports/button-padding-2026-09-10/README.md`, with minimum-size comparison plates, original-art preservation notes and the existing readability lab output. No ImageGen result was applied after the user clarified that the artwork must stay unchanged.
