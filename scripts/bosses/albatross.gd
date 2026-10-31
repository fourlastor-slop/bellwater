extends Boss
## The Albatross: a bird the size of a boat, with a bell tied round its neck by someone long gone.
## Hook the bell with your line and it comes down to the roofs, where a boathook can reach it.

enum { DORMANT, CIRCLE, WINDUP, SWOOP, GUST, HOOKED, GROUNDED, RISE }

var state := DORMANT
var timer := 0
var pos := Vector2.ZERO
var from := Vector2.ZERO
var to := Vector2.ZERO
var ctrl := Vector2.ZERO
var bird: Sprite2D
var bell: Sprite2D
var face := 1
var arena := Rect2()
var ground_y := 0.0
var gusts := 0


func should_spawn() -> bool:
	return not G.flag("albatross_dead")


func begin() -> void:
	boss_name = "THE ALBATROSS"
	max_hp = 16
	hp = max_hp
	hw = 26
	hh = 28
	contact = 0
	hittable = false
	var r := game.room.rect
	arena = Rect2(r.position.x + 48, r.position.y + 24, 728, 120)
	ground_y = float(y)
	pos = Vector2(arena.end.x, r.position.y - 50)
	bird = Sprite2D.new()
	bird.texture = load("res://assets/gfx/albatross.png")
	bird.hframes = 3
	add_child(bird)
	sprite = bird
	bell = Sprite2D.new()
	bell.texture = load("res://assets/gfx/albatross_bell.png")
	bell.position = Vector2(20, 18)
	add_child(bell)
	visible = false


func tick() -> void:
	t += 1
	timer -= 1
	if dying > 0:
		_die_tick()
		return
	var p := game.player
	match state:
		DORMANT:
			if p.ix < arena.end.x - 8 and p.iy < y + 8:
				start_fight()
				var r := game.room.rect
				var tx0 := (r.end.x >> 3) - 22
				var ty0 := (r.position.y >> 3)
				game.lock_area(tx0, ty0 + 3, tx0, ty0 + 19)
				var wx := r.position.x >> 3
				game.lock_area(wx, ty0 + 16, wx + 3, ty0 + 19)
				game.hud.show_banner(boss_name)
				visible = true
				contact = 1
				hittable = true
				state = CIRCLE
				timer = 200
		CIRCLE:
			var gx := clampf(p.ix + cos(t * 0.022) * 118.0, arena.position.x, arena.end.x)
			var goal := Vector2(gx, arena.position.y + 26.0 + sin(t * 0.04) * 16.0)
			face = 1 if goal.x > pos.x else -1
			pos = pos.lerp(goal, 0.03)
			if t % (70 if hp < max_hp / 2 else 100) == 0:
				_drop_salt()
			if timer <= 0:
				if gusts < 2:
					state = WINDUP
					timer = 30
					game.snd("gull")
					gusts += 1
				else:
					gusts = 0
					state = GUST
					timer = 150
					face = 1 if p.ix > pos.x else -1
		WINDUP:
			pos.y -= 0.8
			if timer <= 0:
				_start_swoop(p)
		SWOOP:
			var k := 1.0 - maxf(timer, 0) / 70.0
			var a := from.lerp(ctrl, k)
			var b := ctrl.lerp(to, k)
			var next := a.lerp(b, k)
			face = 1 if next.x >= pos.x else -1
			pos = next
			if timer <= 0:
				state = CIRCLE
				timer = 150
		GUST:
			pos = pos.lerp(Vector2(p.ix - face * 120.0, arena.position.y + 40.0), 0.04)
			if timer < 120 and t % 3 == 0:
				game.fx.add(pos.x + face * 20.0, pos.y + randf_range(-20, 60), face * 150.0, 0, 50, Color(1, 1, 1, 0.7))
			if timer < 120 and p.state in [Player.NORMAL, Player.SWIM]:
				p.move_x(face * 1.05)
			if timer <= 0:
				state = CIRCLE
				timer = 170
		HOOKED:
			pos.y = minf(pos.y + 3.5, ground_y - 16.0)
			if pos.y >= ground_y - 16.0:
				state = GROUNDED
				timer = 130
				game.snd("slam")
				game.shake = maxf(game.shake, 4.0)
				contact = 0
				game.fx_dust(int(pos.x), int(ground_y), 12)
		GROUNDED:
			if timer <= 0:
				state = RISE
				timer = 40
				contact = 1
		RISE:
			pos.y -= 2.2
			if timer <= 0:
				state = CIRCLE
				timer = 160
	x = int(pos.x)
	y = int(pos.y) + 14


func hookable() -> bool:
	return awake and state in [CIRCLE, WINDUP, SWOOP, GUST] and dying == 0


func on_hooked() -> void:
	state = HOOKED
	timer = 30
	game.snd("clink")
	game.snd("bell4")
	game.fx.ring_wave(int(pos.x), int(pos.y))


func on_cast(_aim: Vector2) -> void:
	if hookable():
		on_hooked()


func _start_swoop(p: Player) -> void:
	from = pos
	var c := p.center()
	to = Vector2(c.x + (c.x - pos.x) * 0.9, arena.position.y + 20.0)
	to.x = clampf(to.x, arena.position.x, arena.end.x)
	ctrl = Vector2((pos.x + c.x) / 2.0 + (c.x - pos.x) * 0.3, c.y + 34.0)
	state = SWOOP
	timer = 70


func _drop_salt() -> void:
	var b: Ent = game.spawn({"kind": "shot", "x": int(pos.x), "y": int(pos.y) + 14})
	if b != null:
		b.vel = Vector2((game.player.ix - pos.x) * 0.25, 70.0)
		b.sprite.texture = load("res://assets/gfx/saltbomb.png")


func _die_tick() -> void:
	dying += 1
	pos.y = minf(pos.y + 1.4, ground_y - 12.0)
	bird.rotation = minf(dying * 0.01, 0.5) * -face
	if dying % 7 == 0:
		game.fx_burst(int(pos.x) + randi_range(-24, 24), int(pos.y) + randi_range(-10, 10), Color("efe6d0"), 7)
	if dying == 100:
		game.snd("bell4")
		game.fx.ring_wave(int(pos.x), int(pos.y))
		game.shake = 6.0
	if dying > 100:
		bird.modulate.a = move_toward(bird.modulate.a, 0.0, 0.02)
		bell.modulate.a = bird.modulate.a
	if dying == 160:
		reveal("albatross_dead")
		end_fight()
		dead = true
		game.hud.say("The rope gives way at last. The bell drops onto the roof, and whatever it was tied to is free of it.")


func render() -> void:
	position = pos.round()
	bird.flip_h = face < 0
	bird.frame = 1 if state in [SWOOP, HOOKED] else (0 if state == GROUNDED else (t / 8) % 3)
	bell.position = Vector2(20 * face, 18)
	bird.modulate = Color(3, 3, 3) if flash > 0 else Color.WHITE
	if flash > 0:
		flash -= 1
