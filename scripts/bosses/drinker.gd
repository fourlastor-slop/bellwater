extends Boss
## The Drinker: the mouth at the bottom of the Well, and the reason the sea left.
## It pulls you in, spits, and tires, and then its tongue can be cut.
## Wounded, it brings up the sea and the flood lifts you to its eye, the only way to reach it.

enum { DORMANT, SUCK, SPIT, TONGUE, FLOOD, DRAIN }

const EYE_DAMAGE := 3

var state := DORMANT
var timer := 0
var mouth: Sprite2D
var tongue_tex: Texture2D
var tongue_len := 0.0
var open_k := 0
var mouth_x := 0
var mouth_y := 0
var eye := Rect2i()
var floods := 0
var eye_cd := 0
var volley := 0


func should_spawn() -> bool:
	return not G.flag("drinker_dead")


func begin() -> void:
	boss_name = "THE DRINKER"
	max_hp = 22
	hp = max_hp
	hw = 8
	hh = 10
	contact = 0
	hittable = false
	var r := game.room.rect
	mouth = Sprite2D.new()
	mouth.texture = load("res://assets/gfx/drinker.png")
	mouth.hframes = 3
	mouth.centered = false
	add_child(mouth)
	sprite = mouth
	position = Vector2(r.end.x - 108, r.end.y - 152)
	mouth_x = int(position.x) + 28
	mouth_y = int(position.y) + 72
	eye = Rect2i(int(position.x) + 34, int(position.y) + 12, 30, 24)
	x = mouth_x
	y = r.end.y - 24
	tongue_tex = load("res://assets/gfx/drinker_tongue.png")


func tick() -> void:
	t += 1
	timer -= 1
	eye_cd = maxi(eye_cd - 1, 0)
	if dying > 0:
		_die_tick()
		return
	var p := game.player
	match state:
		DORMANT:
			if p.ix > game.room.rect.position.x + 40:
				start_fight()
				var tx := game.room.rect.position.x >> 3
				var ty := game.room.rect.position.y >> 3
				game.lock_area(tx, ty + 14, tx, ty + 19)
				game.hud.show_banner(boss_name)
				_to_suck()
		SUCK:
			open_k = 2
			if p.state in [Player.NORMAL, Player.SWIM] and timer < 170:
				var pull := 1.15 if hp < max_hp / 2 else 0.95
				p.move_x(pull)
				if t % 4 == 0:
					game.fx.add(p.ix - 60 + randf_range(-20, 20), p.iy - randf_range(0, 50), 160.0, 0, 40, Color(0.8, 0.9, 0.9, 0.5))
			if p.ix > mouth_x - 16 and absi(p.iy - 10 - mouth_y) < 50:
				p.hurt(1, mouth_x + 60)
			if timer <= 0:
				state = SPIT
				timer = 30
				volley = 3
				open_k = 1
		SPIT:
			if timer <= 0:
				volley -= 1
				_spit()
				timer = 26
				if volley <= 0:
					state = TONGUE
					timer = 190
					game.snd("roar")
		TONGUE:
			open_k = 1
			tongue_len = move_toward(tongue_len, 108.0 if timer > 24 else 0.0, 3.0)
			x = mouth_x - int(tongue_len)
			hw = 10
			hittable = tongue_len > 30.0
			contact = 1 if tongue_len > 30.0 and timer > 170 else 0
			if timer <= 0:
				hittable = false
				tongue_len = 0.0
				if floods < 2 and hp <= max_hp - (floods + 1) * max_hp / 3:
					_start_flood()
				else:
					_to_suck()
		FLOOD:
			open_k = 0
			if t % 80 == 0:
				_spit()
			_eye_hits(p)
			if timer <= 0:
				state = DRAIN
				game.water_target = G.tide_px(0)
				game.tide_moving = true
				game.tide_ticks = 0
		DRAIN:
			_eye_hits(p)
			if not game.tide_moving or game.water_y > game.room.rect.end.y + 8.0:
				_to_suck()


func _to_suck() -> void:
	state = SUCK
	timer = 200
	game.snd("drink")


func _spit() -> void:
	game.snd("spit")
	for i in 3:
		var s: Ent = game.spawn({"kind": "shot", "x": mouth_x - 10, "y": mouth_y + 10})
		if s != null:
			var a := game.player.center() - Vector2(mouth_x - 10, mouth_y)
			s.vel = a.normalized().rotated((i - 1) * 0.26) * 96.0


func _start_flood() -> void:
	floods += 1
	state = FLOOD
	timer = 420
	game.snd("roar")
	game.shake = maxf(game.shake, 5.0)
	game.tide_speed = 90.0
	game.water_target = float(eye.position.y + 20)
	game.tide_moving = true
	game.tide_ticks = 0
	game.hud.show_banner("IT BRINGS UP THE SEA")


## The hook reaches the eye only from the top of the flood.
func _eye_hits(p: Player) -> void:
	if eye_cd > 0 or not p.attacking():
		return
	if p.attack_rect().intersects(eye):
		eye_cd = 18
		take_hit(EYE_DAMAGE, Vector2i.ZERO)


func on_cast(_aim: Vector2) -> void:
	if state == TONGUE:
		take_hit(1, Vector2i.ZERO)


func _die_tick() -> void:
	dying += 1
	open_k = 2
	if dying % 6 == 0:
		game.fx_burst(mouth_x + randi_range(-30, 30), mouth_y + randi_range(-50, 50), Color("c86a8a"), 8)
	game.shake = maxf(game.shake, 3.0)
	if dying == 120:
		reveal("drinker_dead")
		game.boss = null
		game.locked_room = false
		game.unlock_all()
		game.begin_return()
		dead = true


func render() -> void:
	mouth.frame = open_k
	mouth.modulate = Color(3, 3, 3) if flash > 0 else Color.WHITE
	if flash > 0:
		flash -= 1
	queue_redraw()


func _draw() -> void:
	if tongue_len <= 0.0:
		return
	var n := int(tongue_len / 11.0)
	var base := Vector2(mouth_x, y - 7) - position
	for i in n:
		draw_texture(tongue_tex, (base + Vector2(-11.0 * i - 8.0, sin(t * 0.2 + i) * 1.5)).round())
