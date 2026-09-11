# Distinct gameplay haptics — September 8, 2026

[Research, design, and implementation](../../enemy_escape_haptics.md)

The previous system warning was rejected after the user's physical-device comparison with tower building. This revision changes the event type, duration, rhythm, and sharpness. It does not treat different API labels as proof of perceptual separation.

- Build: original two transient taps at 0 and 55ms.
- Escape: one low-sharpness continuous 280ms rumble with a fade.
- Defeat: two 280ms rumbles separated by 120ms.

Actual Core Haptics exports are `build.ahap`, `lifeLoss.ahap`, and `defeat.ahap`. They were generated from production code and decoded again in tests. These describe requested signals, not captured actuator waveforms.

17 selected Swift tests pass. The production playback harness verifies preemption, loss priority over builds, cancellation on exit, uninterrupted defeat feedback after simulation shutdown, fallback, and recovery. The production exit-crossing harness also passes. The unsigned iPhone app build succeeds.

Physical feel of this revision is not measured here. The new structure supplies deliberate differences for the next on-device comparison; source shape and passing tests do not certify human discrimination.
