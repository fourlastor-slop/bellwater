class_name Menu
extends CanvasLayer
## Title, pause (with the world map), options, controls and the end screen.

signal action(name: String)

const BONE := Color("efe6d0")
const GOLD := Color("f7d154")
const SHADOW := Color(0, 0, 0, 0.8)

var game: Game
var canvas: Node2D
var mode := ""
var items: Array[String] = []
var sel := 0
var back_to := ""
var map_tex: ImageTexture
var t := 0
var icons: Texture2D
var stats := {}


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	canvas = Node2D.new()
	add_child(canvas)
	canvas.draw.connect(_paint)
	icons = load("res://assets/gfx/pickups.png")


func open(m: String) -> void:
	mode = m
	sel = 0
	t = 0
	match m:
		"title":
			items = ["New Game", "Controls", "Options", "Quit"]
			if G.has_save():
				items.insert(0, "Continue")
		"confirm":
			items = ["Cancel", "Erase and start"]
		"pause":
			items = ["Resume", "Back to last lamp", "Options", "Quit to title"]
			_build_map()
		"options":
			items = ["Music", "Sound", "Language", "Fullscreen", "Done"]
		"controls":
			items = ["Done"]
		"ending":
			items = []
		"":
			items = []
	canvas.queue_redraw()


func close() -> void:
	open("")


func active() -> bool:
	return mode != ""


func _process(_d: float) -> void:
	if mode == "":
		return
	t += 1
	canvas.queue_redraw()
	if t < 3:
		return  # the key that opened this menu must not also act on it
	if mode == "ending":
		if t > 90 and (Input.is_action_just_pressed("accept") or Input.is_action_just_pressed("pause")):
			action.emit("title")
		return
	if items.is_empty():
		return
	if Input.is_action_just_pressed("up"):
		sel = (sel - 1 + items.size()) % items.size()
		Sfx.play("text")
	if Input.is_action_just_pressed("down"):
		sel = (sel + 1) % items.size()
		Sfx.play("text")
	if mode == "options":
		_options_input()
		return
	if Input.is_action_just_pressed("accept"):
		Sfx.play("clink")
		_choose(items[sel])
	elif Input.is_action_just_pressed("back") or (mode == "pause" and (Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("map"))):
		if mode == "pause":
			action.emit("resume")
		elif mode == "controls" or mode == "confirm":
			open(back_to if back_to != "" else "title")


func _choose(item: String) -> void:
	match item:
		"Continue":
			action.emit("continue")
		"New Game":
			if G.has_save():
				back_to = "title"
				open("confirm")
			else:
				action.emit("new")
		"Erase and start":
			G.wipe_save()
			action.emit("new")
		"Cancel":
			open("title")
		"Controls":
			back_to = mode
			open("controls")
		"Options":
			back_to = mode
			open("options")
		"Quit":
			get_tree().quit()
		"Resume":
			action.emit("resume")
		"Back to last lamp":
			action.emit("respawn")
		"Quit to title":
			action.emit("title")
		"Done":
			open(back_to if back_to != "" else "title")


func _options_input() -> void:
	var d := int(Input.is_action_just_pressed("right")) - int(Input.is_action_just_pressed("left"))
	var item := items[sel]
	if item == "Music" and d != 0:
		G.settings.music = clampf(snappedf(float(G.settings.music) + d * 0.1, 0.1), 0.0, 1.0)
		Sfx.apply_volume()
		G.save_settings()
	elif item == "Sound" and d != 0:
		G.settings.sfx = clampf(snappedf(float(G.settings.sfx) + d * 0.1, 0.1), 0.0, 1.0)
		Sfx.apply_volume()
		Sfx.play("clink")
		G.save_settings()
	elif item == "Language" and (d != 0 or Input.is_action_just_pressed("accept")):
		G.settings.lang = "en" if G.italian() else "it"
		G.apply_language()
		G.save_settings()
	elif item == "Fullscreen" and (d != 0 or Input.is_action_just_pressed("accept")):
		G.settings.fullscreen = not G.settings.fullscreen
		G.apply_settings()
		G.save_settings()
	elif item == "Done" and Input.is_action_just_pressed("accept"):
		open(back_to if back_to != "" else "title")


func _paint() -> void:
	var ci := canvas
	match mode:
		"title":
			_paint_title(ci)
		"confirm":
			_dim(ci, 0.6)
			PixelFont.centered(ci, 70, tr("This will erase your saved game."), BONE, SHADOW)
			_list(ci, 100, 140)
		"pause":
			_paint_pause(ci)
		"options":
			_dim(ci, 0.75)
			PixelFont.centered(ci, 40, tr("OPTIONS"), GOLD, SHADOW)
			_paint_options(ci)
		"controls":
			_dim(ci, 0.85)
			_paint_controls(ci)
		"ending":
			_paint_ending(ci)


