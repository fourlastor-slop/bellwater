class_name Ocean
extends CanvasLayer
## The sea, as one full-screen pass: reads the rendered world and tints everything below the surface.
## Surface ripples are a 1D spring simulation fed to the shader as a small texture.

const COLS := 512
const COL_W := 2.0

var rect: ColorRect
var mat: ShaderMaterial
var heights := PackedFloat32Array()
var speeds := PackedFloat32Array()
var bytes := PackedByteArray()
var image: Image
var tex: ImageTexture
var x0 := 0.0
var active := false
var dark := 0.0
var dark_target := 0.0


func _ready() -> void:
	layer = 5
	rect = ColorRect.new()
	rect.size = Vector2(G.VIEW_W, G.VIEW_H)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/ocean.gdshader")
	rect.material = mat
	add_child(rect)
	heights.resize(COLS)
	speeds.resize(COLS)
	bytes.resize(COLS)
	bytes.fill(128)
	image = Image.create_from_data(COLS, 1, false, Image.FORMAT_L8, bytes)
	tex = ImageTexture.create_from_image(image)
	mat.set_shader_parameter("wave_tex", tex)
	mat.set_shader_parameter("wave_w", COLS * COL_W)


func set_room(r: WorldMap.Room) -> void:
	x0 = r.rect.position.x
	heights.fill(0.0)
	speeds.fill(0.0)
	mat.set_shader_parameter("wave_x0", x0)


func splash(wx: float, amp: float) -> void:
	var i := int((wx - x0) / COL_W)
	for k in range(-4, 5):
		var j := i + k
		if j >= 0 and j < COLS:
			speeds[j] += amp * 0.8 * (1.0 - absf(k) / 5.0)


func tick() -> void:
	if not active:
		return
	var n := COLS
	for i in range(1, n - 1):
		var a := (heights[i - 1] + heights[i + 1] - 2.0 * heights[i]) * 0.14 - heights[i] * 0.012
		speeds[i] = (speeds[i] + a) * 0.986
	for i in range(1, n - 1):
		var h := heights[i] + speeds[i]
		heights[i] = h
		bytes[i] = clampi(128 + int(h * 12.0), 0, 255)
	image.set_data(COLS, 1, false, Image.FORMAT_L8, bytes)
	tex.update(image)


func sync(cam: Vector2, water_y: float, ticks: int, p: Player) -> void:
	var sy := water_y - cam.y
	dark = move_toward(dark, dark_target, 0.02)
	active = sy < G.VIEW_H + 12.0
	rect.visible = active or dark > 0.0
	if not rect.visible:
		return
	mat.set_shader_parameter("surface_y", sy)
	mat.set_shader_parameter("tick", ticks / 60.0)
	mat.set_shader_parameter("cam", cam)
	mat.set_shader_parameter("dark", dark)
	mat.set_shader_parameter("light", Vector2(p.ix, p.iy - 8) - cam)
