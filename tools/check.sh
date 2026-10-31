#!/usr/bin/env bash
# The check a build has to pass before it is published. Plays every boss to the death, rides the
# ending and soaks every room with random input. Fails on a lost fight or any script error.
set -euo pipefail
cd "$(dirname "$0")/.."
. tools/godot.sh

log=$(mktemp)
trap 'rm -f "$log"' EXIT
"$GODOT_BIN" --headless --audio-driver Dummy --path . res://tests/bosses.tscn 2>&1 | tee "$log"
if grep -q "SCRIPT ERROR" "$log"; then
	echo "Script errors during the check." >&2
	exit 1
fi
