#!/bin/sh
set -e
MODE="$1"
COUNTER_DIR="$SRCROOT/Versioning"
COUNTER="$COUNTER_DIR/$TARGET_NAME.buildnum"
mkdir -p "$COUNTER_DIR"
N=$(cat "$COUNTER" 2>/dev/null || echo 0)
N=$((N + 1))
printf '%s\n' "$N" > "$COUNTER"
VERSION="${MARKETING_VERSION:-1.0}"
case "$MODE" in
plist)
    PLIST="$TARGET_BUILD_DIR/$INFOPLIST_PATH"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $N" "$PLIST" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $N" "$PLIST"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION.$N" "$PLIST" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION.$N" "$PLIST"
    mkdir -p "$DERIVED_FILE_DIR"
    printf '%s\n' "$N" > "$DERIVED_FILE_DIR/buildstamp.txt"
    ;;
swift)
    printf 'enum BuildVersion {\n    static let version = "%s.%s"\n    static let build = %s\n}\n' \
        "$VERSION" "$N" "$N" > "$SRCROOT/Simulator/BuildVersion.swift"
    ;;
esac
