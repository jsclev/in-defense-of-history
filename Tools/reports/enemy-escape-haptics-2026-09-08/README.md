> Superseded after device feedback: the system warning felt too similar to tower building. See [the revised patterns](../distinct-haptics-2026-09-08/README.md).

# Enemy escape haptics — September 8, 2026

[Research and behavior](../../enemy_escape_haptics.md)

Escapes request the system warning pattern while lives remain, or the failure/error pattern when the last life is lost. Warnings are limited to one per half-second of monotonic real time. Defeat overrides that limit. Suppressed cues are dropped; no delayed vibration queue exists. A persistent Life-loss haptics setting defaults to on.

Validation:

- 5 feedback policy tests passed: bursts, interval boundary, defeat priority, muting/inactivity, load/reset.
- 8 existing viewport/presentation tests passed.
- The production exit-crossing loop and loss method passed the fixture runner probe, including blocked walkers, separate paths, exact crossing, duplicate prevention, and defeat shutdown.
- Unsigned iPhone build succeeded.
- Settings layout was inspected at 340pt and 402pt height using live macOS SwiftUI hosting snapshots. Done stays outside the scrolling options. These are desktop layout checks, not iOS screenshots; native toggles differ and the fixture version is 0.0.0.
- Physical iPhone sensation/comfort: not measured. Tests establish event delivery and policy; they cannot certify tactile feel.

`validation.json` records source hashes. `runner-results.json` records the production runner probe. `settings-render.swift` is generated from the actual Settings view and HUD metrics with file-backed asset loading; the existing Done-button UIKit press haptic is omitted in the macOS rendering fixture.
