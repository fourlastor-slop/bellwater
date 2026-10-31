#!/usr/bin/env bash
# Play the real game with gamepad events only. See tests/gamepad.gd.
cd "$(dirname "$0")/.."
. tools/godot.sh
timeout "${1:-200}" xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT_BIN" --path . --rendering-driver opengl3 --resolution 320x180 res://tests/gamepad.tscn 2>&1 | grep -E "^  (ok|FAIL)|GAMEPAD|SCRIPT ERROR|at: " | grep -vE "_create_xic|set_use_vsync"
