#!/bin/sh
# Fixed-fixture regression checks for editor changes. AppKit tests create hidden
# windows, so run from a normal macOS session; no Simulator or user maps are used.
set -eu
editor_repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$editor_repo"
swift test --filter '\.(Editor[^/]*Tests|LevelGeoJSONTests|HeroStartingPositionTests|CallWaveButtonTests)/' "$@"
