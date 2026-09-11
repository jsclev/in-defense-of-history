# Wave indicator beside money

The stats HUD is one horizontal row: lives, money, then the wave indicator. Visible wave text is `1 of 15`, with both numbers coming from the observed runner. VoiceOver retains the word Wave for context. All three plates retain their black 46%-opacity backgrounds and white values.

The occupied frame now includes the wave plate on the right and uses the height of the counter row. A fixed `99 of 99` sizing template keeps the row stable through wave transitions. No game scheduling or counter logic changed.

Minimum fixture: 604.44×340 screen; HUD about 291.73×33.23 points, wave text 15.1745pt. Native 1× start/end/wide-value renders were inspected before 2×/3× views. `99 of 99` and `9,999` fit without clipping. The heart, coins and white readouts stay distinct on grass/snow. PASS in these constructed host conditions. Host SwiftUI output approximates iOS.

The existing readability lab was rerun (`lab/evidence.json`). `minimum-readability.png` applies the lab's color/grayscale/silhouette transforms in appropriately spaced columns for the wide row; the default narrow-character roster sheet is unsuitable for HUD strips. Color/grayscale readability passed. Source hashes, density renders and layout measurements are saved alongside this record.

Signed iOS game and diagnostic builds passed. On the connected iPhone 15 Pro, the updated production HUD was rendered at 1×/2×/3× and captured in a running level at 852×393 logical pixels. Inspected the native `device-start@1x.png` and `gameplay@1x.png`: lives, money and `1 of 6` are on one row; the wave plate is to the right, without the visible word Wave. All text and icons remain readable, and the row stays separate from the corner controls. PASS in the captured device conditions.

The existing diagnostic also reconfirmed the correct current/total values through all 166 waves across 15 campaign levels (`stats.json`). The view's layout is the only game source changed in this follow-up. The regular game was installed/relaunched, and the temporary diagnostic app was removed; see the install, launch and cleanup records.

Independent player validation remains unmeasured.
