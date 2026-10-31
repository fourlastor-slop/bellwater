class_name Hud
extends CanvasLayer
## Health, breath, banners, dialogue, the boss bar, the tuning fork menu and the screen fade.

var game: Game
var canvas: Node2D
var heart: Texture2D
var bubble: Texture2D
var hidden := false

var banner := ""
var banner_t := 0
var area := ""
var area_t := 0
var note := ""
var note_t := 0

var dlg_pages: Array[PackedStringArray] = []
var dlg_page := 0
var dlg_chars := 0
var dlg_done: Callable
var dlg_cool := 0


func setup(g: Game) -> void:
	game = g
	layer = 10
	heart = load("res://assets/gfx/ui_heart.png")
	bubble = load("res://assets/gfx/ui_bubble.png")
	canvas = Node2D.new()
	add_child(canvas)
	canvas.draw.connect(_paint)


func show_banner(text: String) -> void:
	banner = text
	banner_t = 170


func show_area(text: String) -> void:
	if text == area and area_t > 0:
		return
	if game.ticks < 5:
		return
	area = text
	area_t = 150


func show_note(text: String) -> void:
	note = text
	note_t = 150


func dialog_active() -> bool:
	return not dlg_pages.is_empty()


## Show text in the box at the bottom. Pages split on a blank line.
func say(text: String, done := Callable()) -> void:
	if game.sim:
		if done.is_valid():
			done.call()
		return
	dlg_pages.clear()
	for page in text.split("\n\n"):
		dlg_pages.append(PixelFont.wrap(page, 288))
	dlg_page = 0
	dlg_chars = 0
	dlg_done = done
	dlg_cool = 14


func dialog_input(p: Pad) -> void:
	if dlg_cool > 0:
		dlg_cool -= 1
	var total := 0
	for l in dlg_pages[dlg_page]:
		total += l.length()
	if dlg_chars < total:
		dlg_chars += 1
		if game.ticks % 3 == 0:
			game.snd("text")
	var press := p.jump_p or p.attack_p or p.interact_p
	if not press or dlg_cool > 0:
		return
	if dlg_chars < total:
		dlg_chars = total
		return
	dlg_cool = 8
	dlg_page += 1
	dlg_chars = 0
	if dlg_page >= dlg_pages.size():
		dlg_pages.clear()
		if dlg_done.is_valid():
			var f := dlg_done
			dlg_done = Callable()
			f.call()


func tick() -> void:
	banner_t = maxi(banner_t - 1, 0)
	area_t = maxi(area_t - 1, 0)
	note_t = maxi(note_t - 1, 0)


func sync() -> void:
	canvas.queue_redraw()


func _paint() -> void:
	var ci := canvas
	var p := game.player
	if not hidden:
		_paint_health(ci, p)
		_paint_breath(ci, p)
		_paint_prompt(ci)
		_paint_ring_hint(ci, p)
		_paint_boss(ci)
		_paint_texts(ci)
		if game.fork_menu:
			_paint_fork(ci)
		if dialog_active():
			_paint_dialog(ci)
	if game.fade > 0.0:
		ci.draw_rect(Rect2(0, 0, G.VIEW_W, G.VIEW_H), Color(0.05, 0.05, 0.09, game.fade))


func _paint_health(ci: CanvasItem, p: Player) -> void:
	for i in int(G.s.max_hp):
		var src := Rect2(0 if i < p.hp else 8, 0, 8, 8)
		ci.draw_texture_rect_region(heart, Rect2(6 + i * 10, 6, 8, 8), src)


func _paint_breath(ci: CanvasItem, p: Player) -> void:
	var maxb := G.max_breath()
	if p.breath >= maxb - 0.01:
		return
	var n := int(ceilf(maxb / 2.0))
	var full := int(ceilf(p.breath / 2.0))
	for i in n:
		var src := Rect2(0 if i < full else 5, 0, 5, 5)
		ci.draw_texture_rect_region(bubble, Rect2(7 + i * 7, 17, 5, 5), src)


func _paint_prompt(ci: CanvasItem) -> void:
	var e := game.nearby_interact()
	if e == null or game.player.state in [Player.RINGING, Player.DEAD]:
		return
	var pt := e.interact_point() - game.cam
	var bob := roundf(sin(game.ticks * 0.12) * 1.5)
	var pr := e.prompt()
	var c := Vector2(roundf(pt.x), roundf(pt.y) - 24 + bob)
	ci.draw_rect(Rect2(c.x, c.y, 1, 1), Color.WHITE)
	ci.draw_rect(Rect2(c.x - 1, c.y + 1, 3, 1), Color.WHITE)
	ci.draw_rect(Rect2(c.x - 2, c.y + 2, 5, 1), Color.WHITE)
	if pr != "":
		PixelFont.centered(ci, c.y - 10, pr, Color.WHITE, Color(0, 0, 0, 0.8), c.x)


