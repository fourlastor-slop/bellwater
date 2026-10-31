extends Node
## Plays each boss fight with a simple bot, on the real game with real entities, then the whole ending.
## Then a soak: random input in every room at several tides, to shake out runtime errors.
## run: godot --headless --path . res://tests/bosses.tscn

var game: Game
var pad := Pad.new()
var fails := 0


func _ready() -> void:
	G.new_run()
	G.headless_sim = true
	for a in ["reel", "helm", "bellows", "line", "barb"]:
		G.give(a)
	G.s.max_hp = 6
	game = Game.new()
	add_child(game)
	game.setup(pad, false)
	game.set_physics_process(false)
	game.begin(false)
	Sfx.process_mode = Node.PROCESS_MODE_DISABLED
	walk_in("up the stairs", Vector2i(5 * 320 + 103 * 8, 1 * 184 + 128), -1)
	walk_in("back in from the Well", Vector2i(5 * 320 + 12, 1 * 184 + 160), 1)
	fight("hermit", "salthouse", 2, Vector2i(7 * 320 + 90, 3 * 184 + 160), "hermit_dead")
	fight("conger", "cistern", 2, Vector2i(1 * 320 + 500, 5 * 184 + 100), "conger_dead")
	fight("albatross", "roofs", 3, Vector2i(5 * 320 + 700, 1 * 184 + 152), "albatross_dead")
	fight("drinker", "drinker", 0, Vector2i(7 * 320 + 60, 6 * 184 + 160), "drinker_dead")
	the_return()
	soak()
	print("BOSSES ", "FAILED: %d" % fails if fails > 0 else "OK")
	get_tree().quit(1 if fails > 0 else 0)


func teleport(pos: Vector2i, level: int) -> void:
	for e in game.ents:
		e.queue_free()
	game.ents = []
	game.set_tide_instant(level)
	game.tide_moving = false
	game.player.place(pos.x, pos.y)
	game._enter_room(game.map.room_at(pos.x, pos.y - 4))
	game.cam = game._camera_target()


func step(n := 1) -> void:
	for i in n:
		game.hud.dlg_pages.clear()
		game.tick()


## Walk into the Albatross's arena on foot, rather than teleporting in: it has to wake, and the
## doors have to shut with the player inside the arena, not on top of them.
func walk_in(label: String, at: Vector2i, dir: int) -> void:
	teleport(at, 3)
	var pl := game.player
	var r := game.room.rect
	var t := 0
	while t < 60 * 20 and game.boss == null:
		t += 1
		pad.clear()
		pad.x = dir
		pl.hp = int(G.s.max_hp)
		pl.iframes = 2
		step()
		if pl.ix < r.position.x or pl.ix > r.end.x:
			break
	var awake: bool = game.boss != null
	var free := not pl.box_blocked(pl.ix, pl.iy)
	var west := game.map.get_tile((r.position.x >> 3) + 1, (r.position.y >> 3) + 17) == WorldMap.DOOR
	var east := game.map.get_tile((r.end.x >> 3) - 22, (r.position.y >> 3) + 17) == WorldMap.DOOR
	var ok := awake and free and west and east
	print("%-22s %s (woke %s after %.1f s at x %d, player free %s, doors %s/%s)" % [label, "ok" if ok else "FAILED", awake, t / 60.0, pl.ix - r.position.x, free, west, east])
	if not ok:
		fails += 1
	game.boss = null
	game.locked_room = false
	game.unlock_all()


func fight(kind: String, room_id: String, level: int, pos: Vector2i, flag: String) -> void:
	teleport(pos, level)
	var limit := 60 * 240
	var ticks := 0
	var boss_seen := false
	var min_hp := 1000
	while ticks < limit and not G.flag(flag):
		ticks += 1
		game.player.hp = int(G.s.max_hp)
		game.player.iframes = 2
		game.player.breath = 20.0
		_bot(pad)
		step()
		if game.boss != null and is_instance_valid(game.boss):
			boss_seen = true
			min_hp = mini(min_hp, game.boss.hp)
	var ok := G.flag(flag)
	if not ok:
		fails += 1
	print("%-10s %s in %.1f s (saw boss %s, low hp %d)" % [kind, "defeated" if ok else "NOT DEFEATED", ticks / 60.0, boss_seen, min_hp])
	for k in 200:
		game.player.iframes = 2
		step()


## Walk at the boss's weak spot and swing. Crude, but it's enough to see the state machines through.
func _bot(p: Pad) -> void:
	p.clear()
	var pl := game.player
	var b: Variant = game.boss
	if b == null or not is_instance_valid(b):
		return
	var tx: int = b.x
	var ty: int = b.y - 8
	if b.get("eye") != null and b.get("state") in [4, 5]:
		tx = b.eye.position.x + b.eye.size.x / 2
		ty = b.eye.position.y + b.eye.size.y / 2
	p.x = signi(tx - pl.ix)
	if absi(tx - pl.ix) < 12:
		p.x = 0
	if pl.state == Player.SWIM:
		p.y = signi(ty - pl.iy)
	if game.ticks % 7 == 0:
		p.attack_p = true
		if ty < pl.iy - 24:
			p.y = -1
	if game.ticks % 43 == 0:
		p.jump = true
		p.jump_p = true
	if game.ticks % 97 == 0:
		p.cast_p = true
		p.y = -1


func the_return() -> void:
	var t := 0
	while t < 60 * 60 and game.returning:
		t += 1
		pad.clear()
		step()
	print("return took %.1f s; sea at %.0f; player at %d,%d, room %s; hatch open: %s" % [t / 60.0, game.water_y, game.player.ix, game.player.iy, game.room.id, game.map.get_tile(180, 21) == WorldMap.AIR])
	if game.returning or game.map.get_tile(180, 21) != WorldMap.AIR or game.room.id != "belfry":
		fails += 1
		return
	step(40)
	print("afloat in the Belfry at ", game.player.ix, ",", game.player.iy, " state ", game.player.state)
	var bell_ent: Ent = null
	for e in game.ents:
		if e.props.get("kind", "") == "greatbell":
			bell_ent = e
	if bell_ent == null:
		print("no great bell!")
		fails += 1
		return
	bell_ent.interact()
	var finished := [false]
	game.finished.connect(func() -> void: finished[0] = true)
	for k in 60 * 30:
		pad.clear()
		if k % 30 == 0:
			pad.jump_p = true
		game.tick()
		if finished[0]:
			break
	print("finale finished: ", finished[0], " wet_y ", game.wet_y)
	if not finished[0]:
		fails += 1
	game.ending = 0
	game.fade = 0.0
	game.returning = false


func soak() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var total := 0
	for r in game.map.rooms:
		for level in [0, 1, 2, 3, 4]:
			var at := Vector2i(r.rect.position.x + r.rect.size.x / 2, r.rect.position.y + 120)
			for e in r.ents:
				if e.has("x") and e.kind not in ["deco", "hermit", "conger", "albatross", "drinker"]:
					at = Vector2i(e.x, e.y)
					break
			teleport(at, level)
			for i in 240:
				pad.clear()
				pad.x = rng.randi_range(-1, 1)
				pad.y = rng.randi_range(-1, 1)
				pad.jump = rng.randf() < 0.3
				pad.jump_p = pad.jump
				pad.attack_p = rng.randf() < 0.1
				pad.cast_p = rng.randf() < 0.05
				game.player.hp = 9
				game.player.iframes = 0 if i % 50 == 0 else 2
				step()
				if game.respawn_t > 0:
					game.respawn_t = 0
					game.fade = 0.0
					teleport(at, level)
				total += 1
	print("soak ticks ", total)
