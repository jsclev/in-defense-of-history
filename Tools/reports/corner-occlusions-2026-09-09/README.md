# Corner occlusion height reduction

The shared `VirtualCanvas` corner-size calculation now reserves 90% of each
HUD region's height. Widths and corner anchors are preserved. The playable path,
tower placement bounds, and tower menu avoidance use these smaller rectangles.

At the current 1920 × 1080 virtual play area:

| Corner | Previous height | New height |
| --- | ---: | ---: |
| Upper left | 205.2 | 184.68 |
| Upper right | 183.6 | 165.24 |
| Lower left | 183.6 | 165.24 |
| Lower right | 183.6 | 165.24 |

The existing hero bar tests now check the actual reduced occlusion, and its
short-height fixture expects the smaller available height. All 83 package tests
passed. The minimum default hero button remains 44.9556 points; the test verifies
this and checks containment across the minimum, phone, and tablet fixtures.

The existing readability lab was rerun using the saved hero HUD source renders
from September 8. The native-size plate was inspected: the two portrait controls
remain distinguishable by hair/headwear and face shapes, and reinforcement and
cooldown states remain distinguishable by crossed weapons and numeric overlays.
This is a spot check of the existing unchanged art and minimum-size fixture,
not a fresh game capture or a physical-phone visual acceptance result.
See `hero-hud-lab/roster-minimum.png`, its evidence hashes, and `readability.log`.

Phone build, installation, and launch evidence is saved alongside this report.