## With the Reel in hand, mark the ring a cast would take right now.
func _paint_ring_hint(ci: CanvasItem, p: Player) -> void:
	if not G.has("reel") or p.state == Player.REEL:
		return
	var ring := p.best_ring(p.aim_vector())
	if ring == Vector2i.ZERO:
		return
	var c := (Vector2(ring) - game.cam).round()
	var col := Color("f7d154") if game.ticks / 8 % 2 == 0 else Color("efe6d0")
	for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		ci.draw_rect(Rect2(c + s * 6.0 - Vector2.ONE * 0.5, Vector2(2, 2)), col)


func _paint_boss(ci: CanvasItem) -> void:
	var b: Variant = game.boss
	if b == null or not is_instance_valid(b):
		return
	if b.dead or b.hp <= 0:
		return
	var w := 180
	var x := (G.VIEW_W - w) / 2
	var y := 168
	PixelFont.centered(ci, y - 11, b.boss_name, Color("efe6d0"), Color(0, 0, 0, 0.8))
	ci.draw_rect(Rect2(x - 1, y - 1, w + 2, 6), Color("141826"))
	ci.draw_rect(Rect2(x, y, w, 4), Color("2a2f45"))
	ci.draw_rect(Rect2(x, y, int(w * clampf(float(b.hp) / b.max_hp, 0.0, 1.0)), 4), Color("e8514a"))


func _paint_texts(ci: CanvasItem) -> void:
	if banner_t > 0:
		var a := minf(minf(banner_t / 30.0, (170 - banner_t) / 20.0), 1.0)
		var w := PixelFont.width(banner) + 24
		ci.draw_rect(Rect2((G.VIEW_W - w) / 2.0, 34, w, 15), Color(0.05, 0.08, 0.12, 0.6 * a))
		PixelFont.centered(ci, 38, banner, Color(1, 0.95, 0.8, a))
	if area_t > 0:
		var a := minf(minf(area_t / 30.0, (150 - area_t) / 20.0), 1.0)
		PixelFont.draw(ci, Vector2(10, 164), area, Color(0.94, 0.9, 0.82, a), Color(0, 0, 0, 0.7 * a))
	if note_t > 0:
		var a := minf(note_t / 30.0, 1.0)
		PixelFont.centered(ci, 150, note, Color(0.94, 0.9, 0.82, a), Color(0, 0, 0, 0.7 * a))


func _paint_dialog(ci: CanvasItem) -> void:
	var lines: PackedStringArray = dlg_pages[dlg_page]
	var h := lines.size() * PixelFont.LINE + 10
	var y := G.VIEW_H - h - 6
	ci.draw_rect(Rect2(8, y, 304, h), Color(0.04, 0.05, 0.1, 0.92))
	ci.draw_rect(Rect2(8, y, 304, 1), Color("c98a3a"))
	ci.draw_rect(Rect2(8, y + h - 1, 304, 1), Color("c98a3a"))
	var left := dlg_chars
	for i in lines.size():
		var l: String = lines[i]
		PixelFont.draw(ci, Vector2(16, y + 5 + i * PixelFont.LINE), l.substr(0, maxi(left, 0)), Color("efe6d0"))
		left -= l.length()
	if left >= 0 and game.ticks / 20 % 2 == 0:
		ci.draw_rect(Rect2(302, y + h - 7, 3, 3), Color("f7d154"))


func _paint_fork(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, G.VIEW_W, G.VIEW_H), Color(0.03, 0.05, 0.1, 0.55))
	var x := 112
	var y := 26
	PixelFont.centered(ci, y - 12, "CALL THE SEA", Color("f7d154"), Color(0, 0, 0, 0.8))
	var row := 0
	for lv in range(5, -1, -1):
		if not G.s.rung.has(str(lv)):
			continue
		var yy := y + 6 + row * 14
		var here := lv == int(G.s.level)
		var sel := lv == game.fork_sel
		var col := Color("f7d154") if sel else Color("efe6d0")
		if sel:
			ci.draw_rect(Rect2(x - 12, yy + 1, 4, 5), Color("f7d154"))
		PixelFont.draw(ci, Vector2(x, yy), G.TIDE_NAMES[lv] + ("  (here)" if here else ""), col, Color(0, 0, 0, 0.8))
		row += 1
