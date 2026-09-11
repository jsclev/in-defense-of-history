# Second button-padding pass

Only `HudSizing.paintedButtonIconFraction` (0.72 → 0.64) and the interior scale in `CallWaveArtwork` (0.90 → 0.80) change. The artwork files are unchanged. `Before/` preserves the preceding source versions.

The iPhone fixture compares the previous display geometry against the current production views for the gun, sack, swords and horn. It also captures the actual private tower-menu components, live menus and six ranged build/upgrade variants at minimum/device layouts and 1×/2×/3× density. It invokes production confirmation actions in an isolated temporary app; no physical tap automation or iOS Simulator is used.

- `iphone-build.log`, `editor-build.log`: successful builds.
- `ranged-check.json`, `probe-run.log`: physical-device fixture passed.
- `device-documents/`: native-size visual evidence.
- `unchanged-art-hashes.json`: 32 original art/config files.
- `tested-source-hashes.json`: exact source/catalog inputs used by the fixture.
- `probe-uninstall.json`, `install.json`, `launch.json`: temporary fixture removal and regular game installation/launch.

The data repository contains the review, comparison sheets and regenerated existing readability lab at `ArtReadability/reports/button-padding-pass2-2026-09-10/README.md`. The preceding pass is retained separately; its comparisons are not substituted for this pass's verification.
