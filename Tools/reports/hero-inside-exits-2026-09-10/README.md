# Hero placement inside exits

Implemented in `Engine/Layout/HeroExitPlacement.swift` and connected to the initial/respawn node in `LevelRunner`. Heroes follow the assigned destination's incoming path back to a clear visible station. The whole fixed sprite frame, map boundary, foreground alpha, and shared-exit separation determine clearance.

- Host suite: PASS, 126 tests. See `host-tests.log`.
- Production and diagnostic physical-iPhone builds: PASS.
- Level 15: PASS, 12 completed device loads across pair/solo/ranking changes and four viewport inputs. See `hero-exits.json` (run ID `hero-inside-exit-level15-final`). Initial placement, clear sprite bounds, respawns, and resize stability checked.
- Full campaign attempt: INCOMPLETE. Reached 174/180 progress, then timed out without a final result. Do not treat that attempted sweep as a pass.
- Visual review: PASS for initial visibility in the calibrated minimum proof and the actual phone capture. The diagnostic capture is portrait; landscape capture was not measured.
- Production installation and launch: PASS. See `production-install.json` and `production-launch.json`.

Review evidence: `../../../../in-defense-of-history-data/ArtReadability/reports/hero-inside-exits-2026-09-10/README.md`.
No Simulator was used. Independent player recognition and user acceptance remain unmeasured.
