# Tap-area guide visibility

Updated the guide to bright cyan (RGB 0, 1, 1), matching the other guides' line thickness: 3 points in the game and 1.5 points in the native editor. Dashes are now 16 points long with 4-point gaps, giving 80% line coverage instead of the previous 25%.

The actual debug guide view was host-rendered and inspected at phone size. The cyan boundary is clearly visible, including the inset top edge, with the existing polygon geometry preserved. The iPhone build passed. Build, installation, and launch logs are saved here; the host render is a layout proof, not a gameplay screenshot. No Simulator was used.

[Phone guide](phone-guides@1x.png)
