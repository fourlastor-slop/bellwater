class_name Fx
extends Node2D
## Square pixel particles and expanding bell rings, all drawn in one pass.

const MAX_PARTS := 400

var px := PackedFloat32Array()
var py := PackedFloat32Array()
var vx := PackedFloat32Array()
var vy := PackedFloat32Array()
var grav := PackedFloat32Array()
var life := PackedInt32Array()
var size := PackedByteArray()
var cols := PackedColorArray()
var rings: Array[Dictionary] = []


func add(x: float, y: float, dx: float, dy: float, t: int, c: Color, s := 1, g := 0.0) -> void:
	if life.size() >= MAX_PARTS:
		return
	px.append(x)
	py.append(y)
	vx.append(dx)
	vy.append(dy)
	grav.append(g)
	life.append(t)
	size.append(s)
	cols.append(c)


func tick() -> void:
	var dt := 1.0 / 60.0
	var i := life.size() - 1
	while i >= 0:
		life[i] -= 1
		if life[i] <= 0:
			_remove(i)
		else:
			vy[i] += grav[i] * dt
			px[i] += vx[i] * dt
			py[i] += vy[i] * dt
		i -= 1
	var j := rings.size() - 1
	while j >= 0:
		var r := rings[j]
		r.r += r.speed
		r.t -= 1
		if r.t <= 0:
			rings.remove_at(j)
		j -= 1
	queue_redraw()


func _remove(i: int) -> void:
	var last := life.size() - 1
	px[i] = px[last]
	py[i] = py[last]
	vx[i] = vx[last]
	vy[i] = vy[last]
	grav[i] = grav[last]
	life[i] = life[last]
	size[i] = size[last]
	cols[i] = cols[last]
	px.resize(last)
	py.resize(last)
	vx.resize(last)
	vy.resize(last)
	grav.resize(last)
	life.resize(last)
	size.resize(last)
	cols.resize(last)


func _draw() -> void:
	for i in life.size():
		var s := float(size[i])
		draw_rect(Rect2(Vector2(px[i], py[i]).round(), Vector2(s, s)), cols[i])
	for r in rings:
		var k: float = float(r.t) / float(r.t0)
		var n := int(TAU * r.r / 2.5)
		var c: Color = r.c
		c.a = k
		for i in n:
			var a := TAU * i / n
			var p := Vector2(r.x, r.y) + Vector2(cos(a), sin(a)) * float(r.r)
			draw_rect(Rect2(p.round(), Vector2.ONE), c)


func dust(x: int, y: int, n: int) -> void:
	for i in n:
		add(x + randf_range(-4, 4), y - 1, randf_range(-22, 22), randf_range(-16, -2), randi_range(10, 20), Color(0.9, 0.84, 0.7, 0.8))


func puff(x: int, y: int) -> void:
	for i in 10:
		var a := TAU * i / 10.0
		add(x, y - 2, cos(a) * 42.0, sin(a) * 14.0 + 12.0, 16, Color(0.95, 0.95, 0.9, 0.9))


func bubble(x: int, y: int) -> void:
	add(x, y, randf_range(-4, 4), randf_range(-34, -22), randi_range(40, 90), Color(0.78, 0.96, 0.9, 0.85), 1, -4.0)


func burst(x: int, y: int, c: Color, n: int) -> void:
	for i in n:
		var a := randf() * TAU
		var v := randf_range(30, 90)
		add(x, y, cos(a) * v, sin(a) * v, randi_range(14, 28), c, randi_range(1, 2), 160.0)


func splash(x: int, y: int, strength: float) -> void:
	var n := clampi(int(strength / 18.0) + 3, 3, 14)
	for i in n:
		add(x + randf_range(-5, 5), y, randf_range(-40, 40), randf_range(-60, -20) - strength * 0.3, randi_range(14, 30), Color(0.84, 0.97, 0.92), 1, 320.0)


func ring_wave(x: int, y: int, c := Color(1.0, 0.92, 0.66)) -> void:
	for k in 3:
		rings.append({"x": x, "y": y, "r": 2.0 - k * 22.0, "speed": 2.6, "t": 70, "t0": 70, "c": c})
