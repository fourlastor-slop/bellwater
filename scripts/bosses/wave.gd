extends Ent
## A shock wave running along the floor.

var dir := 1


func begin() -> void:
	hw = 5
	hh = 5
	hittable = false
	dir = int(props.get("dir", 1))
	sprite = make_sprite("res://assets/gfx/shock.png", 1)
	sprite.flip_h = dir < 0


func tick() -> void:
	t += 1
	x += dir * 2
	if tile_block(x + dir * 6, y - 3) or t > 150:
		dead = true
