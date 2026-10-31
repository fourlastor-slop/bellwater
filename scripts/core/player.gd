class_name Player
extends Node2D
## The player. All motion is integer pixels with a sub-pixel remainder, against the tile grid.
## tick() is deterministic, and the planner in tests/ reuses it through save_state/load_state.

enum { NORMAL, SWIM, CLIMB, REEL, HANG, RINGING, HURT, DEAD, STILL }

const HALF_W := 4
const HEIGHT := 13

const RUN := 92.0
const ACCEL := 1000.0
const FRICTION := 1400.0
const AIR_ACCEL := 760.0
const GRAVITY := 640.0
const FALL_MULT := 1.2
const JUMP_V := 192.0
const MAX_FALL := 250.0
const COYOTE := 6
const BUFFER := 7

const SWIM_SPEED := 62.0
const DIVE_SPEED := 74.0
const WATER_JUMP := 172.0
const FLOAT_DEPTH := 7
const CLIMB_SPEED := 58.0
const REEL_SPEED := 270.0
const PUFF_V := 176.0
const DASH_V := 190.0

const ATTACK_TICKS := 16
const ATTACK_LIVE_FROM := 2
const ATTACK_LIVE_TO := 9
const ATTACK_COOLDOWN := 22

var game: Game
var pad := Pad.new()

var state := NORMAL
var ix := 0
var iy := 0
var rx := 0.0
var ry := 0.0
var vx := 0.0
var vy := 0.0
var facing := 1
var grounded := false
var coyote := 0
var buffer := 0
var drop_ticks := 0
var jump_held := false
var puffs := 0
var dash_cd := 0
var diving := false
var ride: Node = null

var hp := 3
var breath := 10.0
var iframes := 0
var state_t := 0
var atk_t := 0
var atk_cd := 0
var atk_dir := Vector2i.RIGHT
var hit_ids := {}
var reel_target := Vector2i.ZERO
var reel_stuck := 0
var line_t := 0
var line_end := Vector2.ZERO
var line_hit: Object = null
var safe := Vector2i.ZERO

var carried := false
var anim_t := 0
var vis_dy := 0.0
var step_snd := 0

var sprite: Sprite2D
var scarf: Array[Vector2] = []


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/gfx/player.png")
	sprite.hframes = 18
	sprite.vframes = 2
	sprite.centered = false
	sprite.position = Vector2(-8, -16)
	add_child(sprite)
	for i in 6:
		scarf.append(Vector2.ZERO)


func place(x: int, y: int) -> void:
	ix = x
	iy = y
	rx = 0.0
	ry = 0.0
	vx = 0.0
	vy = 0.0
	state = NORMAL
	ride = null
	diving = false
	safe = Vector2i(x, y)
	position = Vector2(ix, iy)
	for i in scarf.size():
		scarf[i] = Vector2(ix, iy - 8)


func head_y() -> int:
	return iy - HEIGHT


func center() -> Vector2:
	return Vector2(ix, iy - HEIGHT / 2)


func rect() -> Rect2i:
	return Rect2i(ix - HALF_W, iy - HEIGHT, HALF_W * 2, HEIGHT)


func attacking() -> bool:
	return atk_t > 0 and atk_t <= ATTACK_TICKS - ATTACK_LIVE_FROM and atk_t > ATTACK_TICKS - ATTACK_LIVE_TO


## The hook's strike area for the current attack.
func attack_rect() -> Rect2i:
	var c := center()
	if atk_dir == Vector2i.UP:
		return Rect2i(int(c.x) - 8, iy - HEIGHT - 16, 16, 20)
	if atk_dir == Vector2i.DOWN:
		return Rect2i(int(c.x) - 8, iy - 2, 16, 18)
	var x := ix if atk_dir.x > 0 else ix - 22
	return Rect2i(x, iy - HEIGHT - 2, 22, HEIGHT + 3)


