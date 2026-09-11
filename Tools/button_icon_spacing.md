# Speed and pause icon sizing

Decision, September 8, 2026: fit each speed/pause glyph proportionally inside a
square **60% of its decorative frame's side**. Center that square in the frame.
This leaves **20% of the frame side between each edge of the icon box and the
outer frame edge**, including the thickness of the ornament. It does not mean
20% clear space measured from the ornament's inner edge.

## Research and application

- [Material Web's official icon-button tokens](https://github.com/material-components/material-web/blob/main/docs/components/icon-button.md#filled-icon-button-tokens)
  specify a 24px icon and a 40px square container for a filled icon button.
  That is a 60% ratio and 8px padding per side. This is an established design
  baseline, not evidence that one ratio is optimal for every graphic. We adopt
  its dimensionless proportion, not web pixels as iOS points.
- [Apple's button guidance](https://developer.apple.com/design/human-interface-guidelines/buttons)
  calls for space that distinguishes neighboring controls and makes them easy
  to activate, and generally a hit region of at least 44 × 44pt. This is a
  touch-target requirement, not a recommendation to make the symbol itself
  44pt. Apple's platform-specific visionOS spacing is not an iPhone rule.
- [Android accessibility guidance](https://support.google.com/accessibility/android/answer/7101858?hl=en)
  likewise distinguishes visible content from its touch target: it gives a
  24dp icon in a 48dp target as an example and recommends 8dp between targets.
  These are Android guidelines, not mandatory iOS dimensions.

The glyphs are tightly cropped: speed is 512 × 333 pixels and pause is
403 × 512 pixels. Aspect-fit therefore produces a wide speed symbol and a tall
pause symbol. Their maximum dimensions match; stretching either to a square
would distort its shape. Existing exports and frame art are unchanged.

## Current frame sizing — September 9

`MasterControlsLayout` now fits two equal square buttons and a 10%-of-button
gap between the HUD's top/right edges and the upper-right occlusion's
bottom/left edges. This uses the same combined-bounds concept as `HeroBarLayout`.
Both width and height constrain the result; the 60% glyph proportion is retained.

| Layout fixture | Frame side | Icon box side | Gap |
| --- | ---: | ---: | ---: |
| 340pt playable height, no safe insets | 37.418pt | 22.451pt | 3.742pt |
| 874×402pt phone, 750×382pt safe area | 50.806pt | 30.484pt | 5.081pt |

The phone fixture grows from 45.84pt and reaches the occlusion's bottom edge
from the HUD top. The narrow minimum fixture shrinks because the previous row
extended left of its reserved corner after applying the HUD margin. The new
row fits the entire pair and gap inside the combined bounds. See
`reports/master-controls-fit-2026-09-09` for tests and fresh native-size renders.

## Values in the original September 8 review

| Playable height | Frame side | Icon box side | Outer-edge padding per side |
| --- | ---: | ---: | ---: |
| 340pt (small-size proof) | 40.80pt | 24.48pt | 8.16pt |
| 382pt | 45.84pt | 27.504pt | 9.168pt |

At 340pt, the actual fitted speed glyph is 24.48 × 15.92pt and pause is
19.27 × 24.48pt. The starting 80% box was 32.64pt; the selected box is 25%
smaller in each dimension. The temporary 20%-of-original diagnostic was 6.528pt
and is removed.

`HudSizing.masterControlIconFraction` is the shared policy used by both
`HudMasterControlsView` buttons. The general `HudButtonView` default remains
80% for existing other art, which has different content and occupancy.

This change only adjusts the two glyph boxes. The existing visible frames,
4.53pt inter-frame gap at the 340pt proof size, HUD position, layout footprint,
and hit regions are preserved. At that smallest proof size the frame-sized
hit region is 40.8pt, below Apple's 44pt guideline; at 382pt it is 45.84pt.
This research does not certify the current touch geometry as meeting every
guideline. Any future target expansion must be independent of icon scaling,
remain inside the HUD's reserved area, and avoid overlapping adjacent targets.

## Visual evidence

The saved report is
`in-defense-of-history-data/ArtReadability/reports/control-padding-research-2026-09-08`.
It renders the production SwiftUI button code with the real catalog assets,
then runs the project's existing readability lab. Candidates are 50%, 55%,
60%, 68%, and the original 80%. The selected 60% retains distinct paired
triangles and separated pause bars while leaving visible space around the
ornament. The 80% pause bars crowd its top and bottom edges; 50% and 55% leave
more unused interior than necessary for these simple symbols.

See `review.json` for measured checks and limits. Raster-density proofs and
constructed map scenes are desktop checks, not physical-device usability
testing. The chosen ratio is a documented design decision supported by those
checks, not a claim of a scientifically proven universal optimum.
