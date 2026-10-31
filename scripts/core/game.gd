class_name Game
extends Node2D
## The running world. Everything advances from tick(), in a fixed order, so a test can step
## the whole game headless and faster than real time.

signal finished

const TIDE_SPEED := 52.0
const TRANSITION_TICKS := 22
const MISC_ROW := 80  # first row after the 8 themes of 10 rows each in tiles.png

const ENT_SCRIPTS := {
	"lamp": "res://scripts/entities/lamp.gd",
	"bell": "res://scripts/entities/bell.gd",
	"sign": "res://scripts/entities/sign.gd",
	"pickup": "res://scripts/entities/pickup.gd",
	"vent": "res://scripts/entities/vent.gd",
	"seadoor": "res://scripts/entities/seadoor.gd",
	"raft": "res://scripts/entities/raft.gd",
	"statue": "res://scripts/entities/statue.gd",
	"crab": "res://scripts/enemies/crab.gd",
	"gull": "res://scripts/enemies/gull.gd",
	"fish": "res://scripts/enemies/fish.gd",
	"jelly": "res://scripts/enemies/jelly.gd",
	"hopper": "res://scripts/enemies/hopper.gd",
	"barnacle": "res://scripts/enemies/barnacle.gd",
	"eel": "res://scripts/enemies/eel.gd",
	"husk": "res://scripts/enemies/husk.gd",
	"shot": "res://scripts/enemies/shot.gd",
	"wave": "res://scripts/bosses/wave.gd",
	"greatbell": "res://scripts/entities/greatbell.gd",
	"hermit": "res://scripts/bosses/hermit.gd",
	"conger": "res://scripts/bosses/conger.gd",
	"albatross": "res://scripts/bosses/albatross.gd",
	"drinker": "res://scripts/bosses/drinker.gd",
}

var map: WorldMap
var player: Player
var pad: Pad
var room: WorldMap.Room
var ents: Array = []
var old_ents: Array = []
var platforms: Array = []
var sim := false

var water_y := 0.0
var water_target := 0.0
var wet_y := 0.0
var tide_speed := TIDE_SPEED
var tide_moving := false
var tide_ticks := 0

var cam := Vector2.ZERO
var shake := 0.0
var hitstop := 0
var trans_t := 0
var trans_from := Vector2.ZERO
var trans_to := Vector2.ZERO
var ticks := 0
var freeze := 0
var respawn_t := 0
var fade := 0.0
var boss: Node = null
var locked_room := false

var root: Node2D
var static_root: Node2D
var ent_root: Node2D
var back_layer: TileMapLayer
var main_layer: TileMapLayer
var prop_layer: TileMapLayer
var wet_layer: TileMapLayer
var fx: Fx
var ocean: Ocean
var backdrop: Backdrop
var hud: Hud
var grade: ShaderMaterial
var grade_wet: ShaderMaterial
var fork_menu := false
var fork_sel := 0
var locks: Array[Vector2i] = []
var returning := false
var ride: Array[Vector2] = []
var ending := 0
var ending_t := 0
var attract := false


func _init() -> void:
	map = WorldMap.new()


func setup(p: Pad, simulate := false) -> void:
	pad = p
	sim = simulate
	root = Node2D.new()
	add_child(root)
	grade = ShaderMaterial.new()
	grade.shader = load("res://shaders/grade.gdshader")
	grade_wet = ShaderMaterial.new()
	grade_wet.shader = load("res://shaders/grade.gdshader")
	grade_wet.set_shader_parameter("wet_only", true)
	var tileset := _make_tileset()
	back_layer = _tile_layer(tileset, grade, -20)
	static_root = Node2D.new()
	static_root.z_index = -15
	root.add_child(static_root)
	main_layer = _tile_layer(tileset, grade, -10)
	wet_layer = _tile_layer(tileset, grade_wet, -9)
	prop_layer = _tile_layer(tileset, null, -8)
	ent_root = Node2D.new()
	root.add_child(ent_root)
	player = Player.new()
	player.game = self
	player.pad = pad
	player.z_index = 5
	root.add_child(player)
	fx = Fx.new()
	fx.z_index = 8
	root.add_child(fx)
	backdrop = Backdrop.new()
	add_child(backdrop)
	backdrop.setup(grade)
	ocean = Ocean.new()
	add_child(ocean)
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	_paint_world()
	_build_statics()