func save_state() -> Array:
	return [state, ix, iy, rx, ry, vx, vy, facing, grounded, coyote, buffer, drop_ticks, jump_held,
		puffs, dash_cd, diving, reel_target, reel_stuck, line_t, breath, state_t]


func load_state(a: Array) -> void:
	state = a[0]
	ix = a[1]
	iy = a[2]
	rx = a[3]
	ry = a[4]
	vx = a[5]
	vy = a[6]
	facing = a[7]
	grounded = a[8]
	coyote = a[9]
	buffer = a[10]
	drop_ticks = a[11]
	jump_held = a[12]
	puffs = a[13]
	dash_cd = a[14]
	diving = a[15]
	reel_target = a[16]
	reel_stuck = a[17]
	line_t = a[18]
	breath = a[19]
	state_t = a[20]


# --- collision -------------------------------------------------------------

func box_blocked(x: int, y: int) -> bool:
	var m := game.map
	var x0 := floori((x - HALF_W) / 8.0)
	var x1 := floori((x + HALF_W - 1) / 8.0)
	var y0 := floori((y - HEIGHT) / 8.0)
	var y1 := floori((y - 1) / 8.0)
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			if m.is_block(m.get_tile(tx, ty)):
				return true
	return false


## True when feet at y would rest on a one-way surface (plank, ladder top) or floating platform.
func oneway_under(x: int, y: int) -> bool:
	if drop_ticks > 0:
		return false
	if y % 8 == 0:
		var m := game.map
		var ty := y / 8
		var above := ty - 1
		for tx in range(floori((x - HALF_W) / 8.0), floori((x + HALF_W - 1) / 8.0) + 1):
			var t := m.get_tile(tx, ty)
			if t == WorldMap.ONEWAY:
				return true
			if t == WorldMap.LADDER and m.get_tile(tx, above) != WorldMap.LADDER:
				return true
	return platform_under(x, y) != null


func platform_under(x: int, y: int) -> Node:
	if drop_ticks > 0:
		return null
	for p in game.platforms:
		if p.top() == y and x + HALF_W > p.left() and x - HALF_W < p.right():
			return p
	return null


func on_ground_at(x: int, y: int) -> bool:
	return box_blocked(x, y + 1) or oneway_under(x, y)


func move_x(dx: float) -> bool:
	rx += dx
	var step := roundi(rx)
	if step == 0:
		return false
	rx -= step
	var sgn := signi(step)
	while step != 0:
		if box_blocked(ix + sgn, iy):
			if _try_step_up(sgn) or _try_ledge(sgn):
				continue
			rx = 0.0
			return true
		ix += sgn
		step -= sgn
	return false


func move_y(dy: float) -> bool:
	ry += dy
	var step := roundi(ry)
	if step == 0:
		return false
	ry -= step
	var sgn := signi(step)
	while step != 0:
		if sgn > 0:
			if box_blocked(ix, iy + 1) or oneway_under(ix, iy):
				ry = 0.0
				return true
		elif box_blocked(ix, iy - 1):
			if _try_corner_nudge():
				continue
			ry = 0.0
			return true
		iy += sgn
		step -= sgn
	return false


## Walk up a single-tile step without jumping; the sprite eases up in _render.
func _try_step_up(sgn: int) -> bool:
	if not grounded or state != NORMAL or pad.x != sgn:
		return false
	var drop := iy % 8
	var up := 8 + drop if drop != 0 else 8
	if box_blocked(ix, iy - up) or box_blocked(ix + sgn, iy - up):
		return false
	iy -= up
	ix += sgn
	vis_dy += up
	return true


## Forgive a jump that came up a few pixels short of a ledge.
func _try_ledge(sgn: int) -> bool:
	if state != NORMAL or grounded or pad.x != sgn or vy < -60.0:
		return false
	for k in range(1, 6):
		if not box_blocked(ix + sgn, iy - k):
			if box_blocked(ix, iy - k):
				return false
			iy -= k
			ix += sgn
			vis_dy += k
			return true
	return false


