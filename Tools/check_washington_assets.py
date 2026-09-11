#!/usr/bin/env python3
"""Verify the sword-up revision reaches both the catalog and the compiled app.

Update washington_asset_manifest.json deliberately when replacing Washington art.
Uses the standard library so this also runs with Xcode's Python installation.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess

GAME = Path(__file__).resolve().parents[1]
CATALOG = GAME.parent / "in-defense-of-history-data/LibertyLineAssets.xcassets"
PREFIX = "hero_unit_george_washington"
DIRECTIONS = ("n", "ne", "e", "se", "s", "sw", "w", "nw")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, help="Check a built .app, including a device-thinned build")
    parser.add_argument("--output", type=Path, help="Save verification evidence")
    args = parser.parse_args()
    manifest = json.loads((GAME / "Tools/washington_asset_manifest.json").read_text())
    facing = (GAME / "Engine/Models/UnitFacing.swift").read_text()
    count = int(re.search(r"georgeWashingtonFrameCount = (\d+)", facing)[1])
    east_count = int(re.search(r"georgeWashingtonEastFrameCount = (\d+)", facing)[1])
    counts = {d: east_count if d == "e" else count for d in DIRECTIONS}
    require(count == manifest["frame_count"], "Runtime Washington frame count is stale")
    require(counts == manifest["frame_counts_by_direction"], "Directional Washington counts are stale")
    names = {PREFIX} | {f"{PREFIX}_idle_{d}" for d in DIRECTIONS} | {
        f"{PREFIX}_walk_{d}_{i}" for d in DIRECTIONS for i in range(counts[d])}
    actual_names = {p.stem for p in CATALOG.glob(f"{PREFIX}*.imageset")}
    require(actual_names == names, "Missing or stale Washington imagesets in production catalog")
    rows = manifest["assets"]
    expected = {(name, scale) for name in names for scale in (1, 2, 3)}
    require({(r["name"], r["scale"]) for r in rows} == expected
            and len(rows) == len(expected), "Asset manifest is incomplete or duplicated")
    for row in rows:
        path = CATALOG / row["file"]
        data = path.read_bytes()
        require(data[:8] == b"\x89PNG\r\n\x1a\n", f"Not a PNG: {path}")
        require(hashlib.sha256(data).hexdigest() == row["sha256"],
                f"Washington artwork differs from the integrated revision: {path}")
        size = struct.unpack(">II", data[16:24])
        require(size == (row["width"], row["height"])
                == tuple(n * row["scale"] for n in manifest["canvas_points_at_1x"]),
                f"Inconsistent animation canvas: {path}")
        contents = json.loads((path.parent / "Contents.json").read_text())
        require(any(r.get("filename") == path.name and r.get("scale") == f'{row["scale"]}x'
                    for r in contents["images"]), f"Catalog does not reference {path}")
    research = json.loads((GAME / "Tools/hero_physical_scale.json").read_text())
    calibration = next(r["calibration"] for r in research["heroes"]
                       if r["id"] == "george_washington")
    require(calibration["reference_sha256"] == next(r["sha256"] for r in rows
            if r["name"] == PREFIX + "_idle_se" and r["scale"] == 3),
            "Physical size calibration points to old Washington artwork")
    result = {"status": "PASS", "revision": manifest["revision"],
              "runtime_frames_per_direction": counts, "imagesets": len(names),
              "source_pngs_verified": len(rows), "compiled_app": "NOT_CHECKED"}
    if args.bundle:
        car = args.bundle / "Assets.car"
        info = subprocess.run(["/usr/bin/xcrun", "assetutil", "--info", str(car)],
                              check=True, capture_output=True, text=True)
        renditions = [r for r in json.loads(info.stdout)
                      if r.get("Name", "").startswith(PREFIX) and r.get("AssetType") == "Image"]
        require({r["Name"] for r in renditions} == names,
                "Built app contains missing/stale Washington frame names")
        # Xcode may retain only the connected device's density. Every frame name
        # must exist, and every retained rendition must match the new canvas.
        by_key = {(r["name"], r["scale"]): r for r in rows}
        for rendition in renditions:
            key = (rendition["Name"], rendition.get("Scale"))
            require(key in by_key, f"Unexpected compiled Washington rendition: {key}")
            row = by_key[key]
            require(rendition.get("PixelWidth") == row["width"]
                    and rendition.get("PixelHeight") == row["height"],
                    f'Built app has stale artwork: {row["name"]} at {row["scale"]}x')
        result.update(compiled_app="PASS", compiled_renditions=len(renditions),
                      assets_car_sha256=hashlib.sha256(car.read_bytes()).hexdigest())
    if args.output:
        args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))


if __name__ == "__main__":
    main()
