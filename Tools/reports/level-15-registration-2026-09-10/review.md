# Level 15 path and marker registration — September 10, 2026

The path layer was stale. Regenerated `level_15_charleston_path.png` from the latest
GeoJSON using the existing painted soil material, 3× supersampling and the same
4-source-pixel feather. The resulting alpha exactly matches the regenerated
GeoJSON road mask. 772,167 source pixels changed. Authored geometry was preserved.

The game and call-wave HUD now use the same `LevelMapProjection`. Call-wave
centers were already algebraically correct; sharing the implementation prevents
the two layers from drifting apart. Removed the crown's legacy crop offset:
its tightly cropped visible image is now centered on the authored exit point.
Its size and artwork are unchanged. Heroes still render above exits.

## Evidence

- `path-verification.json`: source/output hashes, dimensions and exact alpha check.
- `verified-placement.json`: production loaders and eight production SwiftUI view
  renders on John's physical iPhone 15 Pro. Both exits and both buttons are tested
  at the physical viewport and a 604×340 logical-point stress viewport (339.75 pt
  fitted play height, with sprite minimum clamped to 340).
- Device confirmed the bundled GeoJSON and path PNG hashes equal the current files.
- Shared projection tests exercise phone, tablet, portrait and minimum-size fits,
  asymmetric safe areas, fractional coordinates and coordinates beyond the play area.
- `placement-tests.log`: 15 placement/canvas tests passed. Two existing Charleston
  data-consistency tests fail because the exported route assignments and the old
  database routes disagree (46 assertions). This is separate from marker projection.
- `device-documents/level-15-device.png` and `level-15-minimum.png`: actual game view
  captured on physical iPhone; first-wave button is shown on its incoming route.
  Both authored buttons were also rendered and measured individually.
- `lab/index.html`, `lab/roster-minimum.png`, `lab/evidence.json`: calibrated art
  review at 24.533 pt visible crown image height, with source hashes.

## Visible-center measurement

Alpha >= 128 bounds measured on 3× SwiftUI renders; signed differences are in
logical points from the exact projected authored center. These subpixel errors
are raster rounding, not intentional placement offsets. Maximum error < 0.2 pt.

| Viewport | Marker | GeoJSON point | Error x, y (pt) |
| --- | --- | --- | --- |
| minimum | exit 1 | [2366, 1304] | -0.025, 0.067 |
| minimum | exit 2 | [1634, 552] | -0.083, 0.000 |
| minimum | call-wave 1 | [538, 1280] | -0.133, -0.150 |
| minimum | call-wave 2 | [1218, 1460] | -0.050, -0.192 |
| device | exit 1 | [2366, 1304] | 0.115, -0.059 |
| device | exit 2 | [1634, 552] | -0.074, -0.111 |
| device | call-wave 1 | [538, 1280] | 0.119, -0.015 |
| device | call-wave 2 | [1218, 1460] | -0.067, -0.181 |

## Visual review

Inspected the native logical-size phone/minimum captures and the lab's color,
grayscale and silhouette proof before any magnified review. The regenerated
soil paths remain continuous with clear grass boundaries at minimum size. The
red/gold horn ring and red-edged gold crown retain distinct silhouettes and color
regions on the Charleston background. The crown's cross and broad red inset
remain visible. The primary hero intentionally overlaps the lower exit because
its authored start is almost coincident; the hero correctly draws above the crown.
This is an author review, not a blind recognition study or a full combat playthrough.

## Remaining route-data discrepancy

The latest GeoJSON gives both entrance/exit pairs and every wave pathIndex 0;
the database retains the former left-to-bottom and top-to-right routes and mixed
wave assignments. Database route endpoints are older than the current markers:
left entry (495.65,1221.96) vs (510,1276); bottom exit (1587,549) vs (1634,552);
top entry (1224,1495) vs (1214,1496); right exit (2370,1235) vs (2366,1304).
Some old route waypoints also fall outside the edited road area. Clarification
requested on whether the level should retain both routes before changing routing.

## Deployment

Production iPhone build succeeded. Bundled GeoJSON/path hashes match the tested
files (`game-bundle-verification.json`). Installing it over the game was blocked
by automatic approval review pending explicit user confirmation. The separate
physical-device probe was installed and all eight render checks completed.