## Slide around a ceiling corner rather than bonking on its last few pixels.
func _try_corner_nudge() -> bool:
	for k in [1, 2, 3]:
		for sgn in [1, -1]:
			if not box_blocked(ix + sgn * k, iy) and not box_blocked(ix + sgn * k, iy - 1):
				ix += sgn * k
				return true
	return false


# --- main tick --------------------------------------------------------------

func tick() -> void:
	anim_t += 1
	state_t += 1
	if iframes > 0:
		iframes -= 1
	if atk_cd > 0:
		atk_cd -= 1
	if atk_t > 0:
		atk_t -= 1
		if atk_t == 0:
			hit_ids.clear()
	if drop_ticks > 0:
		drop_ticks -= 1
	if dash_cd > 0:
		dash_cd -= 1
	if line_t > 0 and state != REEL:
		line_t -= 1
	buffer = BUFFER if pad.jump_p else maxi(buffer - 1, 0)

	match state:
		NORMAL: _normal()
		SWIM: _swim()
		CLIMB: _climb()
		REEL: _reel()
		HANG: _hang()
		RINGING: _ringing()
		HURT: _hurt()
		DEAD, STILL: pass

	_breathe()
	if state in [NORMAL, SWIM, CLIMB, HANG]:
		_hazards()
	if not grounded:
		ride = null


func enter(new_state: int) -> void:
	state = new_state
	state_t = 0


func in_water_depth() -> int:
	return iy - int(game.water_y)


func head_under() -> bool:
	return head_y() > int(game.water_y) + 1


func _normal() -> void:
	var dt := 1.0 / 60.0
	var was_ground := grounded
	grounded = on_ground_at(ix, iy)

	if in_water_depth() >= 9 and not (grounded and in_water_depth() < 12):
		_enter_swim()
		return

	var target := pad.x * RUN
	if in_water_depth() > 2:
		target *= 0.8
	var acc := ACCEL if grounded else AIR_ACCEL
	if pad.x != 0:
		vx = move_toward(vx, target, acc * dt)
		if atk_t == 0:
			facing = pad.x
	else:
		vx = move_toward(vx, 0.0, (FRICTION if grounded else AIR_ACCEL * 0.5) * dt)

	if grounded:
		coyote = COYOTE
		puffs = 1 if G.has("bellows") else 0
		if vy > 0:
			vy = 0.0
		if not was_ground:
			_landed()
		if ride == null:
			ride = platform_under(ix, iy)
		_remember_safe()
	else:
		coyote = maxi(coyote - 1, 0)

	# ladders
	if pad.y != 0 and _ladder_here(pad.y):
		if not (pad.y > 0 and grounded and game.map.get_tile(ix >> 3, iy >> 3) != WorldMap.LADDER):
			_enter_climb()
			return

	# jumping
	if buffer > 0 and (grounded or coyote > 0):
		if pad.y > 0 and _on_oneway_only():
			drop_ticks = 10
			buffer = 0
			iy += 1
		else:
			_do_jump(JUMP_V)
	elif pad.jump_p and puffs > 0 and not grounded:
		puffs -= 1
		_do_jump(PUFF_V)
		game.fx_puff(ix, iy)
		game.snd("puff")

	if jump_held and not pad.jump:
		jump_held = false
		if vy < -60.0:
			vy *= 0.5

	var g := GRAVITY
	if vy > 0:
		g *= FALL_MULT
	vy = minf(vy + g * dt, MAX_FALL)

	_common_actions()

	if move_x(vx * dt):
		vx = 0.0
	if move_y(vy * dt):
		vy = 0.0

	_stick_to_steps(was_ground)
	grounded = on_ground_at(ix, iy)


