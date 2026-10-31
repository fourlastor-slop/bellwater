class_name TouchPad
extends CanvasLayer
## A gamepad on the screen, for phones. It speaks in real joypad events, so the game and every
## menu take it exactly as they take a controller, with no code of their own for touch.
## Laid out in view pixels (320x180). The black bars beside the picture on a wide phone still
## count: a thumb that drifts off the picture stays on its control.

## Not a real pad: how this class tells its own events from a controller's.
const DEVICE := 7
const STICK_HOME := Vector2(42, 136)
const STICK_RADIUS := 20.0
## How far the thumb gets from the stick's middle before the middle follows it. Much less than the
## radius it is drawn at: this is how far a thumb has to travel to reverse.
const STICK_TRAVEL := 9.0
## Left of this, a touch takes the stick, wherever it lands.
const STICK_ZONE := 150.0
const DEAD_ZONE := 4.0
## How far from a button's middle a touch still counts as that button.
const REACH := 19.0
const BUTTONS := {
	"a": {"joy": JOY_BUTTON_A, "at": Vector2(280, 158), "r": 13.0, "label": "A"},
	"b": {"joy": JOY_BUTTON_B, "at": Vector2(302, 136), "r": 13.0, "label": "B"},
	"x": {"joy": JOY_BUTTON_X, "at": Vector2(258, 136), "r": 13.0, "label": "X"},
	"y": {"joy": JOY_BUTTON_Y, "at": Vector2(280, 114), "r": 13.0, "label": "Y"},
	"use": {"joy": JOY_BUTTON_RIGHT_SHOULDER, "at": Vector2(236, 160), "r": 11.0, "label": "!"},
	"pause": {"joy": JOY_BUTTON_START, "at": Vector2(304, 16), "r": 10.0, "label": ""},
}
const INK := Color(1, 1, 1, 0.6)
const FILL := Color(1, 1, 1, 0.12)
const FILL_DOWN := Color(1, 1, 1, 0.38)
const SHADOW := Color(0, 0, 0, 0.5)

var menu: Menu
var canvas: Node2D
var stick_touch := -1
var stick_origin := STICK_HOME
var stick_now := STICK_HOME
var touches := {}
var down := {}
## A real controller took over, so get out of the way until the screen is touched again.
var hidden_by_pad := false


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	canvas = Node2D.new()
	add_child(canvas)
	canvas.draw.connect(_paint)


func _process(_d: float) -> void:
	canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		hidden_by_pad = false
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
	elif event is InputEventScreenDrag:
		_touch_move(event.index, event.position)
	elif event is InputEventJoypadButton and event.device != DEVICE:
		_pad_took_over()
	elif event is InputEventJoypadMotion and event.device != DEVICE and absf(event.axis_value) > 0.5:
		_pad_took_over()


func _pad_took_over() -> void:
	if not hidden_by_pad:
		hidden_by_pad = true
		release_all()


## Let go of everything, as when the app loses focus and the lift of a finger will never arrive.
func release_all() -> void:
	for joy: int in down.keys():
		_press(joy, false)
	touches.clear()
	stick_touch = -1


## The controls that mean something right now. The others are neither drawn nor touchable.
func available(name: String) -> bool:
	var game := menu.game
	var in_menu := menu.active()
	var playing := game != null and not in_menu and not game.attract and game.ending == 0
	match name:
		"a":
			return true
		"b":
			return in_menu or (playing and G.has("reel"))
		"y":
			return playing and G.has("fork")
		"use":
			return playing and game.nearby_interact() != null
	return playing


func _touch_down(index: int, pos: Vector2) -> void:
	if pos.x < STICK_ZONE:
		if stick_touch < 0:
			stick_touch = index
			stick_origin = pos
			stick_now = pos
		return
	var name := _button_at(pos)
	if name != "":
		touches[index] = name
		_press(BUTTONS[name].joy, true)


func _touch_up(index: int) -> void:
	if index == stick_touch:
		stick_touch = -1
		_update_stick()
	elif touches.has(index):
		_press(BUTTONS[touches[index]].joy, false)
		touches.erase(index)


func _touch_move(index: int, pos: Vector2) -> void:
	if index == stick_touch:
		stick_now = pos
		# the base follows the thumb, so reversing direction never means crossing a long way back
		var pull := stick_now - stick_origin
		if pull.length() > STICK_TRAVEL:
			stick_origin = stick_now - pull.normalized() * STICK_TRAVEL
		_update_stick()
	elif touches.has(index):
		# sliding onto another button changes to it; sliding off into nothing keeps holding
		var name := _button_at(pos)
		if name != "" and name != touches[index]:
			_press(BUTTONS[touches[index]].joy, false)
			touches[index] = name
			_press(BUTTONS[name].joy, true)


func _button_at(pos: Vector2) -> String:
	var at := Vector2(minf(pos.x, G.VIEW_W), pos.y)
	var best := ""
	var best_d := REACH
	for name: String in BUTTONS:
		var d := at.distance_to(BUTTONS[name].at)
		if d < best_d and available(name):
			best_d = d
			best = name
	return best


func _update_stick() -> void:
	var d := stick_now - stick_origin
	var on := stick_touch >= 0 and d.length() > DEAD_ZONE
	var a := d.normalized()
	_press(JOY_BUTTON_DPAD_RIGHT, on and a.x > 0.38)
	_press(JOY_BUTTON_DPAD_LEFT, on and a.x < -0.38)
	# steeper than left and right, so running with the thumb a little high doesn't aim or dive
	_press(JOY_BUTTON_DPAD_DOWN, on and a.y > 0.6)
	_press(JOY_BUTTON_DPAD_UP, on and a.y < -0.6)


func _press(joy: int, on: bool) -> void:
	if down.has(joy) == on:
		return
	if on:
		down[joy] = true
	else:
		down.erase(joy)
	var e := InputEventJoypadButton.new()
	e.device = DEVICE
	e.button_index = joy as JoyButton
	e.pressed = on
	e.pressure = 1.0 if on else 0.0
	Input.parse_input_event(e)


func _paint() -> void:
	if hidden_by_pad:
		return
	var ci := canvas
	var held := stick_touch >= 0
	var base := stick_origin if held else STICK_HOME
	ci.draw_arc(base, STICK_RADIUS, 0.0, TAU, 32, INK, 1.0)
	var knob := base + (stick_now - base) * STICK_RADIUS / STICK_TRAVEL if held else base
	ci.draw_circle(knob, 9.0, FILL_DOWN if held else FILL)
	for name: String in BUTTONS:
		if not available(name):
			continue
		var b: Dictionary = BUTTONS[name]
		ci.draw_circle(b.at, b.r, FILL_DOWN if down.has(b.joy) else FILL)
		ci.draw_arc(b.at, b.r, 0.0, TAU, 28, INK, 1.0)
		if name == "pause":
			ci.draw_rect(Rect2(b.at + Vector2(-3, -4), Vector2(2, 8)), INK)
			ci.draw_rect(Rect2(b.at + Vector2(1, -4), Vector2(2, 8)), INK)
		else:
			PixelFont.centered(ci, b.at.y - 3.0, b.label, INK, SHADOW, b.at.x)
