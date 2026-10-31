extends Node
## Plays the real main scene using nothing but gamepad events: menus, movement, every action.
## The events are the same InputEventJoypad* types Godot produces from a physical controller.
## run: godot --path . res://tests/gamepad.tscn

var main: Node
var fails := 0
var device := 0


func _ready() -> void:
	G.wipe_save()
	bindings()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(30)
	await play()
	G.wipe_save()
	print("GAMEPAD ", "FAILED: %d" % fails if fails > 0 else "OK")
	get_tree().quit(1 if fails > 0 else 0)


func wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func expect(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1


func button(b: int, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = device
	e.button_index = b
	e.pressed = down
	e.pressure = 1.0 if down else 0.0
	Input.parse_input_event(e)


func axis(a: int, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = device
	e.axis = a
	e.axis_value = v
	Input.parse_input_event(e)


func tap(b: int) -> void:
	button(b, true)
	await wait(5)
	button(b, false)
	await wait(5)


## Every binding, from the first controller and from a second one. A pad isn't always device 0.
func bindings() -> void:
	var buttons := {
		JOY_BUTTON_A: ["jump", "accept"], JOY_BUTTON_B: ["cast", "back"], JOY_BUTTON_X: ["attack"],
		JOY_BUTTON_Y: ["fork"], JOY_BUTTON_START: ["pause"], JOY_BUTTON_BACK: ["map"],
		JOY_BUTTON_DPAD_LEFT: ["left"], JOY_BUTTON_DPAD_RIGHT: ["right"],
		JOY_BUTTON_DPAD_UP: ["up"], JOY_BUTTON_DPAD_DOWN: ["down"],
	}
	var sticks := {"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0], "up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0]}
	for dev in [0, 1]:
		device = dev
		var bad: Array[String] = []
		for b: int in buttons:
			button(b, true)
			Input.flush_buffered_events()
			for a: String in buttons[b]:
				if not Input.is_action_pressed(a):
					bad.append("%s (button %d)" % [a, b])
			button(b, false)
			Input.flush_buffered_events()
		for a: String in sticks:
			axis(sticks[a][0], sticks[a][1])
			Input.flush_buffered_events()
			if not Input.is_action_pressed(a):
				bad.append("%s (stick)" % a)
			axis(sticks[a][0], 0.0)
			Input.flush_buffered_events()
		expect("controller %d drives every action %s" % [dev, bad if not bad.is_empty() else ""], bad.is_empty())
	device = 0


func play() -> void:
	var menu: Menu = main.menu
	expect("title is up", menu.mode == "title")
	await tap(JOY_BUTTON_DPAD_DOWN)
	expect("d-pad moves the title menu", menu.sel == 1)
	axis(JOY_AXIS_LEFT_Y, -1.0)
	await wait(6)
	axis(JOY_AXIS_LEFT_Y, 0.0)
	await wait(6)
	expect("stick moves the title menu", menu.sel == 0)
	await tap(JOY_BUTTON_A)
	await wait(20)
	expect("A starts a new game", not menu.active() and not main.game.attract)
	for i in 300:
		if not main.game.hud.dialog_active():
			break
		await tap(JOY_BUTTON_A)
	expect("A clears the opening text", not main.game.hud.dialog_active())
	var p: Player = main.game.player
	await wait(30)

	var spot := Vector2i(p.ix, p.iy)
	var x0 := p.ix
	axis(JOY_AXIS_LEFT_X, -1.0)
	await until(func() -> bool: return p.ix < x0 - 16)
	axis(JOY_AXIS_LEFT_X, 0.0)
	expect("stick moves the player", p.ix < x0 - 16)
	await rest(p, spot)
	button(JOY_BUTTON_DPAD_LEFT, true)
	await until(func() -> bool: return p.ix < x0 - 16)
	button(JOY_BUTTON_DPAD_LEFT, false)
	expect("d-pad moves the player", p.ix < x0 - 16)
	await rest(p, spot)
	button(JOY_BUTTON_A, true)
	await until(func() -> bool: return p.iy < spot.y - 12)
	button(JOY_BUTTON_A, false)
	expect("A jumps", p.iy < spot.y - 12)
	await rest(p, spot)

	var swung := false
	button(JOY_BUTTON_X, true)
	for i in 30:
		await wait(1)
		swung = swung or p.atk_t > 0
	button(JOY_BUTTON_X, false)
	await wait(30)
	expect("X swings the hook", swung)

	G.give("reel")
	var cast := false
	button(JOY_BUTTON_B, true)
	for i in 30:
		await wait(1)
		cast = cast or p.line_t > 0 or p.state == Player.REEL
	button(JOY_BUTTON_B, false)
	await wait(30)
	expect("B casts the reel", cast)

	G.give("fork")
	await tap_until(JOY_BUTTON_Y, func() -> bool: return main.game.fork_menu)
	expect("Y opens the tuning fork", main.game.fork_menu)
	await tap_until(JOY_BUTTON_Y, func() -> bool: return not main.game.fork_menu)
	expect("Y closes the tuning fork", not main.game.fork_menu)

	# read a sign the way a player would: stand by it and press a button
	var sign_ent: Ent = null
	for e in main.game.ents:
		if e.props.get("kind", "") == "sign":
			sign_ent = e
	p.place(sign_ent.x - 8, sign_ent.y)
	await wait(10)
	await tap_until(JOY_BUTTON_DPAD_UP, func() -> bool: return main.game.hud.dialog_active())
	expect("d-pad up reads a sign", main.game.hud.dialog_active())
	for i in 300:
		if not main.game.hud.dialog_active():
			break
		await tap(JOY_BUTTON_A)
	await wait(10)
	await tap_until(JOY_BUTTON_RIGHT_SHOULDER, func() -> bool: return main.game.hud.dialog_active(), 8)
	expect("RB interacts", main.game.hud.dialog_active())
	for i in 300:
		if not main.game.hud.dialog_active():
			break
		await tap(JOY_BUTTON_A)
	await wait(10)

	# running past something with the stick angled up must not set it off
	p.place(sign_ent.x - 8, sign_ent.y)
	await wait(10)
	axis(JOY_AXIS_LEFT_X, 0.8)
	await wait(4)
	axis(JOY_AXIS_LEFT_Y, -0.8)
	await wait(12)
	var opened: bool = main.game.hud.dialog_active()
	axis(JOY_AXIS_LEFT_X, 0.0)
	axis(JOY_AXIS_LEFT_Y, 0.0)
	await wait(6)
	expect("stick up while running doesn't interact", not opened)
	for i in 300:
		if not main.game.hud.dialog_active():
			break
		await tap(JOY_BUTTON_A)

	await tap(JOY_BUTTON_START)
	await wait(10)
	expect("Start pauses", get_tree().paused and menu.mode == "pause")
	await tap(JOY_BUTTON_DPAD_DOWN)
	expect("d-pad works in the pause menu", menu.sel == 1)
	await tap(JOY_BUTTON_B)
	await wait(10)
	expect("B resumes", not get_tree().paused and not menu.active())
	await tap(JOY_BUTTON_BACK)
	await wait(10)
	expect("Back opens the map", get_tree().paused and menu.mode == "pause")
	await tap(JOY_BUTTON_BACK)
	await wait(10)
	expect("Back closes the map", not get_tree().paused and not menu.active())

	await tap(JOY_BUTTON_START)
	await wait(10)
	menu.sel = 2
	await tap(JOY_BUTTON_A)
	await wait(10)
	expect("A opens options", menu.mode == "options")
	var v: float = G.settings.music
	await tap(JOY_BUTTON_DPAD_LEFT)
	expect("d-pad changes the volume", not is_equal_approx(v, float(G.settings.music)))
	G.settings.music = v
	Sfx.apply_volume()
	var was: String = G.settings.lang
	var italian := G.italian()
	menu.sel = menu.items.find("Language")
	await tap(JOY_BUTTON_DPAD_RIGHT)
	expect("d-pad changes the language", G.italian() != italian)
	await tap(JOY_BUTTON_DPAD_RIGHT)
	expect("and back again", G.italian() == italian)
	G.settings.lang = was
	G.save_settings()
	menu.sel = menu.items.find("Done")
	await tap(JOY_BUTTON_A)
	await wait(10)
	menu.sel = menu.items.find("Quit to title")
	await tap(JOY_BUTTON_A)
	await wait(30)
	expect("A quits to the title", menu.mode == "title")

	# the end screen, reached the way the game reaches it, and left with a button
	await main._on_menu("new")
	await wait(10)
	main.game.hud.dlg_pages.clear()
	G.set_flag("drinker_dead")
	main.game.start_finale()
	main.game.ending_t = 515
	await until(func() -> bool: return main.game.hud.dialog_active(), 600)
	for i in 300:
		if not main.game.hud.dialog_active():
			break
		await tap(JOY_BUTTON_A)
	await until(func() -> bool: return menu.mode == "ending", 1800)
	expect("the end screen appears", menu.mode == "ending")
	await until(func() -> bool: return menu.t > 95, 600)
	expect("the end screen offers a way out", menu.t > 95)
	await tap(JOY_BUTTON_A)
	await until(func() -> bool: return menu.mode == "title", 300)
	expect("A leaves the end screen", menu.mode == "title")


## Wait for a condition, for as long as a slow software renderer might need.
func until(done: Callable, frames := 900) -> void:
	for i in frames:
		if done.call():
			return
		await wait(1)


func rest(p: Player, spot: Vector2i) -> void:
	await wait(4)
	p.place(spot.x, spot.y)
	await wait(12)


func tap_until(b: int, done: Callable, tries := 40) -> void:
	for i in tries:
		if done.call():
			return
		await tap(b)