func _remember_safe() -> void:
	var m := game.map
	var t0 := m.get_tile((ix - HALF_W) >> 3, iy >> 3)
	var t1 := m.get_tile((ix + HALF_W - 1) >> 3, iy >> 3)
	if t0 == WorldMap.SOLID and t1 == WorldMap.SOLID and ride == null:
		safe = Vector2i(ix, iy)


func _landed() -> void:
	game.fx_dust(ix, iy, 3)
	game.snd("land")


func _do_jump(v: float) -> void:
	vy = -v
	buffer = 0
	coyote = 0
	grounded = false
	jump_held = true
	game.fx_dust(ix, iy, 2)
	game.snd("jump")


func _on_oneway_only() -> bool:
	return not box_blocked(ix, iy + 1) and oneway_under(ix, iy)


func _stick_to_steps(was_ground: bool) -> void:
	if not was_ground or state != NORMAL or vy < 0.0 or on_ground_at(ix, iy) or ride != null:
		return
	for k in range(1, 9):
		if box_blocked(ix, iy + k):
			break
		if on_ground_at(ix, iy + k):
			iy += k
			vis_dy -= k
			vy = 0.0
			return


func _ladder_here(dir: int) -> bool:
	var m := game.map
	var ty := (iy - 7 if dir < 0 else iy + 1) >> 3
	return m.get_tile(ix >> 3, ty) == WorldMap.LADDER


func _enter_climb() -> void:
	enter(CLIMB)
	ix = (ix >> 3) * 8 + 4
	rx = 0.0
	vx = 0.0
	vy = 0.0
	drop_ticks = 2
	puffs = 1 if G.has("bellows") else 0


func _climb() -> void:
	var dt := 1.0 / 60.0
	var m := game.map
	if pad.jump_p:
		enter(NORMAL)
		vx = pad.x * RUN
		if pad.y >= 0:
			_do_jump(JUMP_V * 0.8)
		return
	var dy := pad.y * CLIMB_SPEED * dt
	drop_ticks = 2
	if pad.y != 0:
		if move_y(dy):
			enter(NORMAL)
			return
	var here := m.get_tile(ix >> 3, (iy - 2) >> 3)
	if here != WorldMap.LADDER:
		enter(NORMAL)
		drop_ticks = 0
		if iy % 8 < 4 and pad.y < 0:
			iy -= iy % 8
		ry = 0.0
		return


func _common_actions() -> void:
	if pad.attack_p and atk_cd <= 0:
		_start_attack()
	if pad.cast_p and G.has("reel"):
		_cast()


func _start_attack() -> void:
	atk_t = ATTACK_TICKS
	atk_cd = ATTACK_COOLDOWN
	hit_ids.clear()
	if pad.y < 0:
		atk_dir = Vector2i.UP
	elif pad.y > 0 and not grounded:
		atk_dir = Vector2i.DOWN
	else:
		atk_dir = Vector2i(facing, 0)
	game.snd("swing")


## Called by the game when the hook lands on something.
func attack_recoil() -> void:
	if atk_dir == Vector2i.DOWN and state == NORMAL:
		vy = -170.0
		jump_held = false
		puffs = 1 if G.has("bellows") else 0
	elif atk_dir.x != 0 and state == NORMAL:
		vx -= atk_dir.x * 40.0


func _enter_swim() -> void:
	if state != SWIM:
		game.fx_splash(ix, int(game.water_y), absf(vy))
		game.snd("splash")
	enter(SWIM)
	jump_held = false
	puffs = 1 if G.has("bellows") else 0


func _swim() -> void:
	var dt := 1.0 / 60.0
	grounded = false
	var depth := in_water_depth()
	if depth < 3:
		enter(NORMAL)
		return
	if G.has("helm") and pad.y > 0:
		diving = true
	var head_clear := head_y() < int(game.water_y) - 1
	if head_clear and vy <= 0.0:
		diving = false
	if diving:
		_swim_dive(dt)
	else:
		_swim_surface(dt, depth)
	_common_actions()
	if state != SWIM:
		return
	if move_x(vx * dt):
		vx = 0.0
	if move_y(vy * dt):
		vy = 0.0
	if on_ground_at(ix, iy) and in_water_depth() < 9:
		enter(NORMAL)


