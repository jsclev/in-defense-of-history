# Henry Knox HUD headroom — September 10, 2026

The user requested more space above Knox's head while preserving his approved portrait and blue frame. `HeroHUDButton.swift` now draws Knox at 64% of the button side, down from 68%, and offsets him downward by 2% of the button side. This holds the portrait's lower edge at 84% of the button side and moves its top from 16% to 20%. The frame, button size, selection treatment, and original portrait files remain unchanged.

At the minimum 44.9556-point button size, this adds 1.7982 points above the portrait. On the connected iPhone's 57.069-point button, it adds 2.2828 points. The original 96/192/288-pixel image exports are reused without raster edits.

## Verification

- Normal iPhone build succeeded; see `iphone-build.log`.
- The isolated physical-iPhone probe compiled current production views and rendered the previous and updated Knox buttons, selected/unavailable states, adjacent buttons, and live Charleston HUD at minimum and device layout sizes. Captures cover 1x, 2x, and 3x; see `probe-run.log` and `device-documents/`.
- Visual review of the native minimum-size proof, full HUD, and readability-lab roster confirms a larger blue gap above the hair, continued clearance beneath the coat, and a recognizable face, hair mass, blue coat, and red sash. This is a familiar-agent review, not a blinded recognition study. Opaque framed-button silhouettes alone cannot measure portrait recognition.
- `headroom-checks.json` records increased portrait top clearance at all six size/density combinations. All 24 adjacent Washington/reinforcement state captures are pixel-identical to the preceding approved revision.
- `final-preservation-checks.json` verifies all 30 tested source/art inputs, all four original Knox catalog files, and all 32 protected recent art/configuration files.
- The temporary probe was removed. The normal game was installed and launched successfully on the physical iPhone; see `probe-uninstall.json`, `install.json`, and `launch.json`.

The art review and small before/after proof are in `/Users/john/projects/td/in-defense-of-history-data/ArtReadability/reports/knox-headroom-2026-09-10/`.
