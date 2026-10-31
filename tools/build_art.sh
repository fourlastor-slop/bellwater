#!/usr/bin/env bash
# Regenerate every image in assets/gfx. Run from anywhere.
set -euo pipefail
cd "$(dirname "$0")/.."
PY=".venv/bin/python"
export PYTHONPATH=tools
$PY tools/gen_tiles.py assets/gfx/tiles.png
$PY tools/gen_player.py assets/gfx/player.png
$PY tools/gen_sprites.py
$PY tools/gen_font.py
$PY tools/gen_deco.py
$PY tools/gen_backdrop.py
$PY tools/gen_bosses.py
