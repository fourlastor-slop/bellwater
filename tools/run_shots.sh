#!/usr/bin/env bash
# Dev helper: run a scripted input file under a virtual display and save screenshots.
# usage: tools/run_shots.sh out_dir script.json
cd "$(dirname "$0")/.."
. tools/godot.sh
timeout "${3:-120}" xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT_BIN" --path . --rendering-driver opengl3 --resolution 320x180 res://tests/shot.tscn -- "$1" "$2" 2>&1 | grep -vE "^(WARNING: Failed to create wd|WARNING: Could not set V-Sync|     at: (_create_xic|set_use_vsync)|OpenGL API|Godot Engine|$)"
