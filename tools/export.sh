#!/bin/sh
# Exports the game into build/<platform>, what goes to itch.io, with the engine's licences beside it.
#
# linux: one x86_64 binary with the game inside it.
#
# windows: one x86_64 .exe with the game inside it. It is not signed: Windows asks before its
# first start (More info > Run anyway).
#
# macos: Bellwater.zip, with the app inside, for Apple Silicon and Intel Macs. The app is signed
# ad hoc and not notarized: one that was downloaded is held back by macOS until it is allowed
# under System Settings > Privacy & Security (Open Anyway), or by:
#   xattr -dr com.apple.quarantine Bellwater.app
# It is signed here with rcodesign, not by Godot: Godot's own signature is one that newer
# versions of macOS refuse to start.
#
# usage: tools/export.sh [linux|windows|macos]   (linux without any)
set -eu
cd "$(dirname "$0")/.."
. tools/godot.sh

platform="${1:-linux}"
case "$platform" in
	linux) preset=Linux; file=bellwater.x86_64 ;;
	windows) preset=Windows; file=Bellwater.exe ;;
	macos) preset=macOS; file=Bellwater.zip ;;
	*) echo "usage: tools/export.sh [linux|windows|macos]" >&2; exit 1 ;;
esac

OUT="build/$platform"
rm -rf "$OUT"
mkdir -p "$OUT/licenses"
touch build/.gdignore
"$GODOT_BIN" --headless --path . --export-release "$preset" "$OUT/$file"
test -s "$OUT/$file"

# Godot's notices have to travel with the game. The Linux binary writes them itself, which also
# proves it starts up on its own; the others can't run here, so the editor writes theirs.
licenses="$(pwd)/$OUT/licenses/GODOT.txt"
if [ "$platform" = linux ]; then
	test -x "$OUT/$file"
	"$OUT/$file" --headless --audio-driver Dummy -- licenses "$licenses"
else
	"$GODOT_BIN" --headless --audio-driver Dummy --path . -- licenses "$licenses"
fi
test -s "$licenses"

if [ "$platform" = macos ]; then
	# The export leaves the app unsigned (the preset's codesign is off). rcodesign signs it ad hoc,
	# as Apple's `codesign --sign -` would: no entitlements, which only a hardened runtime asks for.
	# $RCODESIGN, the one on PATH, or the folder the publish workflow unpacks at the repo root.
	rcodesign="${RCODESIGN:-$(command -v rcodesign || ls -d "$PWD"/apple-codesign-*/rcodesign 2>/dev/null | sort | tail -n 1 || true)}"
	if [ ! -x "$rcodesign" ]; then
		echo "No rcodesign found: set RCODESIGN to its path." >&2
		exit 1
	fi
	mkdir "$OUT/app"
	unzip -q "$OUT/$file" -d "$OUT/app"
	rm "$OUT/$file"
	"$rcodesign" sign "$OUT"/app/*.app
	mv "$OUT/licenses" "$OUT/app/"
	# -y: a link stays a link; the files keep their permissions (the executable's, above all)
	(cd "$OUT/app" && zip -q -r -y "../$file" .)
	rm -rf "$OUT/app"
fi
ls -l "$OUT"
