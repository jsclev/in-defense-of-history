#!/usr/bin/env python3
"""Download image and JSON diagnostics from an app's Documents directory."""
import argparse
import json
from pathlib import Path, PurePosixPath
import subprocess


def artifact_paths(entries):
    for entry in entries:
        resources = entry["resources"]
        path = PurePosixPath(entry["relativePath"])
        if resources.get("isDirectory") or resources.get("isSymbolicLink"):
            continue
        if path.is_absolute() or ".." in path.parts:
            raise ValueError(f"Invalid diagnostic path: {path}")
        if path.suffix.lower() in {".png", ".jpg", ".jpeg", ".heic", ".webp", ".gif", ".json"}:
            yield path


def capture(device, bundle_id, output):
    domain = ["--device", device, "--domain-type", "appDataContainer",
              "--domain-identifier", bundle_id]
    listing = subprocess.run(
        ["xcrun", "devicectl", "device", "info", "files", *domain,
         "--subdirectory", "Documents", "--recurse", "--json-output", "-"],
        check=True, capture_output=True, text=True)
    entries = json.loads(listing.stdout)["result"]["files"]
    count = 0
    for path in artifact_paths(entries):
        destination = output.joinpath(*path.parts)
        destination.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            ["xcrun", "devicectl", "device", "copy", "from", *domain,
             "--source", str(PurePosixPath("Documents") / path),
             "--destination", str(destination)], check=True)
        count += 1
    print(f"Downloaded {count} diagnostic files.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    capture(args.device, args.bundle_id, args.output)
