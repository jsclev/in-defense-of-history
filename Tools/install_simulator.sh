#!/bin/sh
set -eu

case "${1:-}" in
    -h|--help)
        printf 'Usage: %s\nBuild and install ~/bin/LibertyLineSimulator and its build-named starter SQLite database.\n' "$0"
        exit 0
        ;;
esac
if [ "$#" -ne 0 ]; then
    printf 'Usage: %s\n' "$0" >&2
    exit 2
fi

sim_project_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
sim_build_dir="$HOME/Library/Developer/Xcode/DerivedData/LibertyLineCLI"
sim_install_dir="$HOME/bin"
sim_destination="$sim_install_dir/LibertyLineSimulator"

xcodebuild -project "$sim_project_dir/InDefenseOfHistory.xcodeproj" \
    -scheme Simulator \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath "$sim_build_dir" \
    build

sim_product="$sim_build_dir/Build/Products/Release/Simulator"
if [ ! -x "$sim_product" ]; then
    printf 'Release executable missing: %s\n' "$sim_product" >&2
    exit 1
fi
if [ -d "$sim_destination" ]; then
    printf 'Cannot install an executable over a directory: %s\n' "$sim_destination" >&2
    exit 1
fi

mkdir -p "$sim_install_dir"
sim_version="$("$sim_product" --version)"
sim_database_name="liberty-line-simulator-$sim_version.sqlite"
sim_database="$sim_install_dir/$sim_database_name"
if [ -e "$sim_database" ] || [ -L "$sim_database" ]; then
    printf 'Refusing to replace an existing starter database: %s\n' "$sim_database" >&2
    exit 1
fi

# Build a fresh database from the same authored SQL as the game. The checkout's
# development database is never opened or rebuilt by this installation.
sim_stage="$(mktemp -d "$sim_install_dir/.LibertyLineSimulator-install.XXXXXX")"
trap 'rm -rf "$sim_stage"' EXIT
trap 'exit 1' HUP INT TERM
"$sim_project_dir/Db/create_db.sh" --output "$sim_stage/authored.sqlite"
"$sim_product" --prepare-starter-database "$sim_stage/authored.sqlite" "$sim_stage/$sim_database_name"
/usr/bin/install -m 755 "$sim_product" "$sim_stage/LibertyLineSimulator"
"$sim_stage/LibertyLineSimulator" --database "$sim_stage/$sim_database_name" --runs

# Publish the matching database before replacing the executable. Linking within
# this filesystem refuses an existing filename atomically; old builds remain.
ln "$sim_stage/$sim_database_name" "$sim_database"
mv -f "$sim_stage/LibertyLineSimulator" "$sim_destination"
rm -rf "$sim_stage"
trap - EXIT HUP INT TERM

printf '\nInstalled Release CLI: %s\n' "$sim_destination"
printf 'Installed starter database: %s\n' "$sim_database"
printf 'Start level 15 with: "%s" 15\n' "$sim_destination"
