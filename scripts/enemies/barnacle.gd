extends Ent
## Grows on a wall and spits at anything nearby.

var cooldown := 60


func begin() -> void:
	hp = 2
	hw = 4
	hh = 8
	sprite = make_sprite("res://assets/gfx/barnacle.png", 2)


func tick() -> void:
	t += 1
	cooldown -= 1
	if cooldown <= 0:
		var p := game.player
		var c := Vector2(x, y - 4)
		var pc := p.center()
		if c.distance_to(pc) < 130.0 and game.line_clear(c, pc):
			cooldown = 120
			game.snd("spit")
			var s: Ent = game.spawn({"kind": "shot", "x": x, "y": y - 2})
			if s != null:
				s.vel = (pc - c).normalized() * 74.0
		else:
			cooldown = 30


func render() -> void:
	super()
	sprite.frame = 0 if cooldown > 20 else 1
