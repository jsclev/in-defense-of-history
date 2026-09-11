# Charleston image synchronization: physical-device evidence

The normal game build succeeded with the corrected 2868 × 2064 path PNG and latest GeoJSON. `production-bundle-check.json` confirms that both bundled resources equal the workspace sources.

The isolated physical-iPhone probe compiled production `LevelMapView`, `LevelMapArt`, `RuntimeCanvas` and the current button loader. It verified exact path and GeoJSON SHA-256 values plus the authored centers `(538,1268)` and `(1330,1456)`. It captured the actual 852 × 393-point window and 604 × 340-point minimum fixture at 1× and 3×. Both 1× images were visually inspected; the corrected entrances and loops align with the exported polygon and road remains clear from grass. The temporary probe was removed.

- [Phone capture](device-documents/charleston-device@1x.png)
- [Minimum capture](device-documents/charleston-minimum@1x.png)
- [Device assertions](paths-check.json)
- [Production bundle check](production-bundle-check.json)
- [Exporter regression tests](exporter-tests.log)
- [Production build](production-build.log), [probe execution](probe-run.log)
- [Game installation](install.json)
- [Art review](../../../../in-defense-of-history-data/ArtReadability/reports/charleston-path-sync-2026-09-10/README.md)

This verifies the image fix against the current exported GeoJSON, not unsaved editor state. No simulator was used. Familiar-agent inspection does not establish independent human acceptance. The separate `waypoint-audit.json` records that the database's enemy routes remain older than the new polygon; navigation was not changed by this image correction.