func _dim(ci: CanvasItem, a: float) -> void:
	ci.draw_rect(Rect2(0, 0, G.VIEW_W, G.VIEW_H), Color(0.04, 0.05, 0.09, a))


func _list(ci: CanvasItem, y: float, x: float) -> void:
	for i in items.size():
		var on := i == sel
		if on:
			ci.draw_rect(Rect2(x - 10, y + i * 13 + 2, 4, 5), GOLD)
		PixelFont.draw(ci, Vector2(x, y + i * 13), tr(items[i]), GOLD if on else BONE, SHADOW)


func _paint_title(ci: CanvasItem) -> void:
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2(4, 4))
	var x := 40.0 - PixelFont.width("BELLWATER") / 2.0
	PixelFont.draw(ci, Vector2(x, 3.5), "BELLWATER", Color("2a1f1c"))
	PixelFont.draw(ci, Vector2(x, 3), "BELLWATER", BONE)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	PixelFont.centered(ci, 45, tr("call the sea home"), Color("2a1f1c"), Color(0.95, 0.9, 0.78, 0.45))
	var h := items.size() * 13 + 6
	ci.draw_rect(Rect2(112, 176 - h - 2, 96, h), Color(0.05, 0.05, 0.09, 0.55))
	_list(ci, 176 - h + 1, 128)


func _paint_options(ci: CanvasItem) -> void:
	var y := 70
	for i in items.size():
		var on := i == sel
		var c := GOLD if on else BONE
		if on:
			ci.draw_rect(Rect2(80, y + i * 14 + 2, 4, 5), GOLD)
		PixelFont.draw(ci, Vector2(92, y + i * 14), tr(items[i]), c, SHADOW)
		var v := ""
		match items[i]:
			"Music":
				v = _bar(float(G.settings.music))
			"Sound":
				v = _bar(float(G.settings.sfx))
			"Fullscreen":
				v = tr("on") if G.settings.fullscreen else tr("off")
			"Language":
				v = "Italiano" if G.italian() else "English"
		PixelFont.draw(ci, Vector2(170, y + i * 14), v, c, SHADOW)


func _bar(v: float) -> String:
	var n := int(round(v * 10.0))
	return "=".repeat(n) + "-".repeat(10 - n)


func _paint_controls(ci: CanvasItem) -> void:
	PixelFont.centered(ci, 14, tr("CONTROLS"), GOLD, SHADOW)
	var dim := Color("c8bcb8")
	PixelFont.draw(ci, Vector2(126, 30), tr("Keyboard"), GOLD, SHADOW)
	PixelFont.draw(ci, Vector2(226, 30), tr("Gamepad"), GOLD, SHADOW)
	var rows := [
		[tr("Move / aim"), tr("Arrows, WASD"), "Stick, D-pad"],
		[tr("Jump"), tr("Space, Z, K"), "A"],
		[tr("Boathook"), "X, J", "X"],
		[tr("Cast the reel"), "C, L", "B"],
		[tr("Ring, read, rest"), tr("Up, E"), tr("Up, LB, RB")],
		[tr("Dive"), tr("Hold Down"), tr("Hold Down")],
		[tr("Tuning fork"), "F, V", "Y"],
		[tr("Map and pause"), "Tab, M, Esc", "Back, Start"],
	]
	for i in rows.size():
		var y := 44 + i * 13
		PixelFont.draw(ci, Vector2(30, y), rows[i][0], BONE, SHADOW)
		PixelFont.draw(ci, Vector2(126, y), rows[i][1], dim, SHADOW)
		PixelFont.draw(ci, Vector2(226, y), rows[i][2], dim, SHADOW)
	PixelFont.centered(ci, 162, tr("Enter or A"), GOLD, SHADOW)


func _build_map() -> void:
	var m := game.map
	var w := m.w / 2
	var h := m.h / 2
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var water := int(game.water_y) >> 3
	var wet := int(game.wet_y) >> 3
	for key: String in G.s.seen:
		var p := key.split(",")
		var cx := int(p[0]) * G.CELL_W
		var cy := int(p[1]) * G.CELL_H
		for ty in range(cy, cy + G.CELL_H):
			for tx in range(cx, cx + G.CELL_W):
				var t := m.get_tile(tx, ty)
				var solid := m.is_block(t)
				var col: Color
				if solid:
					col = Color("3a4a5e") if ty > wet else Color("6a5a4a")
				elif t == WorldMap.ONEWAY or t == WorldMap.LADDER:
					col = Color("a3704a")
				elif ty >= water:
					col = Color("2f7f8f")
				elif ty > wet:
					col = Color("8cc2c0")
				else:
					col = Color("e3d2b0")
				img.set_pixel(tx / 2, ty / 2, col)
	map_tex = ImageTexture.create_from_image(img)


