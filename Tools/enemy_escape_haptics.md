# Enemy escape haptics

## Device audition selection — September 8, 2026

The user found the previous system warning pattern too similar to the tower
build action on a physical device. That invalidates the earlier assumption that
different system semantic labels supplied enough perceptual separation. The
earlier automated tests checked event delivery, not tactile discrimination.

After comparing 20 patterns on-device, the user selected Heavy thud for building
and Long low rumble for escapes, with the rumble shortened from 450 to 400 ms.
The temporary audition is disabled but retained for later comparisons.

| Action | Authored pattern | Intensity / sharpness |
| --- | --- | --- |
| Build or upgrade | Audition #3: one transient Heavy thud, with a firmer attack | 1.0 / 0.35 |
| Enemy escape | Audition #9: one continuous Long low rumble, shortened to 400ms | 0.85 / 0.08 |
| Last life lost | Retained final-life signal: two 280ms rumbles, starting at 0 and 400ms; 120ms silence between them | Peak 0.8 / 0.12 |

Build keeps the audition's single transient and 80ms authored duration. A
follow-up request for a slightly stronger build increases sharpness from 0.2 to
0.35; intensity is already at Core Haptics' maximum of 1.0. Apple's design talk
below distinguishes amplitude from sharpness: this adjustment targets a more
pronounced attack, not a claimed increase in actuator amplitude. Its perceived
strength needs device comparison. The saved audition #3 remains unchanged.
Escape retains #9's constant intensity and low sharpness,
with no added fade or envelope. Only its duration changes. The separate defeat
pattern remains 680ms total, with each rumble rising over 15ms, falling to 85%
gain at 100ms, then fading to zero at 280ms.

## Research basis

[Apple's Designing Audio-Haptic Experiences](https://developer.apple.com/videos/play/wwdc2019/810/)
describes transients as compact taps and continuous events as sustained
sensations. Lower sharpness produces a rounded/rumble-like character; higher
sharpness produces a crisp, mechanical character. This supports separating
the two actions using event structure as well as texture.

[Brown, Brewster, and Purchase, A First Investigation into the Effectiveness of Tactons](https://www.dcs.gla.ac.uk/~stephen/papers/WorldHaptics_Brown.pdf)
evaluated rhythm and vibrotactile roughness as distinguishable information
dimensions. This motivates the larger temporal difference here. Their tests
used different actuators, and roughness in that study is not equivalent to
Core Haptics sharpness. Their recognition rates do not establish how well this
particular iPhone pattern will be recognized.

[Apple's haptic guidance](https://developer.apple.com/design/human-interface-guidelines/playing-haptics)
supports consistent cause/effect, short and sparing feedback, and an opt-out.
The existing life counter supplies the visual feedback. **Life-loss haptics**
remains enabled by default and can be disabled in Settings.

## Playback and lifecycle

`GameplayHapticPattern` defines all three patterns. The runner's existing
Core Haptics engine plays them. `LevelMapView` observes the actual escape-event
counter and requests the appropriate custom cue through `EnemyEscapeHapticPolicy`.
The system `.warning` sensory-feedback modifier has been removed.

Loss cues interrupt the current build player. Builds requested during a loss
cue still build normally, but their haptic is suppressed so it cannot mix into
the loss rhythm. Defeat interrupts an ordinary loss cue. Each playback creates
a fresh player and restarts an idle engine as needed. Reset recovery does not
replay old events; see [Apple's engine lifecycle guidance](https://developer.apple.com/documentation/corehaptics/preparing-your-app-to-play-haptics).

Ordinary loss feedback remains limited to once per 0.5 seconds of monotonic
real time. Suppressed events are discarded, never queued. That limit is a
game-design comfort choice, not a measured universal threshold. The final-life
cue bypasses the limit. Simulation shutdown on defeat leaves haptics active
while the game-over view is visible; leaving or backgrounding the level stops
the player and engine immediately.

If custom playback is unavailable or fails, build falls back to system success
and losses fall back to system error. The two-pulse warning is never used.
Fallbacks are a degraded mode and cannot reproduce the authored rumble.

## Verification and remaining uncertainty

`GameplayHapticPatternTests` compares build with the Heavy thud audition export after changing only sharpness,
and escape with the Long low rumble export after changing only its duration. It also checks
structural separation of loss patterns, the inter-rumble gap, valid parameter
ranges, no audio events, and actual Core Haptics export/import round trips.
Existing policy tests cover bursts, final-life priority, muting, inactivity,
and load/reset behavior.

`Tools/check_haptic_playback.py` executes the production playback and stop/loss
methods with spy hardware. It checks preemption, build suppression during loss,
defeat playback surviving simulation shutdown, full cancellation on exit,
fallback behavior, and fresh playback after recovery.
`Tools/check_enemy_escape_feedback.py` checks the actual crossing loop and loss
event with fixture paths.

`HapticAuditionTests` also checks that the production default cannot autoplay,
while the retained audition still sequences and cancels correctly when enabled.
Earlier research-stage evidence in `Tools/reports/distinct-haptics-2026-09-08`
predates the audition selection. The user's device comparison informed this
selection; the shortened 400ms escape still needs to be felt on-device. Automated
checks establish construction, routing, and lifecycle behavior.
