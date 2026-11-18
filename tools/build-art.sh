#!/usr/bin/env bash
# Rebuild the game's art: render sprites in Blender, then pack them.
# Usage: tools/build-art.sh [group,group...]   (walls, trees, props, figure)
# Renders go to art/render/ (ignored by Git); sheets to game/assets/art/.
set -euo pipefail
cd "$(dirname "$0")/.."
BLENDER="${BLENDER:-/c/Users/ringd/tools/blender/blender-5.2.2-windows-x64/blender.exe}"
RENDER="$(cygpath -m "$PWD/art/render" 2>/dev/null || echo "$PWD/art/render")"
"$BLENDER" -b --factory-startup -P art/sprites.py -- "$RENDER" ${1:-} 2>&1 | grep -E "Error|Traceback|SPRITES DONE" || true
python art/pack.py "$RENDER" game
# Let Godot import the new images, with mipmaps (sheets are drawn at half
# size or less).
GODOT="${GODOT:-/c/Users/ringd/tools/godot/4.7/Godot_v4.7-stable_win64_console.exe}"
"$GODOT" --headless --path game --import >/dev/null 2>&1 || true
sed -i 's|mipmaps/generate=false|mipmaps/generate=true|' game/assets/art/*.png.import game/assets/art/ground/*.png.import
"$GODOT" --headless --path game --import >/dev/null 2>&1 || true
