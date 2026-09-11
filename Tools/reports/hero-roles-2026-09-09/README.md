# Hero roles validation — September 9, 2026

One or two chosen heroes are represented by `HeroSelection`. Higher ranking
determines primary; the other hero is secondary. Equal rankings use stable UUID
order. The model, DAO, preference restoration, menu selection, and gameplay HUD
use this rule. Scripted level rosters retain their existing heroes and path assignments.

Validation completed:

- Eight `HeroRankingTests` passed against an in-memory database loaded from all
  82 production SQL scripts. Coverage includes seed values, database constraints,
  single/pair selection, opposite click orders, rank edits, equal rankings,
  promotion/removal/replacement, invalid choices, rollback after a failed second
  insert, and preference restoration after a content database refresh.
- The production SwiftUI HUD button probe passed with hero unit order deliberately
  reversed relative to ranking. Pointer events exercised primary/secondary
  selection, targeting, death, respawn, and the disabled secondary slot for a
  single hero. Source hashes and exact results are in `results.json`.
- `Liberty Line` built successfully for generic iOS with code signing disabled.
  The initial sandbox build could not access the installed Metal toolchain;
  the normal-access build succeeded.
- All production seeds passed SQLite integrity and foreign-key checks. The bundled
  default selection is Washington (98) in slot 1 and Knox (92) in slot 2.

Commands:

```sh
env CLANG_MODULE_CACHE_PATH=/tmp/td-hero-ranking-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/tmp/td-hero-ranking-module-cache \
  swift test --disable-sandbox --cache-path /tmp/td-hero-ranking-cache \
  --scratch-path /tmp/td-hero-ranking-tests --filter HeroRankingTests
python3 Tools/check_hero_selection.py \
  --build /tmp/td-hero-ranking-tests/arm64-apple-macosx/debug \
  --output Tools/reports/hero-roles-2026-09-09
xcodebuild -project InDefenseOfHistory.xcodeproj -scheme 'Liberty Line' \
  -configuration Debug -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/td-runtime-canvas-device-build CODE_SIGNING_ALLOWED=NO build
```

The button probe runs actual macOS SwiftUI views with fixture units. It does not
measure iOS touch delivery or physical-device gameplay. No art or sprite sizing
was changed or presented for visual acceptance.
