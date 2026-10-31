#!/usr/bin/env bash
# Prove the game can be finished. See tests/route.gd.
cd "$(dirname "$0")/.."
. tools/godot.sh
timeout "${1:-500}" "$GODOT_BIN" --headless --path . res://tests/route.tscn -- "${@:2}" 2>&1 | grep -vE "^(Godot Engine|$)"
