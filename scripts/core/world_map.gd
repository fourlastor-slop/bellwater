class_name WorldMap
extends RefCounted
## The whole world as one tile grid, built from the ASCII rooms in data/rooms.
## Pure data: no nodes, so tests can use it without any rendering.

enum { AIR, SOLID, ONEWAY, SPIKE, SAND, BREAK, LADDER, DOOR }

const THEMES: Array[String] = ["sand", "quay", "town", "roof", "cistern", "belfry", "sump", "wood"]
const ROOM_DIR := "res://data/rooms/"

## Characters that always mean the same entity.
const ENT_CHARS := {
	"L": "lamp", "C": "crab", "G": "gull", "F": "fish", "J": "jelly",
	"Y": "hopper", "A": "barnacle", "V": "vent", "E": "eel", "Z": "husk",
}


class Room:
	var id := ""
	var cx := 0
	var cy := 0
	var cw := 1
	var ch := 1
	var title := ""
	var theme := 0
	var alt := -1
	var bg := "sky"
	var music := "dry"
	var dark := 0.0
	var ents: Array[Dictionary] = []
	var rect := Rect2i()


var w := 0
var h := 0
var tiles := PackedByteArray()
var themes := PackedByteArray()
var back := PackedByteArray()
var rooms: Array[Room] = []
var by_id := {}
var cells := {}
var rings: Array[Vector2i] = []
var sand_cells: Array[Vector2i] = []
var sand_bottom := -1


func _init() -> void:
	var specs: Array[Dictionary] = []
	var files := DirAccess.get_files_at(ROOM_DIR)
	var max_c := 0
	var max_r := 0
	for f in files:
		if not f.ends_with(".txt"):
			continue
		var spec := _parse(ROOM_DIR + f)
		specs.append(spec)
		var r: Room = spec.room
		max_c = maxi(max_c, r.cx + r.cw)
		max_r = maxi(max_r, r.cy + r.ch)
	w = max_c * G.CELL_W
	h = max_r * G.CELL_H
	tiles.resize(w * h)
	tiles.fill(SOLID)
	themes.resize(w * h)
	back.resize(w * h)
	for spec in specs:
		_stamp(spec)


func index(tx: int, ty: int) -> int:
	return ty * w + tx


func get_tile(tx: int, ty: int) -> int:
	if tx < 0 or ty < 0 or tx >= w or ty >= h:
		return SOLID
	return tiles[ty * w + tx]


func set_tile(tx: int, ty: int, v: int) -> void:
	tiles[ty * w + tx] = v


func is_block(t: int) -> bool:
	return t == SOLID or t == SAND or t == BREAK or t == DOOR


func solid_at(tx: int, ty: int) -> bool:
	return is_block(get_tile(tx, ty))


func room_at(px: int, py: int) -> Room:
	var key := Vector2i(floori(float(px) / (G.CELL_W * G.TILE)), floori(float(py) / (G.CELL_H * G.TILE)))
	return cells.get(key, null)


func _parse(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "cannot open " + path)
	var r := Room.new()
	var legend := {}
	var rows: PackedStringArray = []
	var in_rows := false
	while not f.eof_reached():
		var line := f.get_line()
		if not in_rows:
			if line.strip_edges() == "---":
				in_rows = true
				continue
			var c := line.find(":")
			if c < 0:
				continue
			var key := line.substr(0, c).strip_edges()
			var val := line.substr(c + 1).strip_edges()
			match key:
				"id": r.id = val
				"at":
					var p := val.split(" ", false)
					r.cx = int(p[0])
					r.cy = int(p[1])
				"size":
					var p := val.split(" ", false)
					r.cw = int(p[0])
					r.ch = int(p[1])
				"name": r.title = val
				"theme": r.theme = THEMES.find(val)
				"alt": r.alt = THEMES.find(val)
				"bg": r.bg = val
				"music": r.music = val
				"dark": r.dark = float(val)
				"legend":
					var e := val.find("=")
					legend[val.substr(0, e).strip_edges()] = _parse_props(val.substr(e + 1).strip_edges())
		else:
			if line.strip_edges() == "---":
				break
			if line.begins_with("@blank"):
				for i in int(line.substr(6).strip_edges()):
					rows.append("")
				continue
			rows.append(line)
	r.rect = Rect2i(r.cx * G.CELL_W * G.TILE, r.cy * G.CELL_H * G.TILE, r.cw * G.CELL_W * G.TILE, r.ch * G.CELL_H * G.TILE)
	rooms.append(r)
	by_id[r.id] = r
	for cy in r.ch:
		for cx in r.cw:
			cells[Vector2i(r.cx + cx, r.cy + cy)] = r
	return {"room": r, "rows": rows, "legend": legend}


