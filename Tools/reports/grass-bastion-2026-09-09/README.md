# Grass artwork integration — September 9, 2026

The generated grass source is `in-defense-of-history-data/Levels/grass_bastion.png`,
exported at 2868 × 2064. The existing Battle Road compositor consumes it and
produces `Levels/level_01_battle_road.heic`, preserving all other authored layers.
The game already bundles Levels and loads this map name through LevelMapArt.

Validation completed:

- Final physical-iPhone build succeeded (`iphone-build.log`); existing app-icon
  and Washington asset checks completed as part of the build.
- New grass, final map, overlay and forest-occlusion resources in the built app
  match their workspace counterparts byte for byte (asset review's
  `bundle-verification.json`).
- Temporary physical-iPhone probe rendered production LevelMapView at the actual
  852 × 393pt device window and a 604 × 340pt minimum fixture, at 1× and 3×.
- `tested-map-sha256.txt` matches the final exported map; `grass-check.json`
  reports successful native loading at 2868 × 2064.
- The final probe reused the final game's compiled catalog (`compiled-catalog.json`)
  to avoid recompiling unchanged sprite artwork. It loaded the final map files.
- Inspected both final 1× captures: broad grass color masses remain visible,
  while the road, markers, HUD and player-facing controls remain distinct.
- Final game installation and launch completed (`install.json`, `launch.json`).
  The temporary probe app was uninstalled after its captures were saved.

The art reference choices, exact built-in image_gen prompt, export dimensions,
1×/2×/3× diagnostic proofs, existing readability lab, input hashes and self-review
are in `in-defense-of-history-data/ArtReadability/reports/grass-bastion-2026-09-09`.
No simulator was used. Screenshot self-review does not measure an independent
player preference study or a human's perception of the physical display color.
