extends Node
## Top level: owns the running game and swaps between title, play and pause.

var game: Game
var pad := Pad.new()
var menu: Menu


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "licenses":
		_write_licenses(args[1])
		get_tree().quit()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	menu = Menu.new()
	add_child(menu)
	menu.action.connect(_on_menu)
	_to_title()


## tools/export.sh runs this so the engine's notices ship beside the game.
func _write_licenses(path: String) -> void:
	var out := "Bellwater is built with the Godot Engine.\n\n" + Engine.get_license_text() + "\n"
	for part: Dictionary in Engine.get_copyright_info():
		out += "\n%s\n" % part.name
		for p: Dictionary in part.parts:
			out += "  Files: %s\n" % ", ".join(p.files)
			out += "  Copyright: %s\n" % "; ".join(p.copyright)
			out += "  License: %s\n" % p.license
	var texts := Engine.get_license_info()
	for name: String in texts:
		out += "\n--- %s ---\n\n%s\n" % [name, texts[name]]
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(out)


func _make_game() -> void:
	if game:
		game.queue_free()
		await get_tree().process_frame
	game = Game.new()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	game.setup(pad)
	game.finished.connect(_on_finished)
	menu.game = game


func _to_title() -> void:
	get_tree().paused = false
	G.new_run()
	await _make_game()
	game.begin(false)
	game.attract = true
	game.hud.hidden = true
	Sfx.music("title")
	menu.open("title")


func _on_menu(what: String) -> void:
	match what:
		"new":
			menu.close()
			G.new_run()
			await _make_game()
			game.begin(false)
			game.fade = 1.0
			G.save_game()
			var hint := game.hud.show_note.bind(tr("Move with arrows, WASD or the stick. Jump with Space or A."))
			game.hud.say(tr("The sea left Bellwater when you were small.\n\nThis morning, far off and very faint, you heard a bell."), hint)
		"continue":
			menu.close()
			if G.load_game():
				await _make_game()
				game.begin(true)
				game.fade = 1.0
		"resume":
			menu.close()
			get_tree().paused = false
		"respawn":
			menu.close()
			get_tree().paused = false
			game.respawn_now()
		"title":
			menu.close()
			_to_title()


func _on_finished() -> void:
	menu.stats = {
		"time": G.s.time,
		"deaths": G.s.deaths,
		"found": game.count_found(),
		"total": game.count_items(),
	}
	G.wipe_save()
	get_tree().paused = false
	menu.t = 0
	menu.open("ending")


func _unhandled_input(event: InputEvent) -> void:
	if game == null or game.attract or menu.active() or game.ending > 0 or game.returning:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("map"):
		if game.respawn_t > 0 or game.hud.dialog_active():
			return
		get_tree().paused = true
		menu.t = 0
		menu.open("pause")
