# Tap area guide — September 9, 2026

The tap area is a subset of the runtime play-area polygon. Only the exposed top segment between the upper occlusions moves down by **5% of play-area height**. For the current 1080-unit play height, this is **54 map units**. The side edges, corner shoulders, lower corners, and centered bottom cutout retain their play-area boundaries.

The guide is a thin cyan dotted polygon, drawn over the purple play guide so both colors remain visible along shared boundaries. The game Settings layout-guide key names it **tap area**. The native Mac editor's play-area overlay includes the same guide and updated tooltip.

`VirtualCanvas.tapAreaShape` supplies canonical geometry and `RuntimeCanvas.runtimeTapArea` supplies the corresponding screen-coordinate polygon. The runtime version uses the same full-screen-width bottom occlusion as the play area. These are reusable placement regions; this change adds the geometry and its guide consumers. Individual element placement and gesture policies remain in their existing layout code.

The top exclusion spans only the exposed segment. Tests also cover shallow top occlusions, where clipping the entire polygon to a shorter rectangle would incorrectly move the corner shoulders. If the top edge is fully occluded, the tap and play areas coincide. Empty top occlusions expose the full top width.

Verification:

- All **121 host-side Swift tests passed**, including four new tap-area tests.
- Signed physical-iPhone build passed; native Mac LevelEditor build passed.
- Inspected the actual SwiftUI debug guide in host renders at minimum, phone, and tablet sizes. The cyan top segment is visible below the purple segment, and both guides retain all cutouts.
- No Simulator was used. Host renders are layout proofs, not on-device gameplay screenshots.
- Physical-iPhone installation and launch results are retained in `install.json` and `launch.json`.

| Fixture | Play height | Tap top inset |
| --- | ---: | ---: |
| Minimum | 340 pt | 17 pt |
| Phone, 852 × 393 | 373 pt | 18.65 pt |
| Tablet, 1133 × 744 | 637.3125 pt | 31.865625 pt |

`render.py` builds the proof from the production `DebugLayoutGuidesView` and compiled Engine code, replacing only its unused UIKit import with AppKit for the host. `source-hashes.json` identifies the verified sources. `layout.json`, the build logs, and `swift-tests.log` retain detailed results.

- [Phone guide](phone-guides@1x.png)
- [Minimum guide](minimum-guides@1x.png)
- [Tablet guide](tablet-guides@1x.png)
