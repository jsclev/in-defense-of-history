# Knox HUD portrait framing

`HeroHUDButton` gives `hero_icon_henry_knox` the approved blue frame and a 68% portrait box, previously 75%. The portrait PNGs are unchanged. Other hero presentation rules are unchanged.

`PaintedHUDButtonFrame` in `HudButtonView.swift` is the existing calibrated reinforcement-frame drawing extracted for reuse. Both Knox and reinforcements call it, preserving the visible size/alignment correction. Their frame bounds match at both phone layouts and all densities.

- `iphone-build.log`: successful production game build.
- `device-documents/`: production Knox before/ready/selected/unavailable states, neighboring controls, full HUD rows and the live level at 1×/2×/3×.
- `visual-regression-checks.json`: blue-frame equality plus comparisons of 24 Washington/reinforcement renders against the prior version. Twenty-two are pixel-identical; two overlay renders have ten changed pixels each, all channel differences ≤1/255.
- `original-knox-hashes.json`, `unchanged-art-hashes.json`, `tested-source-hashes.json`: original art preservation and exact verified input versions.
- `probe-uninstall.json`, `install.json`, `launch.json`: fixture cleanup and normal game deployment.

The isolated fixture invokes the production views on the physical iPhone; it does not modify gameplay actions or data. No Simulator was used. The inherited fixture result is named `reinforcements-check.json`; its screenshots additionally cover all Knox states. The data-side review and existing readability lab are at `ArtReadability/reports/knox-hud-blue-frame-2026-09-10/`.
