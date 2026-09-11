# Temporary launch haptic audition

The panel and automatic playback are currently disabled; the code and all 20
original samples remain available for future comparisons. Set
`HapticAuditionPlayer.enabled` to `true` to enable them again.

When enabled, the campaign/main screen plays 20 numbered Core Haptics patterns
once per app launch. Each pattern's completion callback starts a 1.25-second silent
gap before the next pattern. The panel shows the current number and description,
with Stop, Replay all, and Replay one controls. Leaving the screen or making the
app inactive cancels playback; returning does not automatically restart it.

This is a physical-device comparison, not a claim about Kingdom Rush's effect.
The patterns vary intensity, sharpness, duration, rhythm, and intensity envelope.
Unsupported hardware shows a message instead of substituting a different signal.
The audition runs independently of gameplay settings. The temporary `.error`
override in `LevelRunner.playHaptic` has been removed. Gameplay now uses #3,
Heavy thud, with sharpness increased from 0.2 to 0.35 for a firmer build/upgrade,
and #9, Long low rumble, shortened to 400 ms for
enemy escapes. The saved audition retains #9's original 450 ms duration.

| # | Pattern |
| --- | --- |
| 1 | Original build double tap (reference) |
| 2 | Sharp crack |
| 3 | Heavy thud |
| 4 | Soft tap |
| 5 | Rounded thump |
| 6 | Quiet buzz, 80 ms |
| 7 | Heavy buzz, 140 ms |
| 8 | Previous escape rumble, 280 ms (reference) |
| 9 | Long low rumble, 450 ms |
| 10 | Crisp buzz, 200 ms |
| 11 | Two soft taps, 120 ms apart |
| 12 | Two hard knocks, 180 ms apart |
| 13 | Three even knocks |
| 14 | Accelerating taps |
| 15 | Slowing taps |
| 16 | Two short rumbles |
| 17 | Five-part rattle |
| 18 | Fading rumble, 400 ms |
| 19 | Rising rumble, 400 ms |
| 20 | Sharp impact with a low tail |

Stable numbers and definitions live in
`Engine/Models/HapticAuditionSample.swift`; sequencing and engine ownership live
in `Engine/Debug/HapticAuditionPlayer.swift`. The panel overlays the campaign map
without participating in its layout.

`HapticAuditionTests` validates all 20 actual Core Haptics patterns and tests order,
completion-based gaps, cancellation, replay isolation, and hardware errors using
a controlled playback backend. These checks cannot verify physical sensation.
