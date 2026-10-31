extends Ent
## Lives in a wall. Lashes out along a line when you swim across its hole.

enum { HIDE, OUT, BACK }

var state := HIDE
var home_x := 0
var dir := 1
var reach := 72.0
var extent := 0.0
var cd := 0
var seg_tex: Texture2D


func begin() -> void:
	hp = 3
	hw = 5
	hh = 7
	home_x = x
	dir = 1 if not tile_block(x + 10, y - 3) else -1
	sprite = make_sprite("res://assets/gfx/eel_head.png", 2)
	seg_tex = load("res://assets/gfx/eel_seg.png")


func tick() -> void:
	t += 1
	cd = maxi(cd - 1, 0)
	var p := game.player
	match state:
		HIDE:
			if cd == 0 and absi(p.iy - 6 - y) < 20 and (p.ix - x) * dir > 0 and absi(p.ix - x) < 96:
				state = OUT
		OUT:
			extent = minf(extent + 4.0, reach)
			if extent >= reach:
				state = BACK
		BACK:
			extent = maxf(extent - 1.4, 0.0)
			if extent <= 0.0:
				state = HIDE
				cd = 80
	x = home_x + int(extent) * dir
	contact = 0 if extent < 4.0 else 1
	hittable = extent >= 4.0


func render() -> void:
	super()
	sprite.flip_h = dir < 0
	sprite.frame = (t / 10) % 2
	queue_redraw()


func _draw() -> void:
	var n := int(extent / 6.0)
	for i in n:
		draw_texture(seg_tex, Vector2(-dir * (6 * (i + 1)) - 3, -5))
