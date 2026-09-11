Reduced `MapSpriteSizing.exitMarker` from 32 to 25.6 points at the minimum
playable height. Both dimensions scale by 0.8 at every supported layout; the
existing 0.7 ground-plane projection gives a minimum 25.6 × 17.92 point box.

The existing art lab and actual physical-iPhone captures passed familiar-agent
readability checks. The four arms and central crossing remain distinct, and
red separates the glyph from grass and snow. The source artwork and authored
centers are preserved. All 26 centers and 52 rendered-bound checks passed.

`comparison-minimum.png` is an unscaled crop comparison from iPhone captures.
`review.json`, `exit-markers.json`, and `raster-checks.json` record the conditions,
source hashes, exact scale ratio, and limits of verification.