func _swim_surface(dt: float, depth: int) -> void:
	var delta := depth - FLOAT_DEPTH
	var want := clampf(-delta * 7.0, -92.0, 70.0)
	vy = move_toward(vy, want, 900.0 * dt)
	vx = move_toward(vx, pad.x * SWIM_SPEED, 420.0 * dt)
	if pad.x != 0 and atk_t == 0:
		facing = pad.x
	if buffer > 0 and absi(delta) <= 6:
		buffer = 0
		enter(NORMAL)
		vy = -WATER_JUMP
		jump_held = true
		game.fx_splash(ix, int(game.water_y), 90.0)
		game.snd("jump")


func _swim_dive(dt: float) -> void:
	var drift := -6.0
	var want := Vector2(pad.x, pad.y)
	if want.length_squared() > 1.0:
		want = want.normalized()
	vx = move_toward(vx, want.x * DIVE_SPEED, 460.0 * dt)
	vy = move_toward(vy, want.y * DIVE_SPEED + (drift if pad.y == 0 else 0.0), 460.0 * dt)
	if pad.x != 0 and atk_t == 0:
		facing = pad.x
	if buffer > 0 and G.has("bellows") and dash_cd == 0:
		buffer = 0
		dash_cd = 44
		var d := want if want != Vector2.ZERO else Vector2(facing, 0)
		vx = d.normalized().x * DASH_V
		vy = d.normalized().y * DASH_V
		game.fx_puff(ix, iy)
		game.snd("puff")
	if anim_t % 40 == 0:
		game.fx_bubble(ix + facing * 3, head_y() + 3)


func _breathe() -> void:
	var dt := 1.0 / 60.0
	if game.returning:
		breath = G.max_breath()
	elif head_under():
		breath -= dt
		if breath < 0.0:
			breath = 1.2
			hurt(1, ix)
	else:
		breath = minf(breath + dt * 6.0, G.max_breath())


# --- the reel ------------------------------------------------------------------

func _cast() -> void:
	var aim := Vector2(pad.x, pad.y)
	if aim == Vector2.ZERO:
		aim = Vector2(facing, 0)
	aim = aim.normalized()
	var c := center()
	var reach := G.reel_range()
	if game.boss != null and is_instance_valid(game.boss) and game.boss.has_method("hookable") and game.boss.hookable():
		if c.distance_to(game.boss.position) < reach + 28.0:
			line_end = game.boss.position
			line_t = 12
			game.boss.on_hooked()
			game.snd("cast")
			return
	var best := best_ring(aim)
	if best != Vector2i.ZERO:
		reel_target = best
		line_end = Vector2(best)
		enter(REEL)
		line_t = 1
		reel_stuck = 0
		atk_t = 0
		vx = 0.0
		vy = 0.0
		diving = false
		game.snd("reel")
		return
	var hit := game.cast_at(c, aim, reach)
	line_end = hit.pos
	line_hit = hit.ent
	line_t = 12
	game.snd("cast")


## The ring a cast would take, given where the player is aiming.
func best_ring(aim: Vector2) -> Vector2i:
	var c := center()
	var reach := G.reel_range()
	var best := Vector2i.ZERO
	var best_score := INF
	for ring in game.map.rings:
		var d := Vector2(ring) - c
		var dist := d.length()
		if dist > reach or dist < 4.0:
			continue
		var along := d.normalized().dot(aim)
		if along < 0.15:
			continue
		var score := dist * (1.6 - along)
		if score < best_score and game.line_clear(c, Vector2(ring)):
			best_score = score
			best = ring
	return best


func aim_vector() -> Vector2:
	var aim := Vector2(pad.x, pad.y)
	if aim == Vector2.ZERO:
		aim = Vector2(facing, 0)
	return aim.normalized()