## Turn `crab hp=2 text="two words"` into {kind: crab, hp: 2, text: "two words"}.
func _parse_props(s: String) -> Dictionary:
	var out := {}
	var i := 0
	var first := true
	while i < s.length():
		while i < s.length() and s[i] == " ":
			i += 1
		if i >= s.length():
			break
		var start := i
		while i < s.length() and s[i] != " " and s[i] != "=":
			i += 1
		var key := s.substr(start, i - start)
		if i < s.length() and s[i] == "=":
			i += 1
			var val := ""
			if i < s.length() and s[i] == "\"":
				i += 1
				var e := s.find("\"", i)
				val = s.substr(i, e - i).replace("\\n", "\n")
				i = e + 1
			else:
				var st := i
				while i < s.length() and s[i] != " ":
					i += 1
				val = s.substr(st, i - st)
			out[key] = val
		elif first:
			out["kind"] = key
		else:
			out[key] = true
		first = false
	return out


func _stamp(spec: Dictionary) -> void:
	var r: Room = spec.room
	var rows: PackedStringArray = spec.rows
	var legend: Dictionary = spec.legend
	var tw := r.cw * G.CELL_W
	var th := r.ch * G.CELL_H
	var x0 := r.cx * G.CELL_W
	var y0 := r.cy * G.CELL_H
	for y in th:
		var row: String = rows[y] if y < rows.size() else ""
		for x in tw:
			var c: String = row[x] if x < row.length() else "."
			var i := index(x0 + x, y0 + y)
			var t := AIR
			var b := 1 if r.bg == "wall" else 0
			var th_id := r.theme
			match c:
				"#":
					t = SOLID
				"$":
					t = SOLID
					th_id = r.alt if r.alt >= 0 else r.theme
				"=":
					t = ONEWAY
				"H":
					t = LADDER
				"^":
					t = SPIKE
				"s":
					t = SAND
					sand_cells.append(Vector2i(x0 + x, y0 + y))
				"%":
					t = BREAK
				"D":
					t = DOOR
				":":
					b = 1
				",":
					b = 2
				"R":
					rings.append(Vector2i((x0 + x) * G.TILE + 4, (y0 + y) * G.TILE + 4))
				".":
					pass
				_:
					var props := {}
					if legend.has(c):
						props = legend[c].duplicate()
					elif ENT_CHARS.has(c):
						props = {"kind": ENT_CHARS[c]}
					else:
						push_error("room %s: unknown char '%s' at %d,%d" % [r.id, c, x, y])
						continue
					props["x"] = (x0 + x) * G.TILE + 4
					props["y"] = (y0 + y) * G.TILE + 8
					props["tx"] = x0 + x
					props["ty"] = y0 + y
					r.ents.append(props)
			tiles[i] = t
			themes[i] = th_id
			back[i] = b
	# entity tiles inherit a neighbouring back wall in outdoor rooms
	if r.bg != "wall":
		for e in r.ents:
			var tx: int = e.tx
			var ty: int = e.ty
			for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var bb := back[index(tx + d.x, ty + d.y)]
				if bb != 0:
					back[index(tx, ty)] = bb
					break