func _tile_layer(ts: TileSet, mat: Material, z: int) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.tile_set = ts
	l.material = mat
	l.z_index = z
	root.add_child(l)
	return l


func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(8, 8)
	var src := TileSetAtlasSource.new()
	var tex: Texture2D = load("res://assets/gfx/tiles.png")
	src.texture = tex
	src.texture_region_size = Vector2i(8, 8)
	ts.add_source(src, 0)
	var size := tex.get_size() / 8.0
	for y in int(size.y):
		for x in int(size.x):
			src.create_tile(Vector2i(x, y))
	return ts


# --- painting the world -------------------------------------------------------

func _paint_world() -> void:
	var w := map.w
	var h := map.h
	# chamfer distance from open space, capped: how deep inside rock is each tile
	var dist := PackedByteArray()
	dist.resize(w * h)
	dist.fill(9)
	for i in w * h:
		if not map.is_block(map.tiles[i]):
			dist[i] = 0
	for y in range(1, h):
		for x in range(1, w - 1):
			var i := y * w + x
			var d := mini(mini(dist[i], dist[i - 1] + 1), mini(dist[i - w] + 1, mini(dist[i - w - 1] + 1, dist[i - w + 1] + 1)))
			dist[i] = d
	for y in range(h - 2, -1, -1):
		for x in range(w - 2, 0, -1):
			var i := y * w + x
			var d := mini(mini(dist[i], dist[i + 1] + 1), mini(dist[i + w] + 1, mini(dist[i + w + 1] + 1, dist[i + w - 1] + 1)))
			dist[i] = d
	for y in h:
		for x in w:
			var i := y * w + x
			var b := map.back[i]
			if b != 0:
				var v := (x & 3) + (y & 1) * 4
				var col := v + (8 if b == 2 else 0)
				back_layer.set_cell(Vector2i(x, y), 0, Vector2i(col, map.themes[i] * 10 + 9))
			_paint_cell(x, y, dist[i])
	for ring in map.rings:
		prop_layer.set_cell(Vector2i(ring.x >> 3, ring.y >> 3), 0, Vector2i(12, MISC_ROW + 1))
	_scatter_life()


func _paint_cell(x: int, y: int, depth: int) -> void:
	var c := Vector2i(x, y)
	var t := map.get_tile(x, y)
	main_layer.erase_cell(c)
	prop_layer.erase_cell(c)
	match t:
		WorldMap.SOLID, WorldMap.BREAK, WorldMap.DOOR:
			var th := int(map.themes[map.index(x, y)])
			var mask := 0
			mask |= 1 if map.solid_at(x, y - 1) else 0
			mask |= 2 if map.solid_at(x + 1, y) else 0
			mask |= 4 if map.solid_at(x, y + 1) else 0
			mask |= 8 if map.solid_at(x - 1, y) else 0
			var v := (x & 3) + (y & 1) * 4
			if mask != 15:
				main_layer.set_cell(c, 0, Vector2i(mask, th * 10 + v))
			else:
				var d := clampi(depth, 1, 3)
				main_layer.set_cell(c, 0, Vector2i((d - 1) * 4 + (x & 3), th * 10 + 8))
			if t == WorldMap.BREAK:
				prop_layer.set_cell(c, 0, Vector2i(12 + (x & 1) + (y & 1) * 2, MISC_ROW))
			elif t == WorldMap.DOOR:
				prop_layer.set_cell(c, 0, Vector2i(8 + (y & 1), MISC_ROW + 1))
		WorldMap.ONEWAY:
			var l := map.get_tile(x - 1, y) == WorldMap.ONEWAY or map.solid_at(x - 1, y)
			var r := map.get_tile(x + 1, y) == WorldMap.ONEWAY or map.solid_at(x + 1, y)
			var col := 3
			if l and r:
				col = 1
			elif r:
				col = 0
			elif l:
				col = 2
			main_layer.set_cell(c, 0, Vector2i(col, MISC_ROW))
		WorldMap.LADDER:
			main_layer.set_cell(c, 0, Vector2i(4 + (y & 1), MISC_ROW))
		WorldMap.SAND:
			main_layer.set_cell(c, 0, Vector2i(8 + (x & 1) + (y & 1) * 2, MISC_ROW))
		WorldMap.SPIKE:
			var col := 0
			if map.solid_at(x, y + 1):
				col = 0
			elif map.solid_at(x, y - 1):
				col = 2
			elif map.solid_at(x - 1, y):
				col = 4
			elif map.solid_at(x + 1, y):
				col = 6
			prop_layer.set_cell(c, 0, Vector2i(col + (x & 1), MISC_ROW + 1))