func _reel() -> void:
	var dt := 1.0 / 60.0
	var goal := Vector2(reel_target.x, reel_target.y + HEIGHT + 3)
	# the line flies out before it starts to pull
	if state_t < 5:
		return
	var here := Vector2(ix, iy)
	var d := goal - here
	var dist := d.length()
	if dist < 3.0:
		ix = int(goal.x)
		iy = int(goal.y)
		rx = 0.0
		ry = 0.0
		enter(HANG)
		puffs = 1 if G.has("bellows") else 0
		game.fx_dust(reel_target.x, reel_target.y, 2)
		game.snd("clink")
		return
	var v := d.normalized() * minf(REEL_SPEED, dist * 60.0)
	var bx := move_x(v.x * dt)
	var by := move_y(v.y * dt)
	if bx or by:
		reel_stuck += 1
		if reel_stuck > 8:
			enter(NORMAL)
			line_t = 0
			vy = -60.0


func _hang() -> void:
	grounded = false
	if pad.cast_p:
		_cast()
		if state == REEL:
			return
	if pad.attack_p and atk_cd <= 0:
		_start_attack()
	if pad.jump_p:
		enter(NORMAL)
		vx = pad.x * RUN
		vy = -JUMP_V * 0.92
		jump_held = true
		game.snd("jump")
	elif pad.y > 0:
		enter(NORMAL)
		vy = 30.0


# --- bell rope, damage ------------------------------------------------------------

func start_ringing() -> void:
	enter(RINGING)
	vx = 0.0
	vy = 0.0


func _ringing() -> void:
	vy = 0.0
	if state_t >= 60:
		enter(NORMAL)


func _hazards() -> void:
	if iframes > 0:
		return
	var m := game.map
	var r := rect()
	var x0 := (r.position.x + 1) >> 3
	var x1 := (r.end.x - 2) >> 3
	var y0 := (r.position.y + 2) >> 3
	var y1 := (r.end.y - 1) >> 3
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			if m.get_tile(tx, ty) == WorldMap.SPIKE:
				if game.spike_lethal(self):
					return


func hurt(amount: int, from_x: int) -> void:
	if iframes > 0 or state == DEAD or state == RINGING or state == STILL:
		return
	hp -= amount
	iframes = 80
	game.on_player_hurt()
	if hp <= 0:
		enter(DEAD)
		return
	if state == HANG or state == REEL or state == CLIMB:
		line_t = 0
	enter(HURT)
	vx = 110.0 if ix >= from_x else -110.0
	vy = -130.0
	atk_t = 0


func _hurt() -> void:
	var dt := 1.0 / 60.0
	vy = minf(vy + GRAVITY * dt, MAX_FALL)
	if in_water_depth() >= 9:
		vy *= 0.8
		vx *= 0.9
	if move_x(vx * dt):
		vx = 0.0
	if move_y(vy * dt):
		vy = 0.0
	if state_t >= 16:
		enter(NORMAL)
		grounded = on_ground_at(ix, iy)


# --- drawing ------------------------------------------------------------------------

func frame_name() -> int:
	if carried:
		return 8 + (anim_t / 8) % 2
	match state:
		SWIM:
			if diving:
				return 8 + (anim_t / 12) % 2
			return 8 + (anim_t / 16) % 2
		CLIMB:
			return 14 + (iy / 6) % 2
		REEL, HANG:
			return 12
		RINGING:
			return 16 + (1 if state_t % 40 > 12 and state_t % 40 < 32 else 0)
		HURT, DEAD:
			return 13
	if atk_t > ATTACK_TICKS - 6:
		return 10
	if atk_t > 2:
		return 11
	if not grounded:
		return 6 if vy < 0 else 7
	if absf(vx) > 12.0:
		return 2 + (anim_t / 5) % 4
	return (anim_t / 34) % 2


