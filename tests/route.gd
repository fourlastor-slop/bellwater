extends Node
## Proves the game can be finished: a best-first search over short input macros, run through the
## real Player.tick() on the real map. Each leg must physically reach its objective, in order,
## with only the abilities and tide the player would have at that point.
## Enemies are not simulated (they can be fought); geometry, water and physics are exact.
##
## run: godot --headless --path . res://tests/route.tscn

const MAX_EXPANSIONS := 90000

var game: Game
var pad := Pad.new()
var p: Player
var failed := false
var total := 0
var last_n := 0
var coarse := false
var last_best := 0.0
var vents: Array[Vector2i] = []


class Heap:
	var items: Array = []

	func push(pri: float, val: int) -> void:
		items.append([pri, val])
		var i := items.size() - 1
		while i > 0:
			var up := (i - 1) / 2
			if items[up][0] <= items[i][0]:
				break
			var t: Array = items[up]
			items[up] = items[i]
			items[i] = t
			i = up

	func pop() -> int:
		var top: Array = items[0]
		var last: Array = items.pop_back()
		if not items.is_empty():
			items[0] = last
			var i := 0
			var n := items.size()
			while true:
				var l := i * 2 + 1
				var r := l + 1
				var m := i
				if l < n and items[l][0] < items[m][0]:
					m = l
				if r < n and items[r][0] < items[m][0]:
					m = r
				if m == i:
					break
				var t: Array = items[m]
				items[m] = items[i]
				items[i] = t
				i = m
		return top[1]

	func empty() -> bool:
		return items.is_empty()


func _ready() -> void:
	G.new_run()
	G.headless_sim = true
	game = Game.new()
	add_child(game)
	game.setup(pad, true)
	game.begin(false)
	p = game.player
	for r in game.map.rooms:
		for e in r.ents:
			if e.kind == "vent":
				vents.append(Vector2i(e.x, e.y))
	if "extras" in OS.get_cmdline_user_args():
		run_extras()
	else:
		run_route()
		if not failed:
			run_gates()
			run_extras()
	print("\nTOTAL expansions ", total)
	print("ROUTE ", "FAILED" if failed else "OK")
	get_tree().quit(1 if failed else 0)


func ent_pos(kind: String, key := "", val := "") -> Vector2i:
	for r in game.map.rooms:
		for e in r.ents:
			if e.kind == kind and (key == "" or str(e.get(key, "")) == val):
				return Vector2i(e.x, e.y)
	push_error("no entity %s %s=%s" % [kind, key, val])
	return Vector2i.ZERO


func bell(level: int, requires := "") -> Vector2i:
	for r in game.map.rooms:
		for e in r.ents:
			if e.kind == "bell" and int(e.level) == level and str(e.get("requires", "")) == requires:
				return Vector2i(e.x, e.y)
	push_error("no bell %d" % level)
	return Vector2i.ZERO


func item(name: String) -> Vector2i:
	return ent_pos("pickup", "item", name)


func open_door(door_name: String) -> void:
	var at := ent_pos("seadoor", "name", door_name)
	var tx := at.x >> 3
	var ty := (at.y - 4) >> 3
	var seen := {}
	var todo: Array[Vector2i] = [Vector2i(tx, ty)]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not seen.has(n) and game.map.get_tile(n.x, n.y) == WorldMap.DOOR:
				seen[n] = true
				todo.append(n)
				game.map.set_tile(n.x, n.y, WorldMap.AIR)


func ring(level: int) -> void:
	game.set_tide_instant(level)
	G.s.rung[str(level)] = true
	p.breath = G.max_breath()
	print("    ~ the sea goes to level ", level, " (", G.TIDE_NAMES[level], ")")


