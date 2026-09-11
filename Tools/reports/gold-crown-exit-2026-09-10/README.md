# Gold Stamp exit marker integration

`LevelExitMarkersView` now uses the user's selected `path_exit_crown` asset and omits the old X-only vertical transform. `MapSpriteSizing.exitMarker` retains its existing 25.6-point source box at minimum playable height. The PNG already contains its isometric angle.

The physical-iPhone production build succeeded. [Build log](iphone-build.log) · [Compiled crown rendition](compiled-crown-renditions.json) · [Asset source, exports, and readability record](../../../../in-defense-of-history-data/ArtReadability/reports/gold-crown-exit-2026-09-10/README.md).

The isolated device check used the production view and the exact catalog from this build, preserving the user's game save data. The temporary check app was removed after capture.

**PASS on the physical iPhone:** all 26 authored exits across 15 campaign levels use the new crown. All 52 raster-bound comparisons (1× and 3×) agree with authored centers within two raster pixels. The minimum source box remains 25.6 points, with no additional vertical squeeze. [Device results](exit-markers.json) · [Raster bounds](raster-checks.json) · [Probe run](probe-run.log).

The device-loaded catalog image is 288 × 288 pixels and matches the exported crown with exact alpha and at most one 8-bit value of premultiplied color round-trip error. [Comparison](device-catalog-comparison.json).

**PASS for familiar-agent visual review:** native minimum captures of Battle Road, Trenton and Charleston show the gold crown/cross and red inset distinctly on grass, dark endpoint foliage and snow. The normal 852 × 393-point Charleston capture was also inspected. [Unscaled minimum crops](minimum-crown-proof.png) · [Full normal phone view](device-documents/level_15_charleston-device@1x.png) · [Review record](review.json). No Simulator was used. Independent player recognition and comprehension of the exit meaning remain unmeasured.

The production app was successfully installed on the user's iPhone after verification. [Install receipt](install.json) · [Launch receipt](launch.json). The source build retains the existing actor-isolation warnings in `LevelRunner` and `HeroSelection`; neither arises from this asset/view change.
