extends Ent
## Hangs on the wind, then dives at you in a line.

enum { HOVER, WINDUP, DIVE, RETURN }

var state := HOVER
var home := Vector2.ZERO
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var timer := 0
var face := -1


func begin() -> void:
	hp = 2
	hw = 7
	hh = 9
	home = Vector2(x, y)
	pos = home
	timer = 60
	sprite = make_sprite("res://assets/gfx/gull.png", 3)


func body_rect() -> Rect2i:
	return Rect2i(x - hw, y - hh, hw * 2, hh)


func tick() -> void:
	t += 1
	var p := game.player
	var target := p.center()
	var hover_y := minf(home.y, game.water_y - 22.0)
	match state:
		HOVER:
			pos = pos.lerp(Vector2(home.x + sin(t * 0.02) * 18.0, hover_y + sin(t * 0.05) * 5.0), 0.04)
			face = 1 if target.x > pos.x else -1
			timer -= 1
			if timer <= 0 and pos.distance_to(target) < 120.0:
				state = WINDUP
				timer = 26
				game.snd("gull")
		WINDUP:
			pos.y -= 0.5
			timer -= 1
			if timer <= 0:
				state = DIVE
				vel = (target - pos).normalized() * 165.0
				timer = 46
		DIVE:
			pos += vel / 60.0
			timer -= 1
			if timer <= 0 or tile_block(int(pos.x), int(pos.y)) or pos.y > game.water_y - 4.0:
				state = RETURN
		RETURN:
			var d := Vector2(home.x, hover_y) - pos
			pos += d.normalized() * minf(84.0 / 60.0, d.length())
			face = 1 if d.x > 0 else -1
			if d.length() < 3.0:
				state = HOVER
				timer = 90
	x = int(pos.x)
	y = int(pos.y)


func render() -> void:
	super()
	sprite.flip_h = face < 0
	sprite.frame = 1 if state == DIVE else (t / 9) % 3
