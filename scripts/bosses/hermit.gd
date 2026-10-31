extends Boss
## The Hermit: a crab grown enormous in the dry years, wearing the Salt Bell as a shell.
## Charge it into a wall and the ringing stuns it. It sheds the bell when beaten.

enum { DORMANT, WAKE, WALK, WINDUP, CHARGE, STUN, CROUCH, AIR }

const WALK_SPEED := 38.0
const CHARGE_SPEED := 190.0

var state := DORMANT
var timer := 0
var dir := -1
var ax := 0.0
var next_is_leap := false
var vy := 0.0
var fy := 0.0
var floor_y := 0
var x_min := 0
var x_max := 0
var shell: Sprite2D
var body: Sprite2D
var shake_x := 0.0


func should_spawn() -> bool:
	return not G.flag("hermit_dead")


func begin() -> void:
	boss_name = "THE HERMIT"
	max_hp = 14
	hp = max_hp
	hw = 24
	hh = 38
	contact = 0
	hittable = false
	floor_y = y
	fy = float(y)
	var r := game.room.rect
	x_min = r.position.x + 32 + hw
	x_max = r.end.x - 32 - hw
	body = Sprite2D.new()
	body.texture = load("res://assets/gfx/hermit_body.png")
	body.hframes = 2
	body.centered = false
	body.position = Vector2(-36, -32)
	body.visible = false
	add_child(body)
	shell = Sprite2D.new()
	shell.texture = load("res://assets/gfx/hermit_shell.png")
	shell.offset = Vector2(0, -22)
	shell.position = Vector2(0, -2)
	add_child(shell)


func tick() -> void:
	t += 1
	timer -= 1
	if dying > 0:
		_die_tick()
		return
	match state:
		DORMANT:
			if absi(game.player.ix - x) < 150:
				start_fight()
				var ty := floori(float(floor_y) / 8.0) - 4
				var tx := game.room.rect.position.x >> 3
				game.lock_area(tx, ty, tx + 3, ty + 3)
				game.hud.show_banner(boss_name)
				state = WAKE
				timer = 70
		WAKE:
			shake_x = sin(t * 1.4) * 1.5
			if timer <= 0:
				shake_x = 0.0
				body.visible = true
				contact = 1
				hittable = true
				_to_walk()
		WALK:
			dir = signi(game.player.ix - x) if game.player.ix != x else dir
			_slide(dir * WALK_SPEED * (1.25 if hp < max_hp / 2 else 1.0))
			if timer <= 0:
				if next_is_leap:
					state = CROUCH
					timer = 26
				else:
					state = WINDUP
					timer = 34
					game.snd("gull")
				next_is_leap = not next_is_leap
		WINDUP:
			dir = signi(game.player.ix - x) if game.player.ix != x else dir
			shake_x = sin(t * 2.0) * 2.0
			if timer <= 0:
				shake_x = 0.0
				state = CHARGE
		CHARGE:
			if _slide(dir * CHARGE_SPEED):
				_hit_wall()
			if t % 4 == 0:
				game.fx_dust(x - dir * 18, y, 2)
		STUN:
			if t % 20 == 0:
				game.fx.add(x + randf_range(-12, 12), y - 44, 0, -20, 24, Color("f7d154"))
			if timer <= 0:
				contact = 1
				_to_walk()
		CROUCH:
			shake_x = sin(t * 2.0) * 1.0
			if timer <= 0:
				shake_x = 0.0
				state = AIR
				vy = -300.0
				var goal := clampi(game.player.ix, x_min, x_max)
				ax = (goal - x) / 62.0
				game.snd("jump")
		AIR:
			vy += 9.7
			fy += vy / 60.0
			x = clampi(x + int(ax), x_min, x_max)
			if vy > 0.0 and fy >= float(floor_y):
				fy = float(floor_y)
				_landed()
			y = int(fy)


func _to_walk() -> void:
	state = WALK
	timer = 80 + (t % 40)


## Returns true on reaching the end of the arena.
func _slide(v: float) -> bool:
	ax += v / 60.0
	var steps := int(ax)
	ax -= steps
	x += steps
	if x <= x_min or x >= x_max:
		x = clampi(x, x_min, x_max)
		return true
	return false


func _hit_wall() -> void:
	state = STUN
	timer = 120
	contact = 0
	game.snd("clang")
	game.snd("bell2")
	game.shake = maxf(game.shake, 5.0)
	game.fx.ring_wave(x, y - 22)
	_falling_salt()


func _landed() -> void:
	game.snd("slam")
	game.shake = maxf(game.shake, 5.0)
	game.fx_dust(x, y, 14)
	game.spawn({"kind": "wave", "x": x - hw, "y": floor_y, "dir": -1})
	game.spawn({"kind": "wave", "x": x + hw, "y": floor_y, "dir": 1})
	if hp < max_hp / 2:
		_falling_salt()
	_to_walk()


func _falling_salt() -> void:
	game.fx.burst(x, y - 60, Color("efe6d0"), 10)


func take_hit(dmg: int, d: Vector2i) -> void:
	if state == CHARGE or state == AIR or state == WINDUP:
		clang()
		return
	super(dmg, d)


func on_cast(_aim: Vector2) -> void:
	clang()


func _die_tick() -> void:
	dying += 1
	shake_x = sin(dying * 1.2) * 1.5
	if dying % 8 == 0:
		game.fx_burst(x + randi_range(-20, 20), y - randi_range(4, 36), Color("e8514a"), 6)
	if dying == 90:
		game.snd("bell2")
		game.fx.ring_wave(x, y - 20)
		game.shake = 6.0
	if dying > 90:
		# the naked crab bolts for the nearest crack
		body.position.x += 3.0 * (1 if x < (x_min + x_max) / 2 else -1)
		shell.modulate.a = move_toward(shell.modulate.a, 0.0, 0.03)
	if dying == 150:
		reveal("hermit_dead")
		end_fight()
		dead = true
		game.hud.say("The Hermit has fled. The bell it wore is only a bell again, and the bell is still in tune.")


func render() -> void:
	position = Vector2(x + roundf(shake_x), y)
	var c := Color(3, 3, 3) if flash > 0 else Color.WHITE
	if flash > 0:
		flash -= 1
	if dying == 0:
		body.modulate = c
	body.flip_h = dir > 0
	body.frame = 1 if state in [WINDUP, CROUCH] or (t / 16) % 2 == 0 else 0
	shell.rotation = 0.0 if state != STUN else sin(t * 0.5) * 0.05
	if state == WALK:
		shell.rotation = sin(t * 0.3) * 0.04
	body.position.y = -30.0 if state == STUN else -32.0 + (1 if (t / 8) % 2 == 0 else 0)
