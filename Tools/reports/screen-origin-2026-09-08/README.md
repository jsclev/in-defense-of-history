Screen-origin correction, 2026-09-08

The previous fixed-size viewport was stable but incorrectly centered by the app root within the shorter safe area. The iPhone 17 Pro UIKit probe reproduced map/HUD origin (0,-10) with 874×402pt window bounds and a 20pt bottom inset. Merely adding ignoresSafeArea to the fixed viewport did not fix it.

Production ScreenCanvas now supplies a full-screen GeometryReader with top-leading placement at the app root. UIKit measurements put the root, map and HUD at (0,0,874,402), a map marker requested at (100,100) at exactly that center, and fixture top controls at their intended 7pt inset. These measurements remain identical with wave controls visible, hidden, then visible again. Existing RuntimeCanvas/HUD layout values and projection formulas are unchanged.

Run Tools/check_screen_origin.py on a booted iOS 26.5+ simulator to reproduce the current and corrected roots and assert absolute positions. The probe compiles the production ScreenCanvas and LevelViewport. It uses simple colored control/marker fixtures, rather than the full game, and does not open game saves. Eight existing viewport and presentation tests also pass; the unsigned Debug iPhone build passed. Physical-device gameplay was not tested.
