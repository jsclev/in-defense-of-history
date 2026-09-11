# Washington complete-icon regeneration — September 10, 2026

The user requested the same complete-icon process used for Knox. The built-in image generator created Washington, natural headroom, continuous teal background and the matching gold/navy rim as one painting. `HeroHUDButton.swift` maps Washington to `hud_hero_george_washington_framed` at full button size. Both completed portraits share the same exterior clipping outline; neither uses an inset portrait rectangle or a separate interior fill. Other hero paths are unchanged.

The original Washington portrait supplies his likeness, ivory hair, navy coat, gold/buff lapels and teal palette. Knox supplies the frame reference. Small previews rejected a tight first draft and an overly low second draft. The selected third version balances headroom with Knox while retaining a large face. Exact prompts and all drafts are preserved in `/Users/john/projects/td/in-defense-of-history-data/HUD/HeroButtons/2026-09-10-washington-regenerated/`.

## Verification

- Normal iPhone build succeeded. `compiled-icon.json` confirms the named 3x rendition is present at 384 × 384 pixels. Catalog exports are 128/256/384 pixels, from the 1254-pixel master cropped to the common 1226-pixel visible frame bounds.
- The isolated physical-iPhone probe captured current production views at minimum (44.9556-point button) and device (57.069-point button) layouts, at 1x/2x/3x. It includes ready/selected/unavailable Washington, all neighboring Knox and reinforcement states, a matched row and the live Charleston HUD.
- `check_renders.py` / `render-checks.json` record 44 geometry/preservation checks. All 36 neighboring-state captures match the preceding revision within one channel value. Visible Washington frame bounds match reinforcements within one raster pixel at each layout/density. Native outer corners are transparent. Tested source/catalog inputs and all 36 protected existing art/configuration files are preserved.
- I inspected the native 45-point portrait and matched row before enlargements, then the 3x portrait, selected/unavailable states, full minimum HUD and existing readability lab. The top and side hair shapes have visible teal clearance, the background flows to the rim without an inset seam, and Washington remains distinct from Knox through ivory side rolls, narrow face, gold lapels and teal field. Unavailable state consistently desaturates the whole button. This is a familiar-agent review; blinded human recognition and user acceptance remain unmeasured.

Native captures, source-before snapshot, hashes, build/probe logs and device receipts are retained here. The art review and lab are in `/Users/john/projects/td/in-defense-of-history-data/ArtReadability/reports/washington-regenerated-2026-09-10/`.

The temporary probe was removed. The normal game was installed and launched successfully on the physical iPhone; see `probe-uninstall.json`, `install.json` and `launch.json`.
