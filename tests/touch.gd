extends Node
## Plays the real main scene using nothing but screen touches, on the on-screen gamepad.
## run: godot --path . --resolution 320x180 res://tests/touch.tscn

var main: Node
var menu: Menu
var pad: TouchPad
var fails := 0


func _ready() -> void:
	G.wipe_save()
	G.force_touch = true
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(30)
	menu = main.menu
	pad = main.touch
	await play()
	G.wipe_save()
	print("TOUCH ", "FAILED: %d" % fails if fails > 0 else "OK")
	get_tree().quit(1 if fails > 0 else 0)


func wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func until(done: Callable, frames := 900) -> void:
	for i in frames:
		if done.call():
			return
		await wait(1)


func expect(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1


func touch(i: int, at: Vector2, on: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = at
	e.pressed = on
	Input.parse_input_event(e)


func drag(i: int, at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = at
	Input.parse_input_event(e)


func tap(at: Vector2) -> void:
	touch(1, at, true)
	await wait(5)
	touch(1, at, false)
	await wait(5)


func button(name: String) -> Vector2:
	return TouchPad.BUTTONS[name].at


## A flick of the stick: down, across, and off again.
func flick(dir: Vector2) -> void:
	var from := Vector2(60, 120)
	touch(0, from, true)
	await wait(2)
	drag(0, from + dir * 16.0)
	await wait(5)
	touch(0, from + dir * 16.0, false)
	await wait(5)


func clear_text() -> void:
	for i in 300:
		if not main.game.hud.dialog_active():
			return
		await tap(button("a"))


func play() -> void:
	expect("the pad is there", pad != null)
	expect("title is up", menu.mode == "title")
	await flick(Vector2.DOWN)
	expect("the stick moves the title menu", menu.sel == 1)
	await flick(Vector2.UP)
	expect("and back", menu.sel == 0)
	await tap(button("a"))
	await wait(20)
	expect("A starts a new game", not menu.active() and not main.game.attract)
	await clear_text()
	expect("A clears the opening text", not main.game.hud.dialog_active())
	var p: Player = main.game.player
	await wait(30)
	var spot := Vector2i(p.ix, p.iy)

	# moving, and the base following the thumb: back across needs no long trip through the middle
	var from := Vector2(60, 120)
	touch(0, from, true)
	await wait(2)
	drag(0, from + Vector2(-16, 0))
	var x0 := p.ix
	await until(func() -> bool: return p.ix < x0 - 16)
	expect("the stick moves the player", p.ix < x0 - 16)
	drag(0, from + Vector2(-46, 0))
	await wait(4)
	drag(0, from + Vector2(-32, 0))
	await wait(8)
	expect("a small move back reverses at once", pad.down.has(JOY_BUTTON_DPAD_RIGHT) and not pad.down.has(JOY_BUTTON_DPAD_LEFT))
	touch(0, from, false)
	await rest(p, spot)
	expect("lifting the thumb stops it", pad.down.is_empty())

	# the whole point of a platformer: two thumbs at once
	x0 = p.ix
	touch(0, from, true)
	await wait(2)
	drag(0, from + Vector2(-16, 0))
	await until(func() -> bool: return p.ix < x0 - 6)
	touch(1, button("a"), true)
	await until(func() -> bool: return p.iy < spot.y - 12)
	expect("running and jumping together", p.iy < spot.y - 12 and p.ix < x0 - 6)
	drag(1, button("a") + Vector2(0, 30))
	await wait(4)
	expect("a thumb sliding off a button keeps holding it", pad.down.has(JOY_BUTTON_A))
	touch(1, button("a"), false)
	touch(0, from, false)
	await rest(p, spot)

	await tap(button("x"))
	var swung := false
	touch(1, button("x"), true)
	for i in 30:
		await wait(1)
		swung = swung or p.atk_t > 0
	touch(1, button("x"), false)
	await wait(30)
	expect("X swings the hook", swung)

	expect("no B before the Reel", not pad.available("b"))
	expect("no Y before the Fork", not pad.available("y"))
	G.give("reel")
	var cast := false
	touch(1, button("b"), true)
	for i in 30:
		await wait(1)
		cast = cast or p.line_t > 0 or p.state == Player.REEL
	touch(1, button("b"), false)
	await wait(30)
	expect("B casts the reel", cast)

	G.give("fork")
	await tap(button("y"))
	await until(func() -> bool: return main.game.fork_menu, 120)
	expect("Y opens the tuning fork", main.game.fork_menu)
	await tap(button("y"))
	await until(func() -> bool: return not main.game.fork_menu, 120)

	# in the black bars of a wide phone, still on the controls
	touch(1, Vector2(340, button("b").y), true)
	await wait(5)
	expect("the bar beside the picture still reaches the buttons", pad.down.has(JOY_BUTTON_B))
	touch(1, Vector2(340, button("b").y), false)
	touch(0, Vector2(-12, 120), true)
	await wait(5)
	expect("and the stick", pad.stick_touch == 0)
	touch(0, Vector2(-12, 120), false)
	await wait(5)

	var sign_ent: Ent = null
	for e in main.game.ents:
		if e.props.get("kind", "") == "sign":
			sign_ent = e
	p.place(sign_ent.x - 8, sign_ent.y)
	await wait(10)
	expect("the use button appears by a sign", pad.available("use"))
	await tap(button("use"))
	await until(func() -> bool: return main.game.hud.dialog_active(), 120)
	expect("and reads it", main.game.hud.dialog_active())
	await clear_text()
	p.place(spot.x, spot.y)
	await wait(10)
	expect("and goes away", not pad.available("use"))

	await tap(button("pause"))
	await until(func() -> bool: return menu.mode == "pause", 120)
	expect("the pause button pauses", get_tree().paused and menu.mode == "pause")
	await flick(Vector2.DOWN)
	expect("the stick works while paused", menu.sel == 1)
	await tap(button("b"))
	await until(func() -> bool: return not menu.active(), 120)
	expect("B resumes", not get_tree().paused and not menu.active())

	# losing focus mid-press must not leave a button stuck down
	touch(1, button("a"), true)
	await wait(5)
	pad.release_all()
	await wait(5)
	expect("letting go of everything when focus goes", pad.down.is_empty() and not Input.is_action_pressed("jump"))

	# a real controller takes over, and a touch hands it back
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = JOY_BUTTON_X
	e.pressed = true
	Input.parse_input_event(e)
	await wait(5)
	expect("a real controller hides the pad", pad.hidden_by_pad)
	e = InputEventJoypadButton.new()
	e.device = 0
	e.button_index = JOY_BUTTON_X
	e.pressed = false
	Input.parse_input_event(e)
	await tap(Vector2(200, 60))
	expect("touching the screen brings it back", not pad.hidden_by_pad)


func rest(p: Player, spot: Vector2i) -> void:
	await wait(4)
	p.place(spot.x, spot.y)
	await wait(12)
