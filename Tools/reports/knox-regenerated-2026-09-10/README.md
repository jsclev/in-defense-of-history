# Knox complete-icon regeneration — September 10, 2026

The user rejected the separately filled orange padding and explicitly requested regeneration of the entire icon with space around Knox's head. The built-in image generator produced one complete framed painting. `HeroHUDButton.swift` now displays `hud_hero_henry_knox_framed` at the full button size. The previous 64% inset, downward offset, blue frame layer and orange interior overlay are removed from Knox's branch. Other heroes and reinforcements retain their existing appearance.

The complete source is 1254 × 1254 pixels. Its visible outer frame is cropped to `(14, 2, 1240, 1228)` and exported at 128/256/384 pixels. The selected output is RGB; a second request returned a painted checkerboard and was discarded. A SwiftUI outline clips only the exterior of the selected image's metal frame. The headroom, portrait and continuous orange background are all within the generated painting.

## Verification

- iPhone build succeeded; `compiled-icon.json` confirms the installed catalog's named 3x rendition is 384 × 384.
- The physical-iPhone probe rendered production components, selected/unavailable states, the adjacent button row and live Charleston HUD at minimum/device sizes and 1x/2x/3x. Complete Knox button sides are 44.9556 and 57.069 points. The inherited `iconSide` field in the raw probe JSON describes the reinforcement emblem, not the new complete Knox image.
- `check_renders.py` / `render-checks.json` record 32 geometry/preservation checks. Visible frame bounds match the adjacent reinforcement frame within one raster pixel at every tested size/density. Outer corner pixels are transparent in native renders. All 24 neighboring control captures match the preceding revision within one channel value. Tested source/catalog inputs and all 32 protected existing art/configuration files are unchanged after capture.
- I inspected the 45-point native icon and matched row first, then the 3x view, selected/unavailable states, full minimum HUD and the existing readability lab. The orange field is continuous to the rim, without a rectangular inset seam. Clear painted space separates the hair from the top rim; broad face, dark hair, red/blue uniform and cannon remain readable. This is a familiar-agent assessment; blinded human recognition and user acceptance are unmeasured.

Art, generation prompts and export metadata are in `/Users/john/projects/td/in-defense-of-history-data/HUD/HeroButtons/2026-09-10-knox-regenerated/`. Native evidence and the lab are in `/Users/john/projects/td/in-defense-of-history-data/ArtReadability/reports/knox-regenerated-2026-09-10/`. Device cleanup/install/launch receipts are retained here.

The temporary probe was removed and the normal game was installed. Initial launches returned iOS Busy and LaunchServices registration errors. Refreshing the installation and launching its returned device path succeeded; see `install-refresh.json` and `launch-refreshed.json`. The normal game is now running on the physical iPhone.
