# Charleston painted-path verification

The production build succeeded with the final `Levels/level_15_charleston_path.png`. Its SHA-256 is `26196cfeb4db829522fb3d65348b8e2f16ec0d6f0a2b095d0eb09ad6befd5d48`.

The isolated physical-iPhone probe uses production `LevelMapView`, `LevelMapArt` and `RuntimeCanvas` and reuses the production build's compiled sprite catalog. The phone verified the exact bundled path hash, 2868 × 2064 dimensions and alpha. It rendered the actual 852 × 393pt window and a 604 × 340pt minimum fixture at 1× and 3×. The temporary probe app was uninstalled after capture.

- [Minimum gameplay capture](device-documents/charleston-minimum@1x.png)
- [Normal phone layout](device-documents/charleston-device@1x.png)
- [Device checks and path hash](paths-check.json)
- [Production build log](iphone-build.log)
- [Probe run log](probe-run.log)
- [Game installation](install.json), [game launch](launch.json)

Both 1× phone captures were visually inspected. The warm road stays distinct and follows the original route. Its small edge transition blends into the grass without a raised contour or opaque backing. Heroes, tower sites, exits and HUD remain readable. No Simulator was used. These are familiar-agent capture reviews, not independent player validation.

The full art review, exporter, backups and calibrated lab are in [the asset report](../../../../in-defense-of-history-data/ArtReadability/reports/paths-bastion-grass-2026-09-10/README.md).
