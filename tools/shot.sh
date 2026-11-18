#!/usr/bin/env bash
# Run the game windowed in a test scenario and save a screenshot.
# Usage: tools/shot.sh <scenario> <out.png> [frames] [actions]
#   e.g. tools/shot.sh sandbox /tmp/a.png 40 "walk:12:5,fight"
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/c/Users/ringd/tools/godot/4.7/Godot_v4.7-stable_win64_console.exe}"
args=(--scenario="$1" --shot="$2" --frames="${3:-30}")
if [ -n "${4:-}" ]; then args+=(--act="$4"); fi
timeout 180 "$GODOT" --path game --resolution 1280x720 -- "${args[@]}"