func render() -> void:
	position = Vector2(ix, iy)
	vis_dy = move_toward(vis_dy, 0.0, 1.5)
	var helm := 18 if G.has("helm") else 0
	sprite.frame = frame_name() + helm
	sprite.flip_h = facing < 0
	sprite.position = Vector2(-8, -16 + roundf(vis_dy))
	sprite.visible = iframes == 0 or (anim_t / 3) % 2 == 0 or state == DEAD
	if state == DEAD:
		sprite.modulate = Color(1, 1, 1, 0.5)
	else:
		sprite.modulate = Color.WHITE
	_scarf_step()
	queue_redraw()


func _scarf_step() -> void:
	var anchor := Vector2(ix - facing * 2, iy - 8 + vis_dy)
	scarf[0] = anchor
	var drift := -vx * 0.012
	for i in range(1, scarf.size()):
		var p := scarf[i]
		var prev := scarf[i - 1]
		p.y += 0.7
		p.x += drift - facing * 0.25
		var d := p - prev
		if d.length() > 2.0:
			p = prev + d.normalized() * 2.0
		scarf[i] = p


func _draw() -> void:
	if sprite == null or not sprite.visible:
		return
	var o := Vector2(ix, iy)
	for i in range(scarf.size() - 1):
		var a := (scarf[i] - o).round()
		var col := Color("e8514a") if i < 3 else Color("a02c3e")
		draw_rect(Rect2(a, Vector2(2 if i < 3 else 1, 2 if i < 2 else 1)), col)
	# the line
	var t := -1.0
	if state == REEL:
		t = minf(state_t / 5.0, 1.0)
	elif state == HANG:
		t = 1.0
	elif line_t > 0:
		t = sin(line_t / 12.0 * PI)
	if t > 0.0:
		var from := Vector2(facing * 3, -9)
		var to := (line_end - o) * t + from * (1.0 - t)
		_draw_line(from, to)
	if atk_t > 2:
		_draw_hook()


func _draw_line(a: Vector2, b: Vector2) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	for i in n + 1:
		var p := a.lerp(b, float(i) / maxf(n, 1)).round()
		draw_rect(Rect2(p, Vector2.ONE), Color("efe6d0"))
	draw_rect(Rect2(b.round() - Vector2(1, 1), Vector2(3, 3)), Color("c98a3a"))


func _draw_hook() -> void:
	# the boathook: pole plus an arc swept by the swing
	var p := 1.0 - float(atk_t) / ATTACK_TICKS
	var col := Color("efe6d0")
	var pole := Color("7a5a44")
	var c := Vector2(0, -8)
	var a0: float
	var a1: float
	if atk_dir == Vector2i.UP:
		a0 = -PI * 0.5 - 0.9 * facing
		a1 = -PI * 0.5 + 0.9 * facing
	elif atk_dir == Vector2i.DOWN:
		a0 = PI * 0.5 + 0.9 * facing
		a1 = PI * 0.5 - 0.9 * facing
	else:
		var f := facing
		a0 = -1.1 if f > 0 else PI + 1.1
		a1 = 0.9 if f > 0 else PI - 0.9
	var a := lerpf(a0, a1, minf(p * 2.2, 1.0))
	var tip := c + Vector2(cos(a), sin(a)) * 18.0
	var n := 16
	for i in n:
		var q := c.lerp(tip, float(i) / n).round()
		draw_rect(Rect2(q, Vector2.ONE), pole)
	draw_rect(Rect2(tip.round() - Vector2(1, 1), Vector2(3, 2)), col)
	if atk_t > ATTACK_TICKS - ATTACK_LIVE_TO:
		var steps := 10
		for i in steps:
			var b := lerpf(a0, a, float(i) / steps)
			var r := Vector2(cos(b), sin(b)) * 18.0 + c
			draw_rect(Rect2(r.round(), Vector2.ONE), Color(1, 1, 1, 0.75))
