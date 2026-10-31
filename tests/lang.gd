extends Node
## Every string the player can read has an Italian version that the font can draw and the screen
## can hold. Strings are gathered from the rooms and the source, so a new one can't be forgotten.
## run: godot --headless --path . res://tests/lang.tscn

const TR := "tr\\(\"((?:[^\"\\\\]|\\\\.)*)\"\\)"
## Lines a string has to fit on, in pixels. Text in the dialogue box wraps by itself.
const MENU_MAX := 116
const LINE_MAX := 312
const CONTROLS := {"Move / aim": 92, "Jump": 92, "Boathook": 92, "Cast the reel": 92, "Ring, read, rest": 92,
	"Dive": 92, "Tuning fork": 92, "Map and pause": 92, "Arrows, WASD": 96, "Space, Z, K": 96, "Up, E": 96,
	"Up, LB, RB": 88, "Hold Down": 88, "Keyboard": 96, "Gamepad": 88}
## Italian uses the same word.
const SAME := ["Gamepad"]

var fails := 0


func _ready() -> void:
	var ids := {}
	var lines := {}
	var menu := {}
	for path in scripts("res://scripts/"):
		gather(path, ids, lines, menu)
	var map := WorldMap.new()
	for r in map.rooms:
		if r.title != "":
			ids[r.title] = true
			lines[r.title] = true
		for e in r.ents:
			if e.has("text"):
				ids[e.text] = true
	var pickups: Dictionary = load("res://scripts/entities/pickup.gd").get_script_constant_map().INFO
	for item: String in pickups:
		ids[pickups[item][0]] = true
		ids[pickups[item][1]] = true
	for name in G.TIDE_NAMES:
		ids[name] = true
		lines[name] = true
	check(ids, lines, menu)
	remembers_language()
	print("LANG %d strings %s" % [ids.size(), "FAILED: %d" % fails if fails > 0 else "OK"])
	get_tree().quit(1 if fails > 0 else 0)


## A language picked in Options has to survive a restart, and beat the system's language.
func remembers_language() -> void:
	var before: Dictionary = G.settings.duplicate()
	for lang in ["it", "en"]:
		G.settings.lang = lang
		G.save_settings()
		G.settings.lang = ""
		TranslationServer.set_locale("en" if lang == "it" else "it")
		G.load_settings()
		if G.italian() != (lang == "it"):
			fail("language not remembered", lang)
	G.settings = before
	G.save_settings()


func scripts(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(scripts(dir + d + "/"))
	return out


func gather(path: String, ids: Dictionary, lines: Dictionary, menu: Dictionary) -> void:
	var rx := RegEx.create_from_string(TR)
	var quoted := RegEx.create_from_string("\"([^\"]+)\"")
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var single := line.contains("PixelFont.") or line.contains("show_note") or line.contains("show_banner") or line.contains("boss_name")
		for m in rx.search_all(line):
			var id := m.get_string(1).replace("\\n", "\n").replace("\\\"", "\"")
			ids[id] = true
			if single:
				lines[id] = true
		if path.ends_with("menu.gd") and (line.contains("items = [") or line.contains("items.insert(")):
			for m in quoted.search_all(line):
				ids[m.get_string(1)] = true
				menu[m.get_string(1)] = true


func fail(why: String, id: String) -> void:
	fails += 1
	print("  FAIL %s: %s" % [why, id.c_escape()])


func placeholders(s: String) -> Array[String]:
	var out: Array[String] = []
	for m in RegEx.create_from_string("%0?\\d*d").search_all(s):
		out.append(m.get_string())
	return out


func check(ids: Dictionary, lines: Dictionary, menu: Dictionary) -> void:
	TranslationServer.set_locale("it")
	for id: String in ids:
		var it: String = TranslationServer.translate(id)
		if it == id and id not in SAME:
			fail("no Italian", id)
			continue
		if placeholders(id) != placeholders(it):
			fail("placeholders differ", id)
		for i in it.length():
			var code := it.unicode_at(i)
			if code != 10 and PixelFont.glyph(code) < 0:
				fail("no glyph for '%s'" % it[i], id)
		if lines.has(id) and PixelFont.width(it) > LINE_MAX:
			fail("too wide (%d)" % PixelFont.width(it), id)
		if menu.has(id) and PixelFont.width(it) > MENU_MAX:
			fail("too wide for a menu (%d)" % PixelFont.width(it), id)
		if CONTROLS.has(id) and PixelFont.width(it) > CONTROLS[id]:
			fail("too wide for the controls screen (%d)" % PixelFont.width(it), id)
	TranslationServer.set_locale("en")
	for id: String in ids:
		if TranslationServer.translate(id) != id:
			fail("English changed", id)
	TranslationServer.set_locale("it")
