extends Node
## Drives the real main scene through the menus, as a player would: title, new game, pause, map,
## options, quit to title, continue. Saves screenshots along the way.
## run under a display: godot --path . res://tests/flow.tscn -- out_dir

var main: Node
var out := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "/tmp"
	G.wipe_save()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await run()
	get_tree().quit()


func wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func send(action: String, down: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = down
	Input.parse_input_event(e)


func press(action: String) -> void:
	send(action, true)
	await wait(4)
	send(action, false)
	await wait(4)


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("shot ", name)


func expect(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])


func run() -> void:
	await wait(40)
	await shot("f_title")
	var menu: Menu = main.menu
	expect("title menu open", menu.mode == "title")
	expect("no Continue without a save", not menu.items.has("Continue"))
	await press("accept")
	await wait(30)
	expect("new game started", not menu.active() and not main.game.attract)
	await shot("f_intro")
	for i in 200:
		if not main.game.hud.dialog_active():
			break
		await press("jump")
	await wait(10)
	await shot("f_start")
	expect("dialog dismissed", not main.game.hud.dialog_active())
	# walk, to see the player answer real input
	var x0: int = main.game.player.ix
	send("left", true)
	await wait(120)
	send("left", false)
	await wait(10)
	expect("left key moved the player", main.game.player.ix < x0)
	await press("pause")
	await wait(20)
	expect("paused", get_tree().paused and menu.mode == "pause")
	await shot("f_pause")
	await press("down")
	await press("down")
	await press("accept")
	await wait(5)
	expect("options open", menu.mode == "options")
	await shot("f_options")
	await press("right")
	await press("up")
	await press("accept")
	await wait(5)
	await press("back")
	await wait(5)
	print("  mode after back: ", menu.mode)
	if menu.mode == "options":
		menu.open("pause")
	await press("up")
	await press("up")
	await press("accept")
	await wait(10)
	expect("resumed", not get_tree().paused and not menu.active())
	G.set_flag("flow_test")
	G.save_game()
	await press("pause")
	await wait(5)
	menu.sel = 3
	await press("accept")
	await wait(30)
	expect("back at title", menu.mode == "title")
	expect("Continue offered", menu.items.has("Continue"))
	await shot("f_title2")
	await press("accept")
	await wait(30)
	expect("continued a save", G.flag("flow_test") and not menu.active())
	await shot("f_continue")
	G.wipe_save()
