# Level Editor eraser repair — September 10, 2026

The previous native eraser cut centerlines and shortened the resulting road pieces to account for round end caps. It missed visible road/paint edges when the brush did not reach the centerline, and could remove material beyond a small circular dab. During a drag the canvas only overlaid a red stroke instead of previewing the subtraction.

The eraser now subtracts the actual circular stroke from visible surfaces. Native roads and paint retain combined cutout polygons in optional erasedArea fields, keeping waypoint editing and wave indices intact. Later paint can refill cutouts. Imported areas are cut directly; an empty imported layer retains its identity so repainting does not reset route indices. Display and export use the cut surfaces. Native saves preserve cutouts and undo/redo restores the complete stroke in one step.

Preview uses the same footprint as the committed edit. Route guides are clipped to the remaining area. Brush turns are normalized with the winding fill rule before polygon flattening, avoiding accidental holes where round stroke joins overlap. Mouse-up includes the final sample, and the eraser cursor follows the drag position.

Validation:
- Before change: three new geometry tests reproduced four failing assertions (edge overlap, painted dab/edge overlap, and excess center-dab removal).
- After change: 35 focused tests passed (10 eraser tests plus 25 GeoJSON tests), covering overlapping surfaces, sharp turns, preview/commit agreement, preservation of route data, native and GeoJSON persistence, repainting, full erasure/repaint, legacy erase order, and undo/redo.
- Full host suite: 141 test cases, 139 passed. The two existing CharlestonWaveTests still fail because current GeoJSON differs from the native map/database (45 assertions). Keyboard-routing tests pass. No map or database files were modified for this fix.
- Both Debug macOS editor builds succeeded: default Xcode DerivedData and /tmp/hero-placement-build.
- eraser-proof.png was generated from the production geometry code by Tools/EditorEraserProbe.swift and visually inspected: live and committed cuts match, including the road edge and angled stroke. This is an offscreen geometry proof, not a screenshot of the user's editor.
- Computer Use still returns “Sky Computer Use native pipe closed before response.” Live UI verification and a safe save/restart could not be performed. Existing editor windows were left running; save, quit and reopen to use the updated binary.

Run the geometry tests with swift test --filter 'EditorEraserTests|LevelGeoJSONTests'. The full suite requires normal window-system access for the hidden-window AppKit keyboard tests. Compile the proof against the current LevelEditorFormats object paths from the package's Objects.LinkFileList; globbing every object may include stale files from removed source.
