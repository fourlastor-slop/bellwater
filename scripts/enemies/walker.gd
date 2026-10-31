class_name Walker
extends Ent
## Something with feet: falls, walks, turns at walls and ledges.

var dir := -1
var acc := 0.0
var vy := 0.0
var turn_at_edges := true


func grounded() -> bool:
	return y % 8 == 0 and (stand_tile(x - hw + 1, y) or stand_tile(x + hw - 1, y))


func apply_gravity() -> void:
	if grounded() and vy >= 0.0:
		vy = 0.0
		return
	vy = minf(vy + 9.0, 220.0)
	var step := int(vy / 60.0)
	if step == 0 and vy > 0.0:
		step = 1
	var sgn := signi(step)
	for i in absi(step):
		if sgn > 0 and grounded():
			vy = 0.0
			return
		if sgn < 0 and tile_block(x, y - hh - 1):
			vy = 0.0
			return
		y += sgn


func walk(speed: float) -> void:
	acc += speed / 60.0
	while acc >= 1.0:
		acc -= 1.0
		var front := x + dir + dir * hw
		var blocked := tile_block(front, y - 2) or tile_block(front, y - hh)
		var hazard := game.map.get_tile(front >> 3, (y - 2) >> 3) == WorldMap.SPIKE
		var no_floor := turn_at_edges and not stand_tile(front, y)
		if blocked or hazard or no_floor:
			dir = -dir
			return
		x += dir


func nudge(dx: int) -> void:
	var sgn := signi(dx)
	for i in absi(dx):
		if tile_block(x + sgn + sgn * hw, y - 2):
			return
		x += sgn


func take_hit(dmg: int, hit_dir: Vector2i) -> void:
	super(dmg, hit_dir)
	if hit_dir.x != 0:
		nudge(hit_dir.x * 5)
