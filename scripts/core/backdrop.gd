class_name Backdrop
extends CanvasLayer
## Sky and distant layers behind the outdoor rooms.

var sky: Sprite2D
var far: Sprite2D
var near: Sprite2D


func setup(mat: Material) -> void:
	layer = -5
	sky = _sprite("res://assets/gfx/bg_sky.png", mat, false)
	far = _sprite("res://assets/gfx/bg_far.png", mat, true)
	near = _sprite("res://assets/gfx/bg_near.png", mat, true)


func _sprite(path: String, mat: Material, repeat: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.centered = false
	s.material = mat
	if repeat:
		s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		s.region_enabled = true
		s.region_rect = Rect2(0, 0, G.VIEW_W, s.texture.get_height())
	add_child(s)
	return s


func sync(cam: Vector2) -> void:
	far.region_rect.position.x = cam.x * 0.06
	far.position.y = roundf(-36.0 + (1000.0 - cam.y) * 0.1)
	near.region_rect.position.x = cam.x * 0.16
	near.position.y = roundf(-40.0 + (400.0 - cam.y) * 0.2)
	# the town stands high and to the west; out on the flats the horizon is empty
	near.modulate.a = clampf((2500.0 - cam.x) / 200.0, 0.0, 1.0) * clampf((820.0 - cam.y) / 100.0, 0.0, 1.0)
	near.visible = near.modulate.a > 0.0
