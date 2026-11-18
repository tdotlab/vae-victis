#!/usr/bin/env bash
# Run the headless test suite. Usage: tools/test.sh [--only=<substring>]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/c/Users/ringd/tools/godot/4.7/Godot_v4.7-stable_win64_console.exe}"
# Import first so class_name globals are registered on a fresh checkout.
"$GODOT" --headless --path game --import >/dev/null 2>&1 || true
"$GODOT" --headless --path game --script res://tests/run_tests.gd -- "$@"
