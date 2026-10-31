extends Walker
## A salt-crusted townsperson that still walks. Lunges when close. The sea dissolves it.

var lunge := 0


func should_spawn() -> bool:
	return float(y) < game.water_y


func begin() -> void:
	hp = 3
	hw = 4
	hh = 15
	turn_at_edges = true
	sprite = make_sprite("res://assets/gfx/husk.png", 3)


func tick() -> void:
	t += 1
	apply_gravity()
	if float(y) > game.water_y + 4.0:
		dead = true
		game.fx_burst(x, y - 8, Color("efe6d0"), 14)
		return
	var p := game.player
	var dx := p.ix - x
	var near := absi(dx) < 100 and absi(p.iy - y) < 26
	if lunge > 0:
		lunge -= 1
		if lunge < 30:
			walk(100.0)
		return
	if near:
		dir = signi(dx) if dx != 0 else dir
		if absi(dx) < 50 and t % 90 == 0:
			lunge = 46
			return
		walk(26.0)
	else:
		walk(12.0)


func render() -> void:
	super()
	sprite.flip_h = dir < 0
	sprite.frame = 2 if lunge > 0 else (t / 20) % 2
