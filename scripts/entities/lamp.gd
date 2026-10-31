extends Ent
## A harbour lamp: rest, save, respawn here.

var lit := false


func begin() -> void:
	solid_body = false
	sprite = make_sprite("res://assets/gfx/lamp.png", 3)
	lit = G.flag("lamp_%d_%d" % [x, y])


func interactive() -> bool:
	return true


func prompt() -> String:
	return "rest"


func interact_point() -> Vector2:
	return Vector2(x, y - 12)


func tick() -> void:
	t += 1
	if lit and t % 30 == 0:
		game.fx.add(x + randf_range(-1, 1), y - 14, randf_range(-3, 3), -14.0, 26, Color("f7d154"))


func render() -> void:
	super()
	sprite.frame = 0 if not lit else 1 + (t / 12) % 2


func interact() -> void:
	lit = true
	G.set_flag("lamp_%d_%d" % [x, y])
	game.set_checkpoint(x, y)
	game.player.breath = G.max_breath()
	game.snd("lamp")
	game.fx.ring_wave(x, y - 12, Color(1.0, 0.85, 0.5))
	game.hud.show_note("Rested. The lamp will remember you.")
