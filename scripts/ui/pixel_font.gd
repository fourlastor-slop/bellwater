class_name PixelFont
extends RefCounted
## Draws the game's own bitmap font on any CanvasItem.

const CW := 6
const CH := 10
const COLS := 16
const LINE := 10

static var tex: Texture2D


static func width(s: String) -> int:
	var w := 0
	for i in s.length():
		var c := s.unicode_at(i) - 32
		if c >= 0 and c < FontData.WIDTHS.size():
			w += FontData.WIDTHS[c] + 1
	return maxi(w - 1, 0)


static func draw(ci: CanvasItem, pos: Vector2, s: String, col := Color.WHITE, shadow := Color(0, 0, 0, 0)) -> void:
	if tex == null:
		tex = load("res://assets/gfx/font.png")
	if shadow.a > 0.0:
		_run(ci, pos + Vector2(0, 1), s, shadow)
	_run(ci, pos, s, col)


static func _run(ci: CanvasItem, pos: Vector2, s: String, col: Color) -> void:
	var x := roundf(pos.x)
	var y := roundf(pos.y)
	for i in s.length():
		var c := s.unicode_at(i) - 32
		if c < 0 or c >= FontData.WIDTHS.size():
			continue
		var src := Rect2((c % COLS) * CW, (c / COLS) * CH, CW, CH)
		if c != 0:
			ci.draw_texture_rect_region(tex, Rect2(x, y, CW, CH), src, col)
		x += FontData.WIDTHS[c] + 1


static func centered(ci: CanvasItem, y: float, s: String, col := Color.WHITE, shadow := Color(0, 0, 0, 0), cx := 160.0) -> void:
	draw(ci, Vector2(cx - width(s) / 2.0, y), s, col, shadow)


static func wrap(s: String, max_w: int) -> PackedStringArray:
	var out: PackedStringArray = []
	for para in s.split("\n"):
		var line := ""
		for word in para.split(" ", false):
			var next := word if line == "" else line + " " + word
			if width(next) > max_w and line != "":
				out.append(line)
				line = word
			else:
				line = next
		out.append(line)
	return out