## Tufts and weed on exposed ledges. On the wet layer: they only exist below the wet line.
func _scatter_life() -> void:
	var seed_v := 77
	for y in range(1, map.h):
		for x in map.w:
			if not map.solid_at(x, y) or map.solid_at(x, y - 1):
				continue
			if map.get_tile(x, y - 1) != WorldMap.AIR:
				continue
			seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
			var r := (seed_v >> 8) & 15
			if r < 7:
				wet_layer.set_cell(Vector2i(x, y - 1), 0, Vector2i(r % 6, MISC_ROW + 2))


func _build_statics() -> void:
	var deco := Sprites.deco()
	for r in map.rooms:
		for e in r.ents:
			if e.kind == "deco":
				var info: Array = deco.get(e.get("name", ""), [])
				if info.is_empty():
					push_error("unknown deco %s in %s" % [e.get("name", ""), r.id])
					continue
				var sp := Sprite2D.new()
				sp.texture = Sprites.deco_tex()
				sp.region_enabled = true
				sp.region_rect = Rect2(info[0], info[1], info[2], info[3])
				sp.centered = false
				sp.position = Vector2(int(e.x) - int(info[2]) / 2, int(e.y) - int(info[3]))
				if e.has("front"):
					sp.z_index = 15
				if e.has("flip"):
					sp.flip_h = true
				sp.material = grade
				static_root.add_child(sp)


# --- starting and restoring ---------------------------------------------------

func begin(from_save: bool) -> void:
	water_y = G.tide_px(int(G.s.level))
	water_target = water_y
	wet_y = minf(float(G.s.wet_y), water_y)
	_wash_sand(true)
	for key: String in G.s.broken:
		var p := key.split(",")
		_remove_tile(int(p[0]), int(p[1]))
	for key: String in G.s.opened:
		var p := key.split(",")
		_remove_tile(int(p[0]), int(p[1]))
	if G.flag("drinker_dead"):
		_open_hatch()
	var spawn := Vector2i(int(G.s.cp[0]), int(G.s.cp[1])) if not G.s.cp.is_empty() else start_position()
	player.hp = int(G.s.max_hp)
	player.breath = G.max_breath()
	player.place(spawn.x, spawn.y)
	var r := map.room_at(spawn.x, spawn.y - 4)
	_enter_room(r)
	cam = _camera_target()
	_sync_view()
	if not sim:
		Sfx.music(room.music)


func start_position() -> Vector2i:
	for r in map.rooms:
		for e in r.ents:
			if e.kind == "start":
				return Vector2i(e.x, e.y)
	return Vector2i(100, 100)


# --- tick -----------------------------------------------------------------------

func _physics_process(_d: float) -> void:
	if sim or get_tree().paused:
		return
	pad.poll()
	tick()