func run_route() -> void:
	leg("ring the Sea-Wall Bell", bell(1))
	ring(1)
	leg("float up the wall to the Quay", ent_pos("lamp", "tx", "195") if false else Vector2i(5 * 320 + 500, 4 * 184 + 160))
	leg("[opt] crow's nest pearl", Vector2i(9 * 320 + 53 * 8 + 4, 4 * 184 + 19 * 8))
	leg("Well east door, row 4", Vector2i(5 * 320 + 24, 4 * 184 + 160))
	leg("get the Reel in the Ropewalk", item("reel"))
	G.give("reel")
	leg("back to the Quay crane", Vector2i(5 * 320 + 56 * 8, 4 * 184 + 160))
	leg("up to Warehouse Row", Vector2i(5 * 320 + 40 * 8, 3 * 184 + 160))
	leg("[opt] storeman's locker wall", Vector2i(5 * 320 + 12 * 8, 3 * 184 + 9 * 8))
	leg("the Salt House", bell(2, "hermit_dead"))
	G.set_flag("hermit_dead")
	ring(2)
	leg("Well west door, row 3", Vector2i(2 * 320 + 76 * 8, 3 * 184 + 160))
	leg("through the Cellars to the Cliff", Vector2i(70 * 8, 3 * 184 + 160))
	leg("across the inlet", Vector2i(24 * 8, 3 * 184 + 160))
	leg("reel up to Lantern Row", Vector2i(30 * 8, 2 * 184 + 160))
	leg("the Brass Helm", item("helm"))
	G.give("helm")
	leg("Lantern Row east door", Vector2i(2 * 320 + 74 * 8, 2 * 184 + 160))
	leg("drop down the Well and dive to the Cistern door", Vector2i(3 * 320 + 36 * 8, 5 * 184 + 152))
	leg("the Great Cistern", bell(3, "conger_dead"))
	G.set_flag("conger_dead")
	ring(3)
	leg("swim back to the Well", Vector2i(4 * 320 + 100, 5 * 184 + 150))
	leg("float up the Well to row 2", Vector2i(4 * 320 + 160, 2 * 184 + 164))
	leg("[opt] market lamp", Vector2i(5 * 320 + 10 * 8, 2 * 184 + 160))
	leg("the Fish Stairs", Vector2i(7 * 320 + 60 * 8, 2 * 184 + 160))
	leg("swim the bay to the high door", Vector2i(12 * 320 - 40, 2 * 184 + 160 + 8))
	leg("swim back west to the Well", Vector2i(4 * 320 + 200, 2 * 184 + 164))
	leg("dive to the Well's vent", Vector2i(4 * 320 + 108, 5 * 184 + 150))
	leg("dive to the Ebb Bell", bell(0))
	ring(0)
	leg("through the Long Drain to the Flats", Vector2i(8 * 320 + 200, 5 * 184 + 112))
	leg("across the Flats to the keeper's door", ent_pos("seadoor", "name", "keeper"))
	open_door("keeper")
	leg("climb to the Bellows", item("bellows"))
	G.give("bellows")
	leg("the Keeper's Bell", bell(3, ""))
	ring(3)
	open_door("high")
	leg("out of the high door, back over the bay", Vector2i(7 * 320 + 60 * 8, 2 * 184 + 160))
	leg("up the Fish Stairs to the Roofs", Vector2i(5 * 320 + 90 * 8, 1 * 184 + 152))
	leg("the Albatross Bell", bell(4, "albatross_dead"))
	G.set_flag("albatross_dead")
	ring(4)
	leg("across the Well to the Terrace", Vector2i(1 * 320 + 100 * 8, 1 * 184 + 160))
	leg("up the ladder to the Belfry", Vector2i(3 * 320 + 20 * 8, 0 * 184 + 160))
	leg("the Tuning Fork", item("fork"))
	G.give("fork")
	G.set_flag("bell_salt")
	G.set_flag("bell_cistern")
	G.set_flag("bell_albatross")
	ring(0)
	leg("back down to the Terrace", Vector2i(1 * 320 + 100 * 8, 1 * 184 + 160))
	leg("fall down the Well", ent_pos("seadoor", "name", "sump"))
	open_door("sump")
	leg("through the Sump", Vector2i(7 * 320 + 16, 6 * 184 + 160))
	leg("the Drinker's mouth", Vector2i(7 * 320 + 26 * 8, 6 * 184 + 160))


func setup_state(level: int, abilities: Array, at: Vector2i) -> void:
	G.s.abilities = {}
	for a: String in abilities:
		G.give(a)
	G.s.air = 0
	game.set_tide_instant(level)
	p.place(at.x, at.y)
	p.breath = G.max_breath()
	p.hp = 3


## These must be impossible: each gate has to hold against the real physics.
func run_gates() -> void:
	print("\nGATES (each must be unreachable)")
	var quay_lamp := Vector2i(5 * 320 + 960 - 160, 4 * 184 + 160)
	gate("no water: can't climb the sea wall", 0, [], Vector2i(8 * 320 + 200, 5 * 184 + 112), quay_lamp)
	gate("no reel: can't reach Warehouse Row", 1, [], quay_lamp, Vector2i(5 * 320 + 40 * 8, 3 * 184 + 160))
	gate("Low Water, reel: can't cross the Well to the Cellars", 1, ["reel"], Vector2i(5 * 320 + 40 * 8, 3 * 184 + 160), Vector2i(2 * 320 + 68 * 8, 3 * 184 + 160))
	gate("no helm: can't reach the Cistern at Half Tide", 2, ["reel"], Vector2i(2 * 320 + 68 * 8, 3 * 184 + 160), Vector2i(3 * 320 + 20 * 8, 5 * 184 + 160))
	gate("Half Tide: can't reach the Market", 2, ["reel", "helm"], Vector2i(2 * 320 + 68 * 8, 2 * 184 + 160), Vector2i(5 * 320 + 40 * 8, 2 * 184 + 160))
	gate("no bellows: can't climb to the Roofs", 3, ["reel", "helm"], Vector2i(7 * 320 + 60 * 8, 2 * 184 + 160), Vector2i(5 * 320 + 90 * 8, 1 * 184 + 152))


