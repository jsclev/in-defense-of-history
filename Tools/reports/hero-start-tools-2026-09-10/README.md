# Hero starting-position tools — September 10, 2026

Added separate primary (person + 1) and secondary (person + 2) toolbar tools.
Each role has one start that can be placed anywhere, dragged, nudged or edited
through X/Y. Placing secondary enables two heroes. Native and GeoJSON files
preserve the points; gameplay and respawns use them verbatim. Legacy maps keep
their exit assignments until an explicit start is placed. Resetting uses the
assigned exit again. All edits participate in the document undo history.

Map badges are 38 × 32 points with 27 × 19 point icons; toolbar icons are
27 × 19 points. Their size is constant across zoom levels. Yellow 1 and cyan 2
have large, distinct numerals and a clear person silhouette, also distinguishable
without color. Nearby badges separate; edge badges remain within the canvas.
Dragging preserves the offset between the badge and its actual foot anchor.

## Verification

- 131 host tests passed, including five new tests covering persistence and
  replacement, mixed legacy/custom roles, disabled-role export, exact runtime
  positions, invalid/duplicate assignments, and undo/redo.
- macOS editor, iOS editor and physical-iPhone game targets compile successfully.
  No Simulator was launched.
- Visually inspected `hero-icons-1x.png` first at native size. Both numerals and
  person silhouettes are clear in light/dark toolbar samples and map colors.
  `hero-icons-2x.png` records Retina output. These are offscreen SwiftUI renders
  of the production `HeroPlacementIcon.swift`, using `IconProbe.swift` and the
  actual shared engine role enum. They are editor UI symbols, not gameplay art.
- Live editor interaction could not be checked: both attempts to use the native
  computer-control connection failed with “native pipe closed before response”.
  No on-device gameplay verification was performed for this editor change.

Build/test logs are saved alongside this record. Build products are in
`/tmp/hero-placement-build/Build/Products/Debug/LevelEditor.app` and
`/tmp/hero-placement-game-build/Build/Products/Debug-iphoneos/`.
