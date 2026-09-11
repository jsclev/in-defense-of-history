# Knox portrait background correction — September 10, 2026

The user rejected the exposed blue panel around the orange Knox portrait. The preceding spacing review checked headroom but incorrectly treated that mismatched background as acceptable.

`HeroHUDButton.swift` now fills Knox's inset panel with orange, retaining the existing painted panel's tonal texture through a grayscale/soft-light layer. A mask follows the panel inside the gold rim. This affects Knox only; the shared frame artwork and reinforcement rendering are unchanged. The original portrait remains at 64% of the button side, offset downward by 2%, preserving its existing headroom and lower edge. No raster assets were generated or edited.

The iPhone build and isolated production-view probe succeeded. Native captures cover ready, selected and unavailable states at minimum and device button sizes (44.9556 and 57.069 points), at 1x/2x/3x. `check_renders.py` and `render-checks.json` record 45 checks: unchanged neighboring controls, preserved portrait interiors, no blue pixels in the sampled top padding, and preserved source/art hashes. Original Knox exports remain 96/192/288 pixels.

I reviewed the minimum native button first, then enlarged ready/selected images, the live minimum Charleston HUD and the existing readability lab's roster. The padding is warm orange throughout the inner panel, the gold rim remains distinct, and the face/dark hair/blue coat/red sash remain readable. Unavailable state desaturates both the portrait and its matching padding. This is a familiar-agent review, not a blinded recognition test.

The temporary probe was removed; the normal game was installed and launched on the physical iPhone. Receipts: `probe-uninstall.json`, `install.json`, `launch.json`. Build and probe logs, tested inputs, source-before snapshot, and device captures are preserved here. Review images and lab are in `/Users/john/projects/td/in-defense-of-history-data/ArtReadability/reports/knox-background-2026-09-10/`.