func _paint_pause(ci: CanvasItem) -> void:
	_dim(ci, 0.88)
	var ox := 30
	var oy := 8
	if map_tex:
		ci.draw_texture(map_tex, Vector2(ox, oy))
	var w := game.map.w / 2
	var h := game.map.h / 2
	ci.draw_rect(Rect2(ox - 1, oy - 1, w + 2, h + 2), Color("525a70"), false)
	# what the player has, on the map
	for r in game.map.rooms:
		var seen: bool = G.s.seen.has("%d,%d" % [r.cx, r.cy])
		for cy in r.ch:
			for cx in r.cw:
				seen = seen or G.s.seen.has("%d,%d" % [r.cx + cx, r.cy + cy])
		if not seen:
			continue
		for e in r.ents:
			if e.kind == "bell" and (e.get("requires", "") == "" or G.flag(e.get("requires", ""))):
				ci.draw_rect(Rect2(ox + int(e.x) / 16 - 1, oy + int(e.y) / 16 - 1, 3, 3), GOLD)
			elif e.kind == "lamp" and G.flag("lamp_%d_%d" % [e.x, e.y]):
				ci.draw_rect(Rect2(ox + int(e.x) / 16, oy + int(e.y) / 16, 2, 2), Color("f29a4a"))
	var p := game.player
	if t / 12 % 2 == 0:
		ci.draw_rect(Rect2(ox + p.ix / 16 - 1, oy + p.iy / 16 - 2, 3, 3), Color("e8514a"))
	var ly := oy + int(game.water_y) / 16
	if ly < oy + h:
		PixelFont.draw(ci, Vector2(ox + w + 3, ly - 4), "<", Color("5fcdbb"))
	PixelFont.draw(ci, Vector2(20, oy + h + 7), tr("Tide: ") + tr(G.TIDE_NAMES[int(G.s.level)]), Color("5fcdbb"), SHADOW)
	_paint_items(ci, oy + h + 19)
	_list(ci, oy + h + 7, 196)


func _paint_items(ci: CanvasItem, y: int) -> void:
	var x := 20
	for i in PICKUP_ORDER.size():
		var it: String = PICKUP_ORDER[i]
		if G.has(it):
			ci.draw_texture_rect_region(icons, Rect2(x, y, 12, 12), Rect2(i * 12, 0, 12, 12))
			x += 14
	var line := tr("Pearls: %d    Air: %d") % [int(G.s.max_hp) - 3, int(G.s.air)]
	PixelFont.draw(ci, Vector2(20, y + 16), line, Color("c8bcb8"), SHADOW)
	var secs := int(float(G.s.time))
	PixelFont.draw(ci, Vector2(20, y + 28), tr("Time: %d:%02d") % [secs / 60, secs % 60], Color("c8bcb8"), SHADOW)


const PICKUP_ORDER: Array[String] = ["reel", "helm", "bellows", "fork", "pearl", "air", "line", "barb"]


func _paint_ending(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, G.VIEW_W, G.VIEW_H), Color("0d0f18"))
	PixelFont.centered(ci, 34, "BELLWATER", GOLD)
	PixelFont.centered(ci, 54, tr("The sea came home."), BONE)
	var secs := int(stats.get("time", 0.0))
	PixelFont.centered(ci, 84, tr("Time  %d:%02d:%02d") % [secs / 3600, secs / 60 % 60, secs % 60], Color("c8bcb8"))
	PixelFont.centered(ci, 96, tr("Wrecked  %d times") % int(stats.get("deaths", 0)), Color("c8bcb8"))
	PixelFont.centered(ci, 108, tr("Found  %d of %d") % [int(stats.get("found", 0)), int(stats.get("total", 0))], Color("c8bcb8"))
	PixelFont.centered(ci, 136, tr("Everything you saw and heard was made for this game,"), Color("8a93a6"))
	PixelFont.centered(ci, 146, tr("by code, in Godot 4.7."), Color("8a93a6"))
	if t > 90:
		PixelFont.centered(ci, 164, tr("Enter or A"), GOLD)
