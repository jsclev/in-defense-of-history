# Enemy escape haptics

Haptic feedback is reserved for enemies crossing an exit. Tower building,
upgrading, campaign markers, menus, and hero buttons produce no haptics. The
temporary audition panel, player, and sample library have been removed.

## Retained patterns

| Exit event | Pattern | Intensity / sharpness |
| --- | --- | --- |
| Ordinary enemy escape | One continuous low rumble, 400 ms | 0.85 / 0.08 |
| Enemy escape taking the last life | Two 280 ms rumbles, starting at 0 and 400 ms | 0.8 / 0.12 |

The ordinary escape keeps the constant intensity and low sharpness selected
during the earlier device comparison. The final-life pattern lasts 680 ms,
including a 120 ms gap. Each of its rumbles rises over 15 ms, falls to 85%
gain at 100 ms, then fades to zero at 280 ms.

## Trigger and lifecycle

`LevelMapView` observes `escapedEnemyCount`, which advances when an enemy crosses
its path's exit. `EnemyEscapeHapticPolicy` requires a new escape, an active scene,
and the **Life-loss haptics** setting. Loading, counter resets, and returning
to the app do not replay feedback. The setting remains enabled by default.

`LevelRunner.playEnemyEscapeHaptic` is the only playback entry point. Its two
patterns are defined in `GameplayHapticPattern`. Ordinary losses are limited
to once per 0.5 seconds of monotonic real time; suppressed events are discarded.
The final-life escape bypasses this limit and interrupts an ordinary loss cue.

Each request creates a fresh player and restarts an idle engine as needed.
Engine reset recovery never replays a previous cue. Simulation shutdown on
the final-life escape allows its haptic to finish; leaving or backgrounding
the level stops the player and engine immediately.

If custom playback is unavailable or fails, the same escape event falls back
to system error feedback. This fallback cannot reproduce the authored rumble.

## Verification

`GameplayHapticPatternTests` checks the retained escape parameters, the
final-life gap, valid parameter ranges, and Core Haptics export/import round
trips without audio. `EnemyEscapeHapticTests` covers bursts, final-life priority,
muting, inactivity, and load/reset behavior.

`Tools/check_haptic_playback.py` exercises the production playback and stop/loss
methods with spy hardware. Pass `--build-path` to the SwiftPM debug directory
containing `Modules` and `LevelEditorFormats.build`. It checks final-life
preemption, inactive suppression, completion after simulation shutdown,
cancellation on exit, error fallback, and fresh playback after recovery.
`Tools/check_enemy_escape_feedback.py` covers the production crossing loop
with fixture paths. These automated checks do not measure physical sensation.
