# Eraser unit and integration coverage — September 10, 2026

Expanded the eraser suite from 10 to 28 tests: 16 geometry/model tests and 12 integration tests. The canvas now uses EditorPaintGesture for preview sampling, coordinate conversion, cancellation and one-time commit. Integration tests call that production handler with real MapDocument edits, UndoManager, and temporary native/GeoJSON files; they do not duplicate its implementation.

Coverage includes circular footprint across brush widths, wide path edges, painted dabs, fast sparse strokes, overlaps, holes/islands, repeated erasure, full erasure, repainting, invalid inputs, zoom/pan and y-axis conversion, final mouse-up sample below sampling spacing, no-op edits, cancellation with late callbacks, duplicate release, single-dab clicks, one-gesture undo/redo, independent documents, and persistence. Preservation tests keep towers, hero starts, entrance/exit/call-wave markers, embedded images, wave data and intended builds intact.

A new test exposed roundoff-driven changes from repeating the same erase. Committing the polygon actually persisted and skipping already-covered masks prevents those redundant edits. The release test also requires inclusion of the final pointer sample even when it is closer than preview sampling spacing.

Verification:
- 28 eraser tests passed.
- Tools/check_level_editor.sh: 79 editor regression tests passed, including keyboard movement, lifecycle, GeoJSON, hero starts and call-wave markers.
- Both macOS LevelEditor builds succeeded (default Xcode DerivedData and /tmp/hero-placement-build).
- Full host suite: 159 cases, 157 passed. The same two CharlestonWaveTests fail because current authored GeoJSON differs from native-map/database data (45 assertions). No authored maps or database data were edited.
- Fault-injection check in a disposable source copy: disabling native cutout application is detected by the road-edge test; dropping the final release sample is detected by the release integration test. Both compiled successfully and failed the expected assertions. Production source was never changed for these fault injections.

Project AGENTS.md now requires the editor regression command and macOS build for LevelEditor changes. Run Tools/check_level_editor.sh from a normal macOS session; AppKit keyboard tests create hidden windows. These are host unit/integration checks, not live UI automation or OS event-dispatch tests.
