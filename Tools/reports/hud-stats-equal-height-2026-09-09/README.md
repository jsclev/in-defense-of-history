# Taller HUD backgrounds with a shared height

All three plates now use one height: the tallest icon plus statPlatePadding above and below. Lives and money explicitly receive this shared height before their backgrounds are drawn, and the wave plate uses the same value. At minimum size, the plates are 33.232pt tall, giving about 3.1pt margin above/below the money icon and 3.64pt around the slightly shorter heart. The row's occupied frame matches this height.

The wave readout now uses the same 19.48474pt font size as lives and money. Its width reserves `99 of 99` at that larger font. Minimum row width is about 337.57pt. The accepted left margin, separate gaps, dark fill and rounded corners are retained.

Native 1× renders were inspected before enlargement. The backgrounds have matching top/bottom edges, each icon has visible vertical margin, and all values remain readable. The 3× wide-value render fits without clipping. The existing readability lab was rerun, and the supplementary wide sheet uses its color/grayscale/silhouette transforms. Sampled vertical alpha spans through all three rendered backgrounds are exactly rows 0–99 at 3×; see `equal-height-evidence.json`. These host conditions PASS.

Signed production and physical-device capture builds passed. Device captures and installation/launch results are stored alongside this record. Independent user acceptance remains unmeasured.

Physical iPhone 15 Pro verification: inspected the native full gameplay capture and cropped HUD. All three backgrounds have aligned top and bottom edges, the heart and coins have vertical breathing room, and the wave uses the same text size as the other counters. These conditions PASS. The regular game was installed and opened, and the temporary diagnostic removed (`device-workflow.log`, `install.json`, `launch.json`). The source/capture hashes are preserved.