func tick() -> void:
	ticks += 1
	if not sim:
		fx.tick()
		ocean.tick()
		hud.tick()
	if attract:
		_sync_view()
		return
	G.s.time = float(G.s.time) + 1.0 / 60.0
	if fade > 0.0 and respawn_t == 0 and ending == 0:
		fade = maxf(fade - 0.05, 0.0)
	if respawn_t > 0:
		_respawn_tick()
		_sync_view()
		return
	if hud.dialog_active():
		hud.dialog_input(pad)
		_sync_view()
		return
	if fork_menu:
		_fork_tick()
		_sync_view()
		return
	if hitstop > 0:
		hitstop -= 1
		_sync_view()
		return
	if trans_t > 0:
		_transition_tick()
		_sync_view()
		return
	if ending > 0:
		_ending_tick()
	elif freeze > 0:
		freeze -= 1
	else:
		_control_tick()
	if returning:
		_return_tick()
	_tide_tick()
	for p in platforms:
		p.tick()
	for e in ents:
		if not e.dead:
			e.tick()
	_collisions()
	_prune()
	_check_room()
	_camera_tick()
	_sync_view()


func _control_tick() -> void:
	if pad.interact_p and player.state in [Player.NORMAL, Player.SWIM, Player.HANG, Player.CLIMB]:
		if _try_interact():
			return
	if pad.fork_p and G.has("fork") and player.state in [Player.NORMAL, Player.SWIM, Player.HANG]:
		_open_fork()
		return
	player.tick()
	if player.state == Player.DEAD and respawn_t == 0:
		_begin_death()


func _try_interact() -> bool:
	var best: Ent = null
	var best_d := 22.0
	var c := player.center()
	for e in ents:
		if e.dead or not e.interactive():
			continue
		var d := c.distance_to(e.interact_point())
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return false
	best.interact()
	return true


func nearby_interact() -> Ent:
	var c := player.center()
	for e in ents:
		if not e.dead and e.interactive() and c.distance_to(e.interact_point()) < 22.0:
			return e
	return null


func _collisions() -> void:
	var pr := player.rect()
	var attacking := player.attacking()
	var ar := player.attack_rect() if attacking else Rect2i()
	for e in ents:
		if e.dead or not e.solid_body:
			continue
		var er: Rect2i = e.body_rect()
		if attacking and e.hittable and not player.hit_ids.has(e.get_instance_id()) and ar.intersects(er):
			player.hit_ids[e.get_instance_id()] = true
			e.take_hit(player_damage(), player.atk_dir)
			player.attack_recoil()
			hitstop = 3
		if e.contact > 0 and not e.dead and pr.intersects(er) and player.iframes == 0:
			player.hurt(e.contact, e.x)
	if attacking:
		_hit_tiles(ar)


func player_damage() -> int:
	return 2 if G.has("barb") else 1


func _hit_tiles(ar: Rect2i) -> void:
	var x0 := ar.position.x >> 3
	var x1 := (ar.end.x - 1) >> 3
	var y0 := ar.position.y >> 3
	var y1 := (ar.end.y - 1) >> 3
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			var t := map.get_tile(tx, ty)
			if t == WorldMap.BREAK:
				G.s.broken["%d,%d" % [tx, ty]] = true
				_remove_tile(tx, ty)
				fx_burst(tx * 8 + 4, ty * 8 + 4, Color("8a93a6"), 8)
				snd("break")
				shake = maxf(shake, 2.0)
			elif t == WorldMap.SPIKE and player.atk_dir == Vector2i.DOWN and not player.hit_ids.has("spike"):
				player.hit_ids["spike"] = true
				player.attack_recoil()
				player.iframes = maxi(player.iframes, 10)
				snd("clink")


func _remove_tile(tx: int, ty: int) -> void:
	map.set_tile(tx, ty, WorldMap.AIR)
	for y in range(ty - 1, ty + 2):
		for x in range(tx - 1, tx + 2):
			if x >= 0 and y >= 0 and x < map.w and y < map.h:
				_paint_cell(x, y, 1)


