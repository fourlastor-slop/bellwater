extends Ent
## A tide bell. Ringing it sends the whole sea to this bell's mark.
## Stripes on the bell's frame count the level. Also a checkpoint.

var level := 1
var swing := 0.0
var swing_v := 0.0
var bell: Sprite2D
var stand: Sprite2D
var ringing := 0
var locked_text := ""


func should_spawn() -> bool:
	var need: String = props.get("requires", "")
	return need == "" or G.flag(need)


func begin() -> void:
	solid_body = false
	level = int(props.get("level", 1))
	stand = Sprite2D.new()
	stand.texture = load("res://assets/gfx/bell_stand.png")
	stand.centered = false
	stand.position = Vector2(-11, -22)
	add_child(stand)
	bell = Sprite2D.new()
	bell.texture = load("res://assets/gfx/bell.png")
	bell.offset = Vector2(0, 7)
	bell.position = Vector2(0, -19)
	add_child(bell)


func interactive() -> bool:
	return ringing == 0


func prompt() -> String:
	return "ring"


func interact_point() -> Vector2:
	return Vector2(x, y - 8)


func interact() -> void:
	ringing = 1
	game.player.start_ringing()
	game.player.facing = 1 if x >= game.player.ix else -1


func tick() -> void:
	t += 1
	if ringing > 0:
		ringing += 1
		if ringing == 22:
			_strike()
		if ringing > 62:
			ringing = 0
	swing_v += -swing * 0.03
	swing_v *= 0.985
	swing += swing_v


func _strike() -> void:
	swing_v = 0.09
	game.snd("bell%d" % level)
	game.fx.ring_wave(x, y - 14)
	game.shake = maxf(game.shake, 3.0)
	game.hitstop = 4
	game.player.breath = G.max_breath()
	if props.has("flag"):
		G.set_flag(str(props.flag))
	if not game.call_tide(level):
		game.hud.show_note("The sea is already at this bell's mark.")
	game.set_checkpoint(x, y)


func render() -> void:
	position = Vector2(x, y)
	bell.rotation = swing
	queue_redraw()


func _draw() -> void:
	# stripes on the post count this bell's level
	for i in level:
		draw_rect(Rect2(-9, -6 - i * 3, 2, 2), Color("f7d154"))
