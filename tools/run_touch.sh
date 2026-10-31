#!/usr/bin/env bash
# Play the real game with screen touches only. See tests/touch.gd.
cd "$(dirname "$0")/.."
. tools/godot.sh
timeout "${1:-300}" xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT_BIN" --path . --rendering-driver opengl3 --resolution 320x180 res://tests/touch.tscn 2>&1 | grep -E "^  (ok|FAIL)|TOUCH|SCRIPT ERROR|at: " | grep -vE "_create_xic|set_use_vsync"
