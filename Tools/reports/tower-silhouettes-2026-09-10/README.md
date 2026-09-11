# Ranged gun silhouette revision: runtime verification

The gun was regenerated around a broad shoulder stock and thick barrel. Ranged menu artwork now uses 80% of the button side, shared by the game and editor. The asset catalog retains its existing name and 128/256/384 pixel exports. Other families keep 66% scaling.

## Results

- `iphone-build.log`: physical-device game build succeeded.
- `editor-build.log`: macOS editor build succeeded.
- `compiled-ranged-menu-check.json`: expected compiled gun renditions present.
- `probe-run.log` / `ranged-check.json`: all six ranged variants completed real build/upgrade confirmation actions; menu and map asset sizes verified.
- `tested-source-hashes.json`: all 35 recorded files matched the production sources after the device probe.
- `probe-uninstall.json`, `install.json`, `launch.json`: temporary probe removed; normal updated game installed and launched.

The temporary app uses production private `TowerMenuItem` and `UpgradeMenuItem` views via a wrapper appended only in its staged source copy. Its fixture grants money/unlocks and invokes production actions. No fixture changes are in the game sources. No iOS Simulator or physical tap automation was used.

The iPhone captured its 373 pt playable height and the minimum 340 pt height, at 1×, 2× and 3×. At the minimum, menu buttons are 49.3 pt, ranged art is 39.44 pt square, branch art is 29 pt high and map art is 36.336 pt high. At the device's height those art dimensions are 43.268, 31.815 and 39.863 pt. The minimum component row and real build/branch menus were visually inspected for recognizable stock/barrel, frame clipping and cost-label overlap.

## Evidence

- [Minimum menu components](device-documents/menu-components-minimum@1x.png)
- [Minimum live build menu](device-documents/build-menu-minimum@1x.png)
- [Minimum live branch menu](device-documents/branch-menu-minimum@1x.png)
- [Minimum ranged roster](device-documents/all-ranged-minimum@1x.png)

The data repository holds the complete 25-asset black silhouette audit, research application, old/new gun comparison and production prompt at `ArtReadability/reports/tower-silhouettes-2026-09-10/README.md`. Basic-family separation was reviewed; no blind recognition score or unique silhouette for every within-family upgrade is claimed.
