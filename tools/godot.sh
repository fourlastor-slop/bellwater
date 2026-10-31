# Finds the Godot editor and puts it in GODOT_BIN. Source this from the repo root.
# Looks at $GODOT, then the copy the publish workflow unpacks at the root, then the usual
# local install, then PATH.

GODOT_BIN="${GODOT:-}"
if [ -z "$GODOT_BIN" ]; then
	GODOT_BIN=$(ls Godot_v*_mono_linux_x86_64/Godot_v*_mono_linux.x86_64 2>/dev/null | head -n 1 || true)
fi
if [ -z "$GODOT_BIN" ]; then
	GODOT_BIN=$(ls "$HOME"/Apps/Godot_v4.7.2-stable_mono_linux_x86_64/Godot_v*_mono_linux.x86_64 2>/dev/null | head -n 1 || true)
fi
if [ -z "$GODOT_BIN" ]; then
	GODOT_BIN=$(command -v godot || true)
fi
if [ -z "$GODOT_BIN" ]; then
	echo "No Godot editor found: set GODOT to its path." >&2
	exit 1
fi
