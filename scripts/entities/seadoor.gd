extends Ent
## A heavy sea door. It opens only when the tide is below its sill: the sea leans on it otherwise.
## The door itself is the block of DOOR tiles touching this marker.

var cells: Array[Vector2i] = []
var opening := 0


func begin() -> void:
	solid_body = false
	var tx: int = props.tx
	var ty: int = props.ty
	var seen := {}
	var todo: Array[Vector2i] = [Vector2i(tx, ty)]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if seen.has(n):
				continue
			seen[n] = true
			if game.map.get_tile(n.x, n.y) == WorldMap.DOOR:
				cells.append(n)
				todo.append(n)


func interactive() -> bool:
	return not cells.is_empty() and opening == 0


func prompt() -> String:
	return tr("open")


func interact() -> void:
	var sill := 0
	for c in cells:
		sill = maxi(sill, (c.y + 1) * 8)
	if props.has("flags"):
		var missing := 0
		for f: String in str(props.flags).split(","):
			if not G.flag(f):
				missing += 1
		if missing > 0:
			game.snd("clink")
			game.hud.say(tr("Three great locks, and %d of them still shut. Each one holds until the creature that keeps a Great Bell is gone.") % missing)
			return
	if game.water_y < sill - 2:
		game.snd("clink")
		game.hud.say(tr("The door will not move. The whole sea is leaning on it."))
		return
	if props.has("needs") and not G.has(str(props.needs)):
		game.snd("clink")
		game.hud.say(tr("An iron ring on a door too heavy to shift by hand. It wants a good line and a strong reel."))
		return
	opening = 1
	for c in cells:
		G.s.opened["%d,%d" % [c.x, c.y]] = true
	game.snd("door")
	game.shake = maxf(game.shake, 2.0)


func tick() -> void:
	if opening == 0:
		return
	opening += 1
	if opening % 5 == 0 and not cells.is_empty():
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y)
		var c: Vector2i = cells.pop_front()
		game._remove_tile(c.x, c.y)
		game.fx_burst(c.x * 8 + 4, c.y * 8 + 4, Color("8a93a6"), 3)
		game.snd("clink")
