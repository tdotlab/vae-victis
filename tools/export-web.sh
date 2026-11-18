#!/usr/bin/env bash
# Build the browser version into build/web. Serve it with tools/serve-web.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/c/Users/ringd/tools/godot/4.7/Godot_v4.7-stable_win64_console.exe}"
mkdir -p build/web
"$GODOT" --headless --path game --import >/dev/null 2>&1 || true
"$GODOT" --headless --path game --export-release "Web" ../build/web/index.html
ls -la build/web
