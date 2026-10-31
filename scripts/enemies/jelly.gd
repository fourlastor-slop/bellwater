extends Ent
## Drifts. Stings. Rests in a damp heap when the sea goes out.

var home := Vector2.ZERO
var pos := Vector2.ZERO


func begin() -> void:
	hp = 3
	hw = 5
	hh = 9
	home = Vector2(x, y)
	pos = home
	sprite = make_sprite("res://assets/gfx/jelly.png", 2)


func tick() -> void:
	t += 1
	var w := game.water_y
	if pos.y < w + 4.0 and home.y < w + 4.0:
		if not tile_block(int(pos.x), int(pos.y) + 1):
			pos.y += 1.6
	else:
		var goal_y := maxf(home.y, w + 8.0) + sin(t * 0.03 + home.x) * 12.0
		pos.y += (goal_y - pos.y) * 0.03
		pos.x = home.x + sin(t * 0.011 + home.y) * 26.0
	x = int(pos.x)
	y = int(pos.y)


func render() -> void:
	super()
	sprite.frame = (t / 18) % 2
