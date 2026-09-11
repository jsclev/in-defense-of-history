# GeoJSON-only tower slots — September 10, 2026

The screenshot showed 16 stale SQLite slots while the re-export contained 18.
`TowerSlotDAO` and all dependencies were removed. `LevelInfoDAO` now returns
metadata; `LevelLoader` composes playable levels with slots from `LevelGeoJSONDAO`.
Gameplay and the macOS balancing executable both use that shared loader.
Missing/malformed GeoJSON fails loading; no SQL fallback exists.

Removed the SQL table, all 15 level seed blocks, and slot SQL generation/validation
from asset-workspace tools. The bundled database was migrated with every other
table verified unchanged; `before.sqlite` is the pre-migration backup.
A complete fresh database build passes integrity and foreign-key checks.

Verification: all 15 maps matched their exact authored positions on physical
iPhone. Charleston loaded 18 slots and built a tower at slot index 17, at the
exact authored position, through the real select/arm/confirm path. Both device
and 340-point minimum screenshots were inspected. Readability lab re-run and
minimum color/grayscale/silhouette proof inspected; no art or sizing was changed.
The temporary probe app was removed. iPhone game, macOS editor and balancing
targets compile successfully. Detailed results: `verification.json`.

Host suite: 164/166 test cases passed, including all five new slot regressions.
The two existing CharlestonWaveTests still fail (46 assertions): current GeoJSON
entrance/exit points and path area disagree with unchanged database routes,
and exported wave route indices disagree with the native map/database. Those
fields were not modified in this slot fix. `host-tests.log` retains the failures.