func _prune() -> void:
	var keep := []
	for e in ents:
		if e.dead:
			e.queue_free()
		else:
			keep.append(e)
	ents = keep


# --- rooms and camera --------------------------------------------------------------

func _check_room() -> void:
	var c := player.center()
	if room.rect.has_point(Vector2i(int(c.x), int(c.y))):
		return
	var next := map.room_at(int(c.x), int(c.y))
	if next == null or next == room:
		return
	if locked_room:
		return
	go_to_room(next)


func go_to_room(next: WorldMap.Room) -> void:
	var going_up := player.center().y < room.rect.position.y
	old_ents = ents
	ents = []
	_enter_room(next)
	if sim:
		_end_transition()
		return
	trans_from = cam
	trans_to = _camera_target()
	trans_t = TRANSITION_TICKS
	if going_up and player.state == Player.NORMAL:
		player.vy = minf(player.vy, -176.0)


func _transition_tick() -> void:
	trans_t -= 1
	var t := 1.0 - float(trans_t) / TRANSITION_TICKS
	t = t * t * (3.0 - 2.0 * t)
	cam = trans_from.lerp(trans_to, t)
	if trans_t == 0:
		_end_transition()


func _end_transition() -> void:
	for e in old_ents:
		e.queue_free()
	old_ents = []


func _enter_room(r: WorldMap.Room) -> void:
	room = r
	platforms.clear()
	for cy in r.ch:
		for cx in r.cw:
			G.s.seen["%d,%d" % [r.cx + cx, r.cy + cy]] = true
	if sim:
		return
	ocean.set_room(r)
	for e in r.ents:
		spawn(e)
	if not returning and ending == 0:
		Sfx.music(r.music)
	if r.title != "":
		hud.show_area(tr(r.title))
	if r.dark > 0.0:
		ocean.dark_target = r.dark
	else:
		ocean.dark_target = 0.0


func spawn(props: Dictionary) -> Ent:
	var kind: String = props.kind
	if not ENT_SCRIPTS.has(kind):
		return null
	var s: Script = load(ENT_SCRIPTS[kind])
	var e: Ent = s.new()
	e.game = self
	e.props = props
	e.x = int(props.get("x", 0))
	e.y = int(props.get("y", 0))
	if not e.should_spawn():
		e.free()
		return null
	ent_root.add_child(e)
	e.begin()
	ents.append(e)
	return e


func _camera_target() -> Vector2:
	var c := player.center()
	var r := room.rect
	var tx := c.x - G.VIEW_W / 2.0 + player.facing * 18.0
	var ty := c.y - G.VIEW_H / 2.0 - 8.0
	var x := r.position.x + (r.size.x - G.VIEW_W) / 2.0
	var y := r.position.y + (r.size.y - G.VIEW_H) / 2.0
	if r.size.x - G.VIEW_W >= 8:
		x = clampf(tx, r.position.x, r.end.x - G.VIEW_W)
	if r.size.y - G.VIEW_H >= 8:
		y = clampf(ty, r.position.y, r.end.y - G.VIEW_H)
	return Vector2(x, y)


func _camera_tick() -> void:
	var t := _camera_target()
	cam.x += (t.x - cam.x) * 0.12
	cam.y += (t.y - cam.y) * 0.14
	if shake > 0.0:
		shake = maxf(shake - 0.15, 0.0)


func _sync_view() -> void:
	if sim:
		return
	player.render()
	for e in ents:
		e.render()
	for e in old_ents:
		e.render()
	var sh := Vector2.ZERO
	if shake > 0.0:
		sh = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	var c := (cam + sh).round()
	# the camera moves the canvas, not a node: moving a node over the world's tile layers costs
	# a slow phone most of a frame in transform notifications
	get_viewport().canvas_transform = Transform2D(0.0, -c)
	grade.set_shader_parameter("wet_y", wet_y - c.y)
	grade.set_shader_parameter("cam_x", c.x)
	grade_wet.set_shader_parameter("wet_y", wet_y - c.y)
	grade_wet.set_shader_parameter("cam_x", c.x)
	backdrop.sync(c)
	ocean.sync(c, water_y, ticks, player)
	Sfx.set_muffled(player.head_under())
	hud.sync()
	queue_redraw()


