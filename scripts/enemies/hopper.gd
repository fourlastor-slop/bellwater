extends Walker
## A sand flea: sits, then springs at you.

var wait := 40
var air := false
var vx := 0.0


func begin() -> void:
	hp = 1
	hw = 3
	hh = 5
	wait = 30 + x % 40
	sprite = make_sprite("res://assets/gfx/hopper.png", 2)


func tick() -> void:
	t += 1
	apply_gravity()
	if air:
		var nx := x + int(signf(vx))
		if t % 2 == 0 or absf(vx) > 50.0:
			if not tile_block(nx + int(signf(vx)) * hw, y - 2):
				x = nx
		if grounded():
			air = false
			wait = 40 + (t * 7) % 40
		return
	wait -= 1
	if wait <= 0:
		var p := game.player
		var near := absi(p.ix - x) < 110 and absi(p.iy - y) < 70
		dir = signi(p.ix - x) if near and p.ix != x else (1 if t % 2 == 0 else -1)
		vy = -150.0
		vx = dir * 62.0
		air = true


func render() -> void:
	super()
	sprite.frame = 1 if air else 0
