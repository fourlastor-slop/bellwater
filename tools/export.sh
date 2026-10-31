#!/bin/sh
# Exports the game for Linux into build/linux, the folder that goes to itch.io:
# one binary with the game inside it, and the engine's licences next to it.
set -eu
cd "$(dirname "$0")/.."
. tools/godot.sh

OUT=build/linux
rm -rf "$OUT"
mkdir -p "$OUT/licenses"
touch build/.gdignore
"$GODOT_BIN" --headless --path . --export-release "Linux" "$OUT/bellwater.x86_64"
test -x "$OUT/bellwater.x86_64"

# Godot's notices have to travel with the game. The binary writes them itself, which also
# proves it starts up on its own.
"$OUT/bellwater.x86_64" --headless --audio-driver Dummy -- licenses "$(pwd)/$OUT/licenses/GODOT.txt"
test -s "$OUT/licenses/GODOT.txt"
ls -l "$OUT" "$OUT/licenses"