# --- tide --------------------------------------------------------------------------

## Send the sea to a level. Returns false if it is already there.
func call_tide(level: int) -> bool:
	var target := G.tide_px(level)
	G.s.level = level
	G.s.rung[str(level)] = true
	if is_equal_approx(target, water_target):
		return false
	var rising := target < water_y
	if rising:
		water_y = minf(water_y, cam.y + G.VIEW_H + 48.0)
	else:
		water_y = maxf(water_y, cam.y - 48.0)
	water_target = target
	tide_moving = true
	tide_ticks = 0
	shake = maxf(shake, 2.5)
	if not sim:
		hud.show_banner(tr("THE SEA RISES") if rising else tr("THE SEA FALLS"))
		Sfx.rumble(true)
	return true


func set_tide_instant(level: int) -> void:
	water_y = G.tide_px(level)
	water_target = water_y
	G.s.level = level
	if water_y < wet_y:
		wet_y = water_y
		G.s.wet_y = wet_y
	_wash_sand(false)


func _tide_tick() -> void:
	if not tide_moving:
		return
	tide_ticks += 1
	var step := tide_speed / 60.0
	# a soft start and landing, so the sea feels heavy
	var remain := absf(water_target - water_y)
	var ease_k := minf(1.0, minf(remain / 40.0 + 0.2, tide_ticks / 50.0 + 0.1))
	water_y = move_toward(water_y, water_target, step * ease_k)
	if water_y < wet_y:
		wet_y = water_y
		G.s.wet_y = wet_y
		_wash_sand(false)
	if not sim:
		shake = maxf(shake, 0.6)
		if ticks % 7 == 0:
			var sx := cam.x + randf() * G.VIEW_W
			if water_y > cam.y and water_y < cam.y + G.VIEW_H:
				fx_splash(int(sx), int(water_y), 40.0)
				ocean.splash(sx, 2.0)
	if is_equal_approx(water_y, water_target):
		water_y = water_target
		tide_moving = false
		if not sim:
			Sfx.rumble(false)


## Sand goes the moment the sea touches any part of a drift: the rest slumps in after it.
func _wash_sand(silent: bool) -> void:
	var todo: Array[Vector2i] = []
	for c in map.sand_cells:
		if (c.y + 1) * 8 > wet_y and map.get_tile(c.x, c.y) == WorldMap.SAND:
			todo.append(c)
	if todo.is_empty():
		return
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		if map.get_tile(c.x, c.y) != WorldMap.SAND:
			continue
		_remove_tile(c.x, c.y)
		if not silent:
			fx_burst(c.x * 8 + 4, c.y * 8 + 4, Color("e3c48a"), 3)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if map.get_tile(c.x + d.x, c.y + d.y) == WorldMap.SAND:
				todo.append(c + d)
	var left: Array[Vector2i] = []
	for c in map.sand_cells:
		if map.get_tile(c.x, c.y) == WorldMap.SAND:
			left.append(c)
	map.sand_cells = left


# --- damage, death, checkpoints ---------------------------------------------------

func spike_lethal(p: Player) -> bool:
	if sim:
		p.set_meta("spiked", true)
		return true
	if p.state == Player.SWIM:
		p.hurt(1, p.ix)
		return true
	p.hurt(1, p.ix)
	if p.state != Player.DEAD:
		fade = 0.6
		p.place(p.safe.x, p.safe.y)
		cam = _camera_target()
	return true


func on_player_hurt() -> void:
	if sim:
		return
	snd("hurt")
	hitstop = 6
	shake = maxf(shake, 3.0)
	fx_burst(player.ix, player.iy - 6, Color("e8514a"), 6)


