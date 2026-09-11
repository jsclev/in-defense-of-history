# Ranged artwork integration

All six ranged tower variants and the ranged build-menu musket were regenerated with the built-in ImageGen tool and installed at their existing asset names. Ranged menu buttons now use the existing blue-and-gold frame through `TowerKind.menuFrameName`, shared by the game and editor.

Artwork, exact prompts, alpha/export hashes, reference dimensions and visual acceptance notes: [Bastion Painted V5](../../../../in-defense-of-history-data/Towers/Ranged/Bastion%20Painted%20V5/README.md).

Verification completed:

- Physical-iPhone game build: `iphone-build.log`, succeeded.
- macOS LevelEditor build: `editor-build.log`, succeeded.
- Seven compiled image names and expected density dimensions: `compiled-ranged-check.json`, passed.
- Actual build/upgrade confirmation actions, six resulting variants, three specialist offers, actual map and menu rendering: `ranged-check.json`, passed on physical iPhone, iOS26.6.1.
- Minimum playable height340pt: tower36.3359pt, menu49.3pt, branch artwork23.925pt. Device playable height373pt: tower39.8626pt, branch artwork26.2471pt. Captures in `device-documents` include 1x/2x/3x output.
- `tested-source-hashes.json` matched production sources after testing. `git diff --check` passed for the three touched Swift files.
- `install.json`, `launch.json` and `probe-uninstall.json` confirm the regular game is installed/launched and the temporary review app removed.

The separately bundled probe copies the game source to a temporary staging directory. Its only runtime instrumentation exposes the runner and grants test funds/level4 unlocks. `MenuProbe.swift.txt` is appended only to the staged view source to access the actual private menu components. The production game does not contain these fixtures. Actions are invoked programmatically; this does not claim a physical tap test or an independent human recognition study.

The first probe selected a top-edge tower slot for the radial-menu capture and exposed existing clipping. The final probe places the level3 fixture in an interior slot so all three branch buttons are visible. Radial-menu positioning is outside this artwork change.
