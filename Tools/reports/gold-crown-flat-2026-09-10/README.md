# Flat crown path marker

The crown's violet sidewall made it look raised above the path. `flatExitCrown` now removes that thickness cue at the 96-point source canvas before gameplay downsampling. The gold/red face, previous half-angle transform, 25.6-point minimum source frame and authored exit centers are preserved.

- Production iPhone build: **PASS**, [build log](iphone-build.log).
- Separate physical-iPhone verification app: **PASS**, all 26 authored exits across 15 campaign maps. [Device results](exit-markers.json). The temporary app was removed after capture, preserving the production game save.
- Rendered bounds: **PASS**, 52 comparisons at 1× and 3×, within two raster pixels. [Bounds results](raster-checks.json). Authored viewport-edge clipping remains expected.
- Actual shader output: **PASS**, 3,249 original opaque violet pixels reduced to zero, with 100% opaque warm-core retention and true transparent output. [Color/alpha checks](flat-face-checks.json).
- Visual self-review: minimum Battle Road and Trenton plus normal Charleston. Gold shoulders, red inset and cross survive while the raised lower edge disappears. [Native before/after and lab](../../../../in-defense-of-history-data/ArtReadability/reports/gold-crown-flat-2026-09-10/README.md). Familiar-agent observations do not establish independent player recognition or user acceptance.

The probe renders the production view and uses the exact production compiled asset catalog; [catalog hash](compiled-catalog.json). `flat-face@1x.png`, `@2x.png` and `@3x.png` in `device-documents` are real iPhone captures of the shader before the existing perspective transform, and serve as lab inputs. No Simulator was used.

Production installation and launch: **PASS** on the connected iPhone. [Install receipt](install.json) · [Launch receipt](launch.json).
