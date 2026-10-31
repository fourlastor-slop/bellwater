class_name Pad
extends RefCounted
## One tick of player input. Polled from the keyboard/gamepad, or set directly by the test bots.

var x := 0
var y := 0
var jump := false
var jump_p := false
var attack_p := false
var cast_p := false
var up_p := false
var down_p := false
var interact_p := false
var fork_p := false


func poll() -> void:
	x = int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left"))
	y = int(Input.is_action_pressed("down")) - int(Input.is_action_pressed("up"))
	jump = Input.is_action_pressed("jump")
	jump_p = Input.is_action_just_pressed("jump")
	attack_p = Input.is_action_just_pressed("attack")
	cast_p = Input.is_action_just_pressed("cast")
	up_p = Input.is_action_just_pressed("up")
	down_p = Input.is_action_just_pressed("down")
	interact_p = (up_p and x == 0) or Input.is_action_just_pressed("interact")
	fork_p = Input.is_action_just_pressed("fork")


func clear() -> void:
	x = 0
	y = 0
	jump = false
	jump_p = false
	attack_p = false
	cast_p = false
	up_p = false
	down_p = false
	interact_p = false
	fork_p = false