func _begin_death() -> void:
	respawn_t = 80
	G.s.deaths = int(G.s.deaths) + 1
	snd("die")


func _respawn_tick() -> void:
	respawn_t -= 1
	if respawn_t > 40:
		fade = minf(fade + 0.05, 1.0)
	if respawn_t == 40:
		_do_respawn()


func _do_respawn() -> void:
	fade = 1.0
	boss = null
	locked_room = false
	unlock_all()
	tide_speed = TIDE_SPEED
	water_target = G.tide_px(int(G.s.level))
	water_y = water_target
	tide_moving = false
	var spawn := Vector2i(int(G.s.cp[0]), int(G.s.cp[1])) if not G.s.cp.is_empty() else start_position()
	player.hp = int(G.s.max_hp)
	player.breath = G.max_breath()
	player.iframes = 60
	player.sprite.modulate = Color.WHITE
	player.place(spawn.x, spawn.y)
	for e in ents:
		e.queue_free()
	ents = []
	_enter_room(map.room_at(spawn.x, spawn.y - 4))
	cam = _camera_target()


## Bar the way out of a boss room for the length of the fight.
func lock_area(x0: int, y0: int, x1: int, y1: int) -> void:
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			if map.get_tile(tx, ty) == WorldMap.AIR:
				map.set_tile(tx, ty, WorldMap.DOOR)
				locks.append(Vector2i(tx, ty))
				_paint_cell(tx, ty, 1)
	snd("door")


func unlock_all() -> void:
	for c in locks:
		_remove_tile(c.x, c.y)
	locks.clear()


# --- the sea comes home -----------------------------------------------------------

## The Drinker is dead. Everything it swallowed comes back at once, and it carries you with it:
## out of the Sump, up the whole height of the Well, and through the floor of the Belfry.
func begin_return() -> void:
	returning = true
	G.s.rung["5"] = true
	tide_speed = 150.0
	call_tide(5)
	hud.show_banner(tr("THE SEA COMES HOME"))
	Sfx.music("return")
	ride = [Vector2(2200, 1256), Vector2(1520, 1256), Vector2(1440, 1240), Vector2(1440, 180)]
	player.enter(Player.STILL)
	player.carried = true
	player.vx = 0.0
	player.vy = 0.0
	player.diving = false


func _return_tick() -> void:
	if ride.is_empty():
		if not tide_moving and water_y <= G.tide_px(5):
			returning = false
			tide_speed = TIDE_SPEED
		return
	var here := Vector2(player.ix, player.iy)
	var goal: Vector2 = ride[0]
	var speed := 3.0 if here.y > 400.0 else 2.2
	var next := here.move_toward(goal, speed)
	player.ix = int(next.x)
	player.iy = int(next.y)
	player.facing = -1 if goal.x < here.x else player.facing
	if ticks % 6 == 0:
		fx_bubble(player.ix + randi_range(-6, 6), player.iy - randi_range(0, 12))
	if player.iy < 300:
		_open_hatch()
	if next.distance_to(goal) < 3.0:
		ride.pop_front()
		if ride.is_empty():
			player.carried = false
			player.enter(Player.SWIM)
			player.vy = -60.0


func _open_hatch() -> void:
	var opened := false
	for ty in range(20, 23):
		for tx in range(176, 184):
			if map.get_tile(tx, ty) == WorldMap.DOOR:
				_remove_tile(tx, ty)
				fx_burst(tx * 8 + 4, ty * 8 + 4, Color("8a93a6"), 4)
				opened = true
	if opened:
		snd("break")
		shake = maxf(shake, 5.0)


func start_finale() -> void:
	ending = 1
	ending_t = 0
	player.start_ringing()
	player.state_t = -100000
	snd("greatbell")
	Sfx.music("ending")
	fx.ring_wave(player.ix, player.iy - 40, Color(1, 1, 1))
	shake = 6.0


