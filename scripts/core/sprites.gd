class_name Sprites
extends RefCounted
## Access to the packed decoration atlas.

static var _deco_tex: Texture2D


static func deco() -> Dictionary:
	return DecoData.REGIONS


static func deco_tex() -> Texture2D:
	if _deco_tex == null:
		_deco_tex = load("res://assets/gfx/deco.png")
	return _deco_tex
