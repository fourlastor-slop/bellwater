extends Ent
## A snapper. Patrols under the surface and leaps at swimmers. Stranded, it can only flop.

var home := Vector2.ZERO
var pos := Vector2.ZERO
var vy := 0.0
var leaping := false
var face := 1


func begin() -> void:
	hp = 2
	hw = 6
	hh = 7
	home = Vector2(x, y)
	pos = home
	sprite = make_sprite("res://assets/gfx/fish.png", 2)


func tick() -> void:
	t += 1
	var p := game.player
	var w := game.water_y
	if pos.y < w - 1.0 and not leaping:
		# out of the water: fall, then flop
		if tile_block(int(pos.x), int(pos.y) + 1):
			contact = 0
			if t % 30 == 0:
				pos.y -= 3.0
		else:
			pos.y += 2.0
	elif leaping:
		vy += 9.0
		pos.y += vy / 60.0
		pos.x += face * 0.7
		if pos.y > w + 8.0 and vy > 0.0:
			leaping = false
			game.fx_splash(int(pos.x), int(w), 60.0)
	else:
		contact = 1
		var depth := minf(maxf(home.y, w + 10.0), w + 90.0) if home.y > w + 10.0 else w + 10.0
		var chase := p.center().distance_to(pos) < 80.0 and p.state == Player.SWIM
		var goal := Vector2(home.x + sin(t * 0.012 + home.x) * 40.0, depth)
		if chase:
			goal = p.center()
		var d := goal - pos
		pos += d.normalized() * minf((48.0 if chase else 26.0) / 60.0, d.length())
		if absf(d.x) > 1.0:
			face = 1 if d.x > 0 else -1
		if p.state == Player.SWIM and not p.diving and absf(p.center().x - pos.x) < 34.0 and pos.y - w < 44.0 and t % 70 == 0:
			leaping = true
			vy = -210.0
			face = 1 if p.ix > pos.x else -1
			game.fx_splash(int(pos.x), int(w), 60.0)
	if tile_block(int(pos.x), int(pos.y)):
		pos.y -= 1.0
	x = int(pos.x)
	y = int(pos.y)


func render() -> void:
	super()
	sprite.flip_h = face < 0
	sprite.frame = (t / 14) % 2
