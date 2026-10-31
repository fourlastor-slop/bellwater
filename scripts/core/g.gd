extends Node
## Global constants and the persistent state of a run.

const TILE := 8
const CELL_W := 40
const CELL_H := 23
const VIEW_W := 320
const VIEW_H := 180

## Sea surface height per tide level, in tile rows of the global grid.
const TIDE_ROWS: Array[int] = [170, 113, 90, 67, 44, 21]
const TIDE_NAMES: Array[String] = ["Dry", "Low Water", "Half Tide", "High Water", "Spring Tide", "The Return"]

## Matches events from any controller. A pad isn't always device 0, and InputMap doesn't expose this.
const ALL_DEVICES := -1

const SAVE_PATH := "user://bellwater_save.json"
const SETTINGS_PATH := "user://bellwater_settings.json"

const BASE_BREATH := 10.0
const BREATH_PER_SAC := 4.0
const BASE_REEL := 88.0
const LONG_REEL := 128.0

## True while tests run: no save writes, no FX, no audio.
var headless_sim := false
## Lets a test have the on-screen gamepad away from a phone.
var force_touch := false

## Everything that goes in the save file.
var s := {}
## lang stays empty until the player picks one, and the game follows the system's language.
var settings := {"music": 0.8, "sfx": 0.9, "fullscreen": false, "lang": ""}


func _ready() -> void:
	_register_inputs()
	new_run()
	load_settings()


func tide_px(level: int) -> float:
	return float(TIDE_ROWS[level] * TILE)


func new_run() -> void:
	s = {
		"abilities": {},
		"max_hp": 3,
		"air": 0,
		"level": 0,
		"wet_y": tide_px(0),
		"taken": {},
		"flags": {},
		"rung": {"0": true},
		"seen": {},
		"cp": [],
		"time": 0.0,
		"deaths": 0,
		"broken": {},
		"opened": {},
	}


func has(ability: String) -> bool:
	return s.abilities.has(ability)


func give(ability: String) -> void:
	s.abilities[ability] = true


func flag(name: String) -> bool:
	return s.flags.has(name)


func set_flag(name: String) -> void:
	s.flags[name] = true


func taken(id: String) -> bool:
	return s.taken.has(id)


func take(id: String) -> void:
	s.taken[id] = true


func max_breath() -> float:
	return BASE_BREATH + BREATH_PER_SAC * s.air


func reel_range() -> float:
	return LONG_REEL if has("line") else BASE_REEL


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	if headless_sim:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(s))


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return false
	new_run()
	for k in d:
		s[k] = d[k]
	s.level = int(s.level)
	s.max_hp = int(s.max_hp)
	s.air = int(s.air)
	s.deaths = int(s.deaths)
	return true


func wipe_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			for k in d:
				settings[k] = d[k]
	apply_settings()


func apply_language() -> void:
	if str(settings.lang) != "":
		TranslationServer.set_locale(str(settings.lang))


func touch_screen() -> bool:
	return force_touch or OS.has_feature("mobile")


func italian() -> bool:
	return TranslationServer.get_locale().begins_with("it")


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))


func apply_settings() -> void:
	apply_language()
	# a phone starts fullscreen, and asking for a window would bring its system bars back
	if DisplayServer.get_name() == "headless" or touch_screen():
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func _register_inputs() -> void:
	var keys := {
		"left": [KEY_LEFT, KEY_A],
		"right": [KEY_RIGHT, KEY_D],
		"up": [KEY_UP, KEY_W],
		"down": [KEY_DOWN, KEY_S],
		"jump": [KEY_SPACE, KEY_Z, KEY_K],
		"attack": [KEY_X, KEY_J],
		"cast": [KEY_C, KEY_L],
		"interact": [KEY_E],
		"fork": [KEY_F, KEY_V],
		"pause": [KEY_ESCAPE, KEY_P],
		"map": [KEY_TAB, KEY_M],
		"accept": [KEY_ENTER, KEY_SPACE, KEY_Z],
		"back": [KEY_ESCAPE, KEY_X],
	}
	var pads := {
		"left": [JOY_BUTTON_DPAD_LEFT],
		"right": [JOY_BUTTON_DPAD_RIGHT],
		"up": [JOY_BUTTON_DPAD_UP],
		"down": [JOY_BUTTON_DPAD_DOWN],
		"jump": [JOY_BUTTON_A],
		"attack": [JOY_BUTTON_X],
		"cast": [JOY_BUTTON_B],
		"interact": [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_LEFT_SHOULDER],
		"fork": [JOY_BUTTON_Y],
		"pause": [JOY_BUTTON_START],
		"map": [JOY_BUTTON_BACK],
		"accept": [JOY_BUTTON_A],
		"back": [JOY_BUTTON_B],
	}
	var axes := {
		"left": [JOY_AXIS_LEFT_X, -1.0],
		"right": [JOY_AXIS_LEFT_X, 1.0],
		"up": [JOY_AXIS_LEFT_Y, -1.0],
		"down": [JOY_AXIS_LEFT_Y, 1.0],
	}
	for action: String in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.45)
		for k: int in keys[action]:
			var e := InputEventKey.new()
			e.device = ALL_DEVICES
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
		for b: int in pads.get(action, []):
			var e := InputEventJoypadButton.new()
			e.device = ALL_DEVICES
			e.button_index = b
			InputMap.action_add_event(action, e)
		if axes.has(action):
			var e := InputEventJoypadMotion.new()
			e.device = ALL_DEVICES
			e.axis = axes[action][0]
			e.axis_value = axes[action][1]
			InputMap.action_add_event(action, e)
