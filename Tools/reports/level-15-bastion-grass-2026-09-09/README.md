# Level 15 grass verification

Charleston now loads the new Bastion grass through its existing
`Levels/level_15_charleston.heic` resource. Its retained background PNG is an exact
copy of `Levels/grass_bastion.png`; canvas size remains 2868 × 2064.

- Production iPhone build passed (`iphone-build.log`).
- Final bundled map resources match their workspace exports byte for byte.
- The physical-iPhone probe used production LevelMapView/LevelMapArt for level 15.
  It recorded the final HEIC hash in `tested-map-sha256.txt` and validated image
  dimensions in `grass-check.json`.
- Inspected `device-documents/charleston-minimum@1x.png` (604 × 340pt fixture) and
  `charleston-device@1x.png` (852 × 393pt device window). The new grass has clear
  painted color masses beneath the road, tower sites, heroes, exits and HUD.
  The road remains a continuous, clearly separated shape at minimum size.
  Matching 3× captures are also saved.
- Game installation and launch succeeded (`install.json`, `launch.json`).
  The temporary probe app was uninstalled after capture.

The existing calibrated art lab, grayscale and minimum-size proofs, unchanged
layer hashes and background backups are in
`in-defense-of-history-data/ArtReadability/reports/level-15-bastion-grass-2026-09-09`.
This is self-review of physical-device captures, not independent player testing.