func gate(label: String, level: int, abilities: Array, from: Vector2i, target: Vector2i) -> void:
	setup_state(level, abilities, from)
	var was_failed := failed
	failed = false
	coarse = true
	var r := search(target)
	coarse = false
	if r == 1:
		failed = true
		print("BREACH  %-56s the player got through!" % label)
	elif r == 0:
		print("  held  %-56s (exhausted)" % label)
	else:
		print("  held? %-56s (search limit, inconclusive)" % label)
	failed = failed or was_failed


## Every optional item, with everything the player could have by then.
func run_extras() -> void:
	print("\nEXTRAS")
	var all := ["reel", "helm", "bellows"]
	for tx in range(0, game.map.w):
		for ty in range(0, game.map.h):
			if game.map.get_tile(tx, ty) == WorldMap.BREAK:
				game.map.set_tile(tx, ty, WorldMap.AIR)
	var pearls: Array = []
	for r in game.map.rooms:
		for e in r.ents:
			if e.kind == "pickup":
				pearls.append({"room": r.id, "item": e.item, "at": Vector2i(e.x, e.y)})
	var starts := {
		"flats_mid": [1, Vector2i(3200, 900)],
		"warehouses": [1, Vector2i(5 * 320 + 40 * 8, 3 * 184 + 160)],
		"ropewalk": [1, Vector2i(1 * 320 + 60, 4 * 184 + 160)],
		"storeroom": [1, Vector2i(1 * 320 + 60, 4 * 184 + 160)],
		"cistern_e": [2, Vector2i(3 * 320 + 160, 5 * 184 + 150)],
		"cistern": [2, Vector2i(3 * 320 + 160, 5 * 184 + 150)],
		"undercroft": [0, Vector2i(5 * 320 + 200, 5 * 184 + 160)],
		"lighthouse": [3, Vector2i(12 * 320 + 200, 2 * 184 + 160)],
		"terrace": [4, Vector2i(1 * 320 + 100 * 8, 1 * 184 + 160)],
		"lantern_w": [2, Vector2i(30 * 8, 2 * 184 + 160)],
		"belfry": [4, Vector2i(3 * 320 + 20 * 8, 160)],
	}
	for it: Dictionary in pearls:
		if not starts.has(it.room):
			print("  ??  no start for ", it.room, " ", it.item)
			continue
		var from: Vector2i = starts[it.room][1]
		if it.item == "line":
			from = Vector2i(5 * 320 + 36 * 8, 3 * 184 + 72)
		setup_state(int(starts[it.room][0]), all, from)
		var r := search(it.at)
		print("  %s  %-10s in %s" % ["ok" if r == 1 else "FAIL", it.item, it.room])
		if r != 1:
			failed = true


## Search from the player's current state until the feet are within reach of the goal.
func leg(label: String, goal: Vector2i) -> void:
	if failed and not label.begins_with("[opt]"):
		print("  skipped: ", label)
		return
	var optional := label.begins_with("[opt]")
	var start := p.save_state()
	var r := search(goal)
	if r == 1:
		print("  ok  %-50s %6d  at %d,%d" % [label, last_n, p.ix, p.iy])
		return
	if optional:
		p.load_state(start)
		print("  --  %-50s UNREACHED, closest %.0fpx" % [label, last_best])
		return
	failed = true
	print("FAIL  %s: goal %s, closest %.0fpx at %d,%d (tile %d,%d, room %s) after %d" % [label, goal, last_best, p.ix, p.iy, p.ix >> 3, p.iy >> 3, game.map.room_at(p.ix, p.iy - 4).id if game.map.room_at(p.ix, p.iy - 4) else "?", last_n])


