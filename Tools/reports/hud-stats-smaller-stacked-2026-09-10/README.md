# Smaller HUD with centered wave row

The production HudStatsView now scales its resolved icons, text, plates, padding, corner radii and spacing uniformly by 0.88. Lives and money occupy the top row; the current/total wave plate is centered beneath their combined width. Both rendered layout bounds and occupiedFrame use the scaled two-row size. White live values, 72% black backing and the accepted margins remain in place.

At minimum runtime size, each plate is 29.24416pt tall (previously 33.232pt), text is 17.1465712pt (previously 19.48474pt), and gaps are 6.82pt. The complete stack is approximately 188.77 × 65.31pt. The total stack height changes with the requested row arrangement; the 12% reduction applies to each element.

Native 1× output was reviewed before the enlarged 3× view. The heart remains clearly recognizable, the coins retain visible stacked rims and a gold face, and the white values read clearly on grass and snow. All plates retain equal height and vertical margin. The wide fixture 99 / 9,999 / 99 of 99 fits. The existing readability lab was run; minimum-readability.png uses its color, grayscale and silhouette transforms with spacing appropriate for a HUD. Reviewer result: PASS for the requested layout and minimum-size readability; independent user acceptance remains unmeasured.

geometry-evidence.json records 3× raster measurements against the previous accepted HUD. Width ratios are within raster rounding of 0.88. The top row and wave plate have the same measured horizontal center (283px). Source sizing uses the exact scale factor 0.88.

Signed production and capture builds passed. A separate temporary app rendered the production HUD on the physical iPhone 15 Pro and captured actual gameplay. The native screenshot and HUD crops were visually inspected: the wave row is centered beneath lives and money, the three plates match in height, and the smaller icons and labels remain readable. Real runner wave progression passed for all 15 campaign levels (stats.json). The updated regular game was installed and launched successfully, and the diagnostic app was removed; see device-workflow.log, install.json and launch.json. No Simulator was used.

The host renderer uses explicit value fixtures and macOS font rendering; physical-device captures are separately identified in device-documents. Input/capture hashes are preserved. Temporary copied SQLite databases were removed after hashing; the original game database is untouched.
