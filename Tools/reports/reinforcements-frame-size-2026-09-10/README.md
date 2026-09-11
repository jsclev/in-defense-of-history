# Correct reinforcement frame's visible HUD size

Only the blue frame's display geometry changes. Its painted rim is fitted to the existing hero-bar button size; the swords remain in the existing 64% box and all PNGs are unchanged. `BeforeReinforcementButton.swift` preserves the preceding implementation.

`iphone-build.log` records the successful game build. The focused physical-iPhone fixture renders the production hero/reinforcement views and captures the live HUD at minimum/device layouts, with 1×/2×/3× exports. `visible-frame-measurements.json` compares alpha bounds: corrected and hero frames match at 45×45 pt in the minimum proofs, with at most one point of raster-edge difference in the device proofs. This supplements direct visual inspection of the full three-button row.

`tested-source-hashes.json` identifies exact inputs, and `unchanged-art-hashes.json` verifies that the approved image files remain unchanged. `probe-uninstall.json`, `install.json` and `launch.json` record fixture cleanup and normal game deployment. No Simulator was used.

The data-side review, comparison sheets, selected/cooldown captures and regenerated readability lab are at `ArtReadability/reports/reinforcements-frame-size-2026-09-10/`.