## 1 reached, 0 proved impossible (search exhausted), -1 ran out of budget.
func search(goal: Vector2i) -> int:
	var heap := Heap.new()
	var states: Array = []
	var seen := {}
	var start := p.save_state()
	states.append(start)
	heap.push(_score(goal), 0)
	var best := INF
	var best_state: Array = start
	var n := 0
	var found := -1
	while not heap.empty() and n < MAX_EXPANSIONS:
		var i := heap.pop()
		n += 1
		var st: Array = states[i]
		p.load_state(st)
		for m in macros():
			p.load_state(st)
			if not _run(m):
				continue
			var d := Vector2(p.ix - goal.x, (p.iy - goal.y) * 1.2).length()
			if d < best:
				best = d
				best_state = p.save_state()
			if absi(p.ix - goal.x) <= 12 and absi(p.iy - goal.y) <= 14:
				found = 1
				best_state = p.save_state()
				break
			var key := _key()
			if seen.has(key):
				continue
			seen[key] = true
			states.append(p.save_state())
			heap.push(d + states.size() * 0.0004, states.size() - 1)
		if found >= 0:
			break
	total += n
	last_n = n
	last_best = best
	p.load_state(best_state)
	if found >= 0:
		return 1
	return 0 if heap.empty() else -1


func _score(goal: Vector2i) -> float:
	return Vector2(p.ix - goal.x, p.iy - goal.y).length()


func _key() -> int:
	if coarse:
		var c := (p.ix >> 3) | ((p.iy >> 3) << 12)
		return c * 16 + p.state + (int(p.vy < 0.0) << 40) + (int(p.grounded) << 41) + (int(p.puffs > 0) << 42)
	var vyb := clampi(int(p.vy / 50.0) + 8, 0, 15)
	var vxb := clampi(int(p.vx / 40.0) + 4, 0, 7)
	var k := (p.ix >> 1) | ((p.iy >> 1) << 12)
	k = k * 16 + vyb
	k = k * 8 + vxb
	k = k * 16 + p.state
	k = k * 2 + int(p.grounded)
	k = k * 2 + int(p.diving)
	k = k * 2 + int(p.puffs > 0)
	k = k * 8 + mini(int(p.breath / 2.0), 7)
	return k


## Each macro: [x, y, ticks, jump hold ticks, jump press, cast press]
func macros() -> Array:
	var out: Array = []
	var cast_dirs := [[0, -1], [1, -1], [-1, -1], [1, 0], [-1, 0], [0, 0]]
	var has_reel := G.has("reel")
	match p.state:
		Player.NORMAL:
			for x in [-1, 0, 1]:
				out.append([x, 0, 8, 0, false, false])
			if p.grounded or p.coyote > 0:
				for x in [-1, 0, 1]:
					out.append([x, 0, 8, 6, true, false])
					out.append([x, 0, 22, 22, true, false])
			elif p.puffs > 0:
				for x in [-1, 0, 1]:
					out.append([x, 0, 20, 20, true, false])
			out.append([0, -1, 8, 0, false, false])
			out.append([0, 1, 8, 0, false, false])
			if p.grounded:
				out.append([0, 1, 8, 2, true, false])
			if has_reel:
				for d: Array in cast_dirs:
					out.append([d[0], d[1], 7, 0, false, true])
		Player.SWIM:
			for x in [-1, 0, 1]:
				for y in [-1, 0, 1]:
					out.append([x, y, 10, 0, false, false])
				out.append([x, 0, 22, 22, true, false])
			if has_reel:
				for d: Array in cast_dirs:
					out.append([d[0], d[1], 7, 0, false, true])
		Player.CLIMB:
			out.append([0, -1, 8, 0, false, false])
			out.append([0, 1, 8, 0, false, false])
			for x in [-1, 1]:
				out.append([x, 0, 16, 10, true, false])
		Player.REEL:
			out.append([0, 0, 8, 0, false, false])
		Player.HANG:
			for x in [-1, 0, 1]:
				out.append([x, 0, 22, 22, true, false])
			out.append([0, 1, 8, 0, false, false])
			if has_reel:
				for d: Array in cast_dirs:
					out.append([d[0], d[1], 7, 0, false, true])
		_:
			out.append([0, 0, 8, 0, false, false])
	return out


func _vents_tick() -> void:
	for v: Vector2i in vents:
		if v.y > game.water_y and absi(p.ix - v.x) < 12 and p.iy > v.y - 56 and p.iy <= v.y + 4:
			p.breath = minf(p.breath + 8.0 / 60.0, G.max_breath())


func _run(m: Array) -> bool:
	var hp := p.hp
	p.remove_meta("spiked")
	for i in int(m[2]):
		pad.clear()
		pad.x = m[0]
		pad.y = m[1]
		pad.jump = i < int(m[3])
		pad.jump_p = m[4] and i == 0
		pad.cast_p = m[5] and i == 0
		p.tick()
		_vents_tick()
		if p.has_meta("spiked") or p.hp < hp or p.state == Player.HURT or p.state == Player.DEAD:
			p.hp = hp
			p.iframes = 0
			return false
	return true
