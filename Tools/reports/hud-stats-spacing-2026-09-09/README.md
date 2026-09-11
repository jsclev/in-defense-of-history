# Spaced and rounded HUD plates

Increased spacing between the lives, money and wave plates from one to 2.5 times statPlatePadding, and increased their continuous corner radius by 50%. At the minimum gameplay fixture this is 7.75pt spacing (previously 3.1pt) and 9.3pt corners (previously 6.2pt). Each plate retains its separate 46%-opacity black fill; there is no background on the containing HStack. Occupied bounds include the wider gaps.

Minimum row: about 301.03×33.23pt. Inspected native minimum renders before enlargements, the same lab's color/grayscale/silhouette transforms, and grass/snow scenes. Text and icons remain clear, plates stay distinct, and terrain is visible between them. PASS. A center scanline of the production host render shows two fully transparent interior gaps of 23 and 24 pixels at 3×, matching 7.75pt spacing with raster rounding (`gap-evidence.json`).

The existing readability lab was rerun (`lab/evidence.json`); the supplemental `minimum-readability.png` gives the wide HUD enough room for the lab's diagnostic transformations. The regular game and device diagnostic builds passed. Physical iPhone 15 Pro native HUD and full gameplay captures were inspected: the three softened rectangles remain separate with clear terrain in both gaps. `device-hud-on-terrain@1x.png` is an unscaled crop of that gameplay capture. These device conditions PASS. Existing live-wave/counter checks also passed in the reused capture app; this change does not modify gameplay logic.

The regular game is installed and relaunched; install/launch logs record the result. The temporary capture app is removed after verification. Source and capture hashes are retained. Independent player testing remains unmeasured.
