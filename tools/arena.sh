#!/usr/bin/env bash
# Headless combat balance check: fresh builds vs every random encounter.
# Usage: tools/arena.sh [--runs=1000] [--only=<substring>] [--turns]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/c/Users/ringd/tools/godot/4.7/Godot_v4.7-stable_win64_console.exe}"
"$GODOT" --headless --path game --import >/dev/null 2>&1 || true
"$GODOT" --headless --path game --script res://tests/arena.gd -- "$@" 2>&1 | grep -v "^Godot Engine"