func _ending_tick() -> void:
	if ending == 2:
		return
	ending_t += 1
	if ending_t % 90 == 0 and ending_t < 600:
		fx.ring_wave(int(cam.x) + 160, int(cam.y) + 70, Color(1, 0.95, 0.75))
	# the wrack line climbs off the top of the world, and the sky comes back
	if ending_t > 60:
		wet_y = move_toward(wet_y, cam.y - 260.0, 0.8)
		G.s.wet_y = wet_y
	if ending_t == 520:
		hud.say(tr("By morning the harbour was full of boats, and the streets were full of people who could not say how long they had slept.\n\nYou kept ringing until she took the rope from your hands."))
	if ending_t > 540 and not hud.dialog_active():
		fade = minf(fade + 0.012, 1.0)
		if fade >= 1.0:
			ending = 2
			finished.emit()


## From the pause menu: an escape hatch from anywhere, in case the tide has left you stuck.
func respawn_now() -> void:
	_do_respawn()
	fade = 1.0


func count_items() -> int:
	var n := 0
	for r in map.rooms:
		for e in r.ents:
			if e.kind == "pickup":
				n += 1
	return n


func count_found() -> int:
	return G.s.taken.size()


func set_checkpoint(x: int, y: int) -> void:
	G.s.cp = [x, y]
	player.hp = int(G.s.max_hp)
	G.save_game()


# --- the reel's queries --------------------------------------------------------------

func line_clear(a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var n := int(d.length() / 3.0)
	for i in range(1, n):
		var p := a + d * (float(i) / n)
		if map.solid_at(int(p.x) >> 3, int(p.y) >> 3):
			return false
	return true


## A cast that found no ring: the line flies straight, snagging on the first thing in its way.
func cast_at(from: Vector2, aim: Vector2, reach: float) -> Dictionary:
	var p := from
	var step := 3.0
	var dist := 0.0
	while dist < reach:
		p += aim * step
		dist += step
		if map.solid_at(int(p.x) >> 3, int(p.y) >> 3):
			return {"pos": p, "ent": null}
		for e in ents:
			if not e.dead and e.solid_body and e.hittable and e.body_rect().has_point(Vector2i(int(p.x), int(p.y))):
				e.on_cast(aim)
				return {"pos": p, "ent": e}
	return {"pos": p, "ent": null}


# --- the fork --------------------------------------------------------------------------

func _open_fork() -> void:
	fork_menu = true
	fork_sel = int(G.s.level)
	snd("fork")


func _fork_tick() -> void:
	if pad.up_p:
		fork_sel = _fork_next(1)
	elif pad.down_p:
		fork_sel = _fork_next(-1)
	if pad.jump_p or pad.interact_p and not pad.up_p:
		fork_menu = false
		if fork_sel != int(G.s.level):
			snd("bell%d" % fork_sel)
			fx.ring_wave(player.ix, player.iy - 8)
			call_tide(fork_sel)
	elif pad.fork_p or pad.attack_p or pad.cast_p:
		fork_menu = false


func _fork_next(dir: int) -> int:
	var i := fork_sel
	for n in 6:
		i += dir
		if i < 0 or i > 5:
			return fork_sel
		if G.s.rung.has(str(i)):
			return i
	return fork_sel


# --- fx and sound passthroughs, silent in simulation --------------------------------------

func snd(name: String) -> void:
	if not sim:
		Sfx.play(name)


func fx_dust(x: int, y: int, n: int) -> void:
	if not sim:
		fx.dust(x, y, n)


func fx_puff(x: int, y: int) -> void:
	if not sim:
		fx.puff(x, y)


func fx_bubble(x: int, y: int) -> void:
	if not sim:
		fx.bubble(x, y)


func fx_burst(x: int, y: int, c: Color, n: int) -> void:
	if not sim:
		fx.burst(x, y, c, n)


func fx_splash(x: int, y: int, strength: float) -> void:
	if sim:
		return
	fx.splash(x, y, strength)
	ocean.splash(float(x), minf(strength / 60.0, 5.0))
