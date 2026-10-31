extends Ent
## A spat globule of brine.

var vel := Vector2.ZERO
var pos := Vector2.ZERO
var life := 300


func begin() -> void:
	hw = 2
	hh = 4
	hittable = true
	pos = Vector2(x, y)
	sprite = make_sprite("res://assets/gfx/shot.png", 1)


func tick() -> void:
	pos += vel / 60.0
	x = int(pos.x)
	y = int(pos.y)
	life -= 1
	if life <= 0 or tile_block(x, y - 2):
		dead = true
		game.fx_burst(x, y, Color("5fcdbb"), 3)


func take_hit(_dmg: int, _dir: Vector2i) -> void:
	dead = true
	game.fx_burst(x, y, Color("5fcdbb"), 3)
