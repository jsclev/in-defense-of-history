# HUD stats restoration

Lives and money again use the existing heart/coin icons on separate rounded black plates at the original 46% opacity. The wave plate reads `Wave current of total`; all values use white, bold rounded text. Live values come from the observed LevelRunner. The wave scheduler updates its published status whenever it enters a wave, refreshing the HUD.

The diegetic `stats_panel_bg` is no longer referenced by HudStatsView. Existing art remains in the catalog. Occupied bounds match the new fixed counter and wave frames, without the old artwork lift, preserving HUD placement and map gesture exclusions as values change.

## Validation and small-size review

- Signed physical-iPhone build: PASS (`iphone-build.log`).
- Production game install: PASS (`install.json`).
- Current host Engine module build: PASS (`host-build.log`).
- Production SwiftUI view with explicit value fixtures: rendered at minimum 604.44×340 and phone 874×402 canvases, at 1×/2×/3×. Minimum HUD is about 197.45×59.02 points; wave text is 15.1745 points. These host renders approximate iOS.
- Small proof inspected before enlargements: `minimum-start@1x.png`, `minimum-wide@1x.png`, `minimum-end-grass@1x.png`, `minimum-start-snow@1x.png`. White values, the two-lobed heart, and the stacked coins remain distinct; first/final/two-digit wave totals and 9,999 money fit without clipping. PASS in these checked conditions.
- Existing readability lab rerun: `lab/evidence.json` retains hashes and density exports. The stock roster sheet assumes narrow character sprites and overlaps wide HUD strips; use `minimum-readability.png`, which applies the lab's same color/grayscale/silhouette transforms at native size with adequate spacing. Color and grayscale pass; plate silhouettes alone are not intended to identify their counters.
- Scene fixtures use the current grass/snow base terrain at the runtime map scale. They are constructed stress scenes; the physical-device gameplay capture is separate.

`generate-render.py` recreates host proofs after `swift build --scratch-path /tmp/td-master-controls-tests`. `run-device-probe.py` checks real LevelRunner wave progression and renders production HUD views in a separate physical-device app with its own database. No Simulator is used. The first device diagnostic used the offline spawn start-time field as an interactive wave deadline; that incorrect test assumption was corrected to advance the actual wave scheduler.

## Physical iPhone result

PASS on the connected iPhone 15 Pro. The production runner loaded all 15 campaign levels and advanced through all 166 authored waves, with the displayed current number matching each wave and each level total remaining correct. `stats.json` records every displayed number. Production HUD renders show Charleston's `Wave 1 of 15` and `Wave 15 of 15`, plus the changed lives/money values. The full running Battle Road screen shows `Wave 1 of 6`, 20 lives and 270 money on the new black plates. Native device captures were visually inspected: all three plates, heart/coin icons, white digits and wave text remain readable. The gameplay capture is 852×393 logical pixels; 1×/2×/3× HUD captures are saved in `device-documents`.

The regular game was installed successfully (`install.json`) and relaunched (`launch.json`). The separate diagnostic app was removed after collecting its results. Source/data/capture hashes are preserved in the JSON records. Independent player testing remains unmeasured.
