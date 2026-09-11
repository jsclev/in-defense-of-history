# Range visibility on the new Bastion grass — September 9, 2026

The range overlay now uses a fixed, bright cool green **#7FFFAD** and a narrow
dark green **#10382B** separator inside its boundary. The outer 2-point line is
solid green. The center remains transparent; the short fade starts at 92% of
the elliptical radius. Current reach is solid, while an upgrade preview is
dashed. Both strokes share one inset path so their dashes align. Clipping keeps
the contrast stroke inside the range boundary.

## Purpose and research

The overlay is a temporary decision aid: show the selected friendly tower's
reach while choosing a build, upgrade, or rally point. The production runner
uses attack range for shooting towers and rally radius for melee towers. Green
identifies friendly reach; it does not certify affordability, available building
space, or safety throughout the enclosed terrain. Preserve the visible road,
troops and targets through the clear center so the player can judge coverage.

Primary sources rechecked for this revision:

- [Riot, Clarity in League](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/)
  (March 12, 2021): clearly convey gameplay, match prominence to gameplay
  importance, minimize visual noise, and check effects across map backgrounds.
  **Application here:** concentrate attention on the range boundary, retain the
  clear interior, and avoid a pulsing or fully glowing field.
- [W3C, Non-text Contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html):
  meaningful graphical cues need luminance contrast with adjacent colors;
  thin antialiased lines may look fainter than their specified colors.
  **Application here:** use the guidance's 3:1 ratio as a useful diagnostic
  reference and add a dark separator instead of relying only on hue. This is
  not a WCAG certification or a validated game-recognition threshold.
- [W3C, Use of Color](https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html):
  meaning should have cues in addition to color. **Application here:** retain
  solid current range versus dashed potential range, and inspect grayscale.

The project's [standing art direction](../../../../in-defense-of-history-data/ArtReadability/ART_DIRECTION.md)
sets Bastion's vivid broad colors and value separation as the style guide.
The exact green and separator colors are our design choice based on this
background, not colors prescribed by those sources or sampled from Bastion.

## Grass measurements and choice

The current source is `Levels/grass_bastion.png`. The reviewed gameplay image
is the shipped Battle Road HEIC with this grass; the previous turn's old terrain
proof was insufficient for judging contrast against the new background.

[color-analysis.json](color-analysis.json) records six median-cut color groups
from the playable grass crop and estimated sRGB relative luminance after
scaling it to 604 × 340 pixels. Representative groups include **#69AF3A**,
**#80BF33**, and **#A4CF30**. Median grass luminance is approximately **0.382**;
the 5th–95th percentile spans **0.236–0.534**.

A nominal iOS green #34C759 has only about **1.17:1 median contrast** against
that grass sample. Brighter green, mint, and chartreuse candidates still provide
only about **1.95–2.06:1 median contrast** by themselves. These are specified
color comparisons, not a claim that every OS appearance resolves `.green` to
that nominal value. Physical before/after captures reproduce the actual weak
boundary and its correction.

The chosen cool green keeps more separation from the warm yellow-green turf
than chartreuse, while reading more green than the paler mint candidate. The
dark separator gives a second, strong luminance edge across bright grass and
snow. The two specified solid colors contrast approximately **10.36:1** with
each other. The separator exposes only 1.5 points inside the green line; it
does not tint the interior or extend the displayed reach. The fade remains a
secondary cue. Raster sampling and human perception still require inspection.

## Review and verification

- **PASS — native-size self-review:** inspected [compact proof](native-size-proof.png)
  before enlargement. At the 393-point portrait fit (221.0625-point playable
  height), the smallest ellipse is approximately 130.62 × 91.44 points. The
  previous border merges with grass; the revised boundary stays traceable on
  new grass, composed Battle Road and Trenton snow. The dashed upgrade remains
  visibly separate from current reach.
- **PASS — existing lab:** ran [the calibrated lab](lab/index.html) with these
  production SwiftUI raster outputs. Inspected current range at 2× and upgrade
  range at 3× on new grass, with color, grayscale, and silhouette panels. Both
  boundary geometry and solid/dashed distinction remain visible without hue.
  Its fixed compact-size fixture avoids scaling a raster's constant-width
  stroke to claim a different runtime size. [Lab evidence](lab/evidence.json)
  includes input hashes and density dimensions.
- **PASS — physical iPhone:** a separate review app compiled the current
  production view and displayed it over the production `LevelMapView` on the
  new Battle Road terrain. It captured clear / previous / current / upgrade
  states at the device's 852 × 393-point window and the 604.44 × 340-point
  fixture, at 1×, 2× and 3×. The range center was set explicitly by the fixture;
  these are native UIKit hierarchy captures of a constructed review state,
  not evidence of exercising tower-selection gestures. See
  [range-check.json](range-check.json), [probe build log](probe-build.log), and
  [native iPhone comparison](iphone-native-comparison.png).
- **PASS — alpha observations:** [alpha-review.json](alpha-review.json) records
  fully clear inner 90% at playable heights 221.0625 / 340 / 900, each at 1×,
  2× and 3×. Equal-range upgrade output remains byte-identical to a single
  ring. [Geometry](geometry.json) records all fixtures. `git diff --check`
  passed; the actual SwiftUI view compiled for macOS and iPhone.
- **NOT MEASURED:** independent player recognition, color-vision-deficiency
  simulation, and a person judging the phone's physical display in different
  lighting. Grayscale self-review is not a substitute for those checks.

Source hashes are in [source-evidence.json](source-evidence.json). The device
probe's map hash is also saved separately. The main app's fresh dedicated
[final build](iphone-final-build.log) succeeded, passed strict code-signature
verification, and [installed successfully](install-final.json). Its grass and
Battle Road resources match the reviewed sources byte for byte:
[bundle verification](bundle-verification.json). The initial installation from
the shared build folder failed signature verification; the dedicated fresh
build resolved it. That failed attempt is retained in `install.json`.
The main game then [launched successfully](launch-refreshed.json) after
refreshing the phone's app inventory to resolve a transient LaunchServices
registration mismatch. The temporary review app was removed; its captures
remain in this report.

The smallest proof was reviewed first. Enlarged source art and numerical
contrast alone were not used to declare the overlay readable. The reusable
lesson is to recheck a gameplay indicator when its terrain palette changes,
and to give an important green-on-green boundary luminance separation while
keeping its purpose and visual prominence clear.
