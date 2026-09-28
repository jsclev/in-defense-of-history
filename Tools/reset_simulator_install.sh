#!/bin/sh
# Remove the previous CLI and generated starter databases before deployment.
set -eu

if [ "$#" -ne 1 ] || [ ! -d "$1" ]; then
    printf 'Usage: %s /absolute/path/to/install-directory\n' "$0" >&2
    exit 2
fi
sim_reset_dir="$1"
case "$sim_reset_dir" in
    /*) ;;
    *) printf 'Install directory must be absolute.\n' >&2; exit 2 ;;
esac

set --
for sim_file in "$sim_reset_dir/LibertyLineSimulator" \
    "$sim_reset_dir"/liberty-line-simulator-*.sqlite \
    "$sim_reset_dir"/liberty-line-simulator-*.sqlite-wal \
    "$sim_reset_dir"/liberty-line-simulator-*.sqlite-shm \
    "$sim_reset_dir"/liberty-line-simulator-*.sqlite-journal; do
    if [ ! -e "$sim_file" ] && [ ! -L "$sim_file" ]; then
        continue
    fi
    if [ "$sim_file" != "$sim_reset_dir/LibertyLineSimulator" ]; then
        sim_name="${sim_file##*/}"
        sim_version="${sim_name#liberty-line-simulator-}"
        sim_version="${sim_version%%.sqlite*}"
        # Only numeric build names are starter databases. Preserve -run- files
        # and custom experiment databases, including their SQLite sidecars.
        case "$sim_version" in
            ''|*[!0-9.]*) continue ;;
        esac
    fi
    if [ ! -f "$sim_file" ] && [ ! -L "$sim_file" ]; then
        printf 'Refusing to remove a non-file installation path: %s\n' "$sim_file" >&2
        exit 1
    fi
    set -- "$@" "$sim_file"
done

if [ "$#" -eq 0 ]; then
    exit 0
fi
# Check every target before deleting any. Never stop a running CLI or delete an
# open database: the user must finish the run or close the connection first.
sim_lsof_status=0
sim_open_pids="$(lsof -t -- "$@")" || sim_lsof_status=$?
# lsof can return 1 when some targets are closed even if others are open.
# Its process output must be checked independently of the exit status.
if [ -n "$sim_open_pids" ]; then
    printf 'Previous simulator installation is in use. Finish active runs and close its databases before deploying.\n' >&2
    exit 1
fi
case "$sim_lsof_status" in
    0|1) ;;
    *) printf 'Could not check whether the previous installation is in use.\n' >&2; exit 1 ;;
esac
rm -f -- "$@"
printf 'Removed previous simulator executable and starter databases.\n'
