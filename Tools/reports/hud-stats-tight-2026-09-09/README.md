# Dark, icon-aligned HUD backing

Raised the three stats backgrounds from 46% to 72% black opacity. Lives and money now have only trailing padding: their backgrounds begin at the icon's left edge and use exactly its height, with no padding above, below or to the left. The wave backing matches the tallest counter. Existing white values, separate rounded plates and 7.75pt minimum gaps are preserved. Occupied-frame dimensions match the smaller backing geometry.

Reference viewed in the browser: [classic Kingdom Rush HUD screenshot](https://www.wesplays.com/uploads/5/0/7/0/50705773/kr-ui-01_orig.png). The reference has compact dark strips closely aligned behind the icons and values; this motivated removing the surrounding padded-card treatment. The chosen 72% opacity is our adjustment, not a measured property of Kingdom Rush.

Minimum row is about 294.83×27.03pt. Lives icon/backing height is 25.9532pt; money icon/backing and wave height are 27.032pt. Source images' nonzero-alpha bounds span their complete canvases at all three densities, so removing layout padding also aligns the visible icon bounds. Icon size is unchanged.

Native 1× production-view renders were inspected before enlargements, including grass and snow scenes. Icons and white values remain readable, the backgrounds are visibly darker, and terrain still shows in the gaps. Color/grayscale and the 3× wide-value render also passed. The existing readability lab was rerun (`lab/evidence.json`); the supplemental wide-row sheet uses that lab's transformations. Host renders approximate SwiftUI on iOS.

Signed game/device diagnostic builds passed. The native HUD and full gameplay captures from the connected iPhone 15 Pro were inspected: the dark backgrounds align with the icon height and left edge, values remain clear, and the gaps reveal the map. PASS in these device conditions. The reused live-counter diagnostic passed. The regular app is installed/relaunched and the temporary diagnostic removed; the final install/launch/cleanup logs record those results. `device-hud-on-terrain@1x.png` is an unscaled crop of the actual 852×393pt gameplay capture. Independent player validation remains unmeasured.

## Subsequent user review

The user rejected the leading-edge appearance as an ambiguous partial margin. Frame alignment did not make the combined curved icon/background look flush. Superseded by [the explicit left-margin revision](../hud-stats-left-margin-2026-09-09/README.md).
