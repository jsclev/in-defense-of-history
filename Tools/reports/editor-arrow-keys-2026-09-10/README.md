# Level Editor arrow-key repair — September 10, 2026

The canvas used SwiftUI onMoveCommand, which depends on responder focus. Inspector selection did not return focus to the canvas; toolbar and ScrollView focus could also consume the arrows.

The Mac editor now uses a local key-down monitor scoped to the active document window. Only unmodified arrows with a valid movable selection are consumed. Text input, other windows, sheets, hidden or detached canvases, unrelated keys and modified shortcuts pass through. Held-key repeat nudges normally. Explicit inspector selection requests canvas focus, including selecting the same row again after editing coordinates. Existing movement, grid snapping and undo code are unchanged.

Validation:
- Seven AppKit keyboard-routing regression tests passed (all four directions, off-canvas focus, SwiftUI hosting responder, text-field editing, multiple windows, shortcuts, repeat, selection changes, detach/hide).
- The AppKit tests require normal window-system access: sandboxed hidden NSWindows have window number zero, so synthetic events cannot resolve their window. The successful run used normal access, with hidden test windows and no input sent to user applications.
- Full host suite: 131 test cases; 129 passed, two CharlestonWaveTests failed with 46 assertions. The current Charleston GeoJSON does not agree with the native map/database on route indices and several coordinates. None of those data files were edited for this keyboard fix.
- LevelEditor Debug macOS build succeeded in both default Xcode DerivedData and /tmp/hero-placement-build.
- Live UI verification/restart blocked: Computer Use returned “Sky Computer Use native pipe closed before response,” including after a session reset. Open editor documents were left running; save and quit/reopen to load the rebuilt executable.
