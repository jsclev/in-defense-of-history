#!/usr/bin/env bash
set -euo pipefail

# Resolve the web project relative to this script, not the caller's directory.
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/LibertyLineWeb"

if ! command -v npm >/dev/null 2>&1; then
    printf '%s\n' 'Node.js and npm are required. Install Node.js 20.15 or newer.' >&2
    exit 1
fi
if [[ ! -x node_modules/.bin/vite ]]; then
    printf 'Install the web dependencies first: cd "%s" && npm ci\n' "$PWD" >&2
    exit 1
fi
if [[ ! -f dist/website/index.html ]]; then
    printf 'Build the website first: cd "%s" && npm run build\n' "$PWD" >&2
    exit 1
fi

printf '%s\n' 'Serving the existing website build. Press Ctrl-C to stop.'
exec npm run preview -- --port 4174 --strictPort
