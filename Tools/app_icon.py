#!/usr/bin/env python3
"""Generate Liberty Line's icon sizes and verify source or archived icon coverage.

Run with --generate after changing the master artwork. Archive builds also pass
--bundle to check the compiled catalog, not just the source configuration.
"""

import argparse
import json
from pathlib import Path
import plistlib
import struct
import subprocess
import sys


ICON_SET = (Path(__file__).resolve().parents[2] / "in-defense-of-history-data"
            / "LibertyLineAssets.xcassets/AppIcon.appiconset")
MASTER = "LibertyLine-AppIcon-Default.png"
# Point size and scale: notifications, Settings, Spotlight, and Home Screen.
SLOTS = {
    "iphone": [(size, scale) for size in (20, 29, 40, 60) for scale in (2, 3)],
    "ipad": ([(size, scale) for size in (20, 29, 40, 76) for scale in (1, 2)]
             + [(83.5, 2)]),
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def entries():
    images = [{"filename": MASTER, "idiom": "universal", "platform": "ios",
               "size": "1024x1024"}]
    for idiom, slots in SLOTS.items():
        for size, scale in slots:
            pixels = int(size * scale)
            images.append({"filename": f"LibertyLine-AppIcon-{pixels}.png",
                           "idiom": idiom, "scale": f"{scale}x",
                           "size": f"{size}x{size}"})
    # Keep this explicit: the single-size master alone did not produce a
    # marketing rendition in Xcode 26.6's compiled Assets.car.
    images.append({"filename": MASTER, "idiom": "ios-marketing",
                   "scale": "1x", "size": "1024x1024"})
    return images


def verify_png(path, pixels):
    data = path.read_bytes()
    require(data[:8] == b"\x89PNG\r\n\x1a\n", f"Not a PNG: {path}")
    width, height, depth, color = struct.unpack(">IIBB", data[16:26])
    require((width, height, depth, color) == (pixels, pixels, 8, 2),
            f"{path.name} must be {pixels}x{pixels}, 8-bit RGB without alpha")


def generate():
    verify_png(ICON_SET / MASTER, 1024)
    for pixels in sorted({int(size * scale) for slots in SLOTS.values()
                          for size, scale in slots}):
        subprocess.run(["/usr/bin/sips", "--resampleHeightWidth", str(pixels),
                        str(pixels), str(ICON_SET / MASTER), "--out",
                        str(ICON_SET / f"LibertyLine-AppIcon-{pixels}.png")],
                       check=True, capture_output=True)
    (ICON_SET / "Contents.json").write_text(json.dumps(
        {"images": entries(), "info": {"author": "xcode", "version": 1}},
        indent=2) + "\n")


def verify_source():
    images = json.loads((ICON_SET / "Contents.json").read_text())["images"]
    for entry in entries():
        require(images.count(entry) == 1,
                f"Missing or duplicated app icon slot: {entry}")
    for entry in images:
        require(entry.get("filename"), f"Empty app icon slot: {entry}")
        pixels = int(float(entry["size"].split("x")[0])
                     * float(entry.get("scale", "1x")[:-1]))
        verify_png(ICON_SET / entry["filename"], pixels)
    print(f"App icon source verified: {len(entries())} populated slots.")


def verify_bundle(bundle):
    info = plistlib.loads((bundle / "Info.plist").read_bytes())
    for key in ("CFBundleIcons", "CFBundleIcons~ipad"):
        primary = info.get(key, {}).get("CFBundlePrimaryIcon", {})
        require(primary.get("CFBundleIconName") == "AppIcon",
                f"{key} does not reference AppIcon")
        names = primary.get("CFBundleIconFiles", [])
        require(names, f"{key} has no device icon file references")
        for name in names:
            require(any(bundle.glob(f"{name}*.png")),
                    f"Missing bundled device icon: {name}")
    result = subprocess.run(["/usr/bin/xcrun", "assetutil", "--info",
                             str(bundle / "Assets.car")],
                            check=True, capture_output=True, text=True)
    icons = [item for item in json.loads(result.stdout)
             if item.get("Name") == "AppIcon"
             and item.get("AssetType") in ("Icon Image", "Image")
             and not item.get("Appearance")]
    expected = {(idiom, int(size * scale), scale)
                for source, idiom in (("iphone", "phone"), ("ipad", "pad"))
                for size, scale in SLOTS[source]}
    expected.update((idiom, 1024, 1) for idiom in ("phone", "pad", "marketing"))
    for idiom, pixels, scale in sorted(expected):
        require(any(item.get("Idiom") == idiom
                    and item.get("PixelWidth") == pixels
                    and item.get("PixelHeight") == pixels
                    and item.get("Scale") == scale
                    and item.get("Opaque") is True for item in icons),
                f"Compiled AppIcon missing opaque {idiom} {pixels}px @{scale}x")
    print("Compiled app icon verified: iPhone, iPad, iPad Pro, Settings, "
          "Spotlight, notifications, and 1024px App Store marketing icon.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--generate", action="store_true",
                        help="Regenerate sizes and Contents.json from the existing master")
    parser.add_argument("--bundle", type=Path,
                        help="Verify the compiled icon in an unthinned .app bundle")
    args = parser.parse_args()
    if args.generate:
        generate()
    verify_source()
    if args.bundle:
        verify_bundle(args.bundle)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError, subprocess.CalledProcessError) as error:
        print(f"error: App icon validation failed: {error}", file=sys.stderr)
        sys.exit(1)
