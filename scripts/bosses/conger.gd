extends Boss
## The Conger: as long as a street, and the cistern has been its whole world.
## Fought under water. It prowls, it lunges, and it hides in the wall to come at you again.

enum { DORMANT, PROWL, AIM, LUNGE, SLUMP, HIDE }

const SEGMENTS := 16
const SPACING := 7

var state := DORMANT
var timer := 0
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var aim := Vector2.ZERO
var trail: Array[Vector2] = []
var head: Sprite2D
var seg_tex: Texture2D
var lunges := 0
var bounds := Rect2()


func should_spawn() -> bool:
	if G.flag("conger_dead"):
		return false
	if game.water_y > game.room.rect.position.y + 24.0:
		return false
	return true


func begin() -> void:
	boss_name = "THE CONGER"
	max_hp = 18
	hp = max_hp
	hw = 12
	hh = 16
	contact = 0
	hittable = false
	var r := game.room.rect
	bounds = Rect2(r.position.x + 44, r.position.y + 40, r.size.x - 88, r.size.y - 76)
	pos = Vector2(r.position.x + 20, r.position.y + 100)
	for i in SEGMENTS * SPACING + 2:
		trail.append(pos)
	head = Sprite2D.new()
	head.texture = load("res://assets/gfx/conger_head.png")
	add_child(head)
	sprite = head
	seg_tex = load("res://assets/gfx/conger_seg.png")
	visible = false


func tick() -> void:
	t += 1
	timer -= 1
	if dying > 0:
		_die_tick()
		return
	var p := game.player
	match state:
		DORMANT:
			if p.ix < game.room.rect.end.x - 80:
				start_fight()
				var ex := (game.room.rect.end.x >> 3) - 1
				var ty := game.room.rect.position.y >> 3
				game.lock_area(ex, ty + 8, ex, ty + 19)
				game.hud.show_banner(boss_name)
				visible = true
				contact = 1
				hittable = true
				state = HIDE
				timer = 40
		PROWL:
			var target := p.center()
			var want := (target - pos).normalized() * (56.0 if hp < max_hp / 2 else 44.0)
			want += Vector2(0, sin(t * 0.09) * 30.0)
			vel = vel.lerp(want, 0.05)
			pos += vel / 60.0
			if timer <= 0:
				state = AIM
				timer = 34
				game.snd("roar")
		AIM:
			vel *= 0.9
			pos += vel / 60.0
			aim = (p.center() - pos).normalized()
			if t % 3 == 0:
				game.fx_bubble(int(pos.x + randf_range(-10, 10)), int(pos.y))
			if timer <= 0:
				state = LUNGE
				timer = 60
				vel = aim * 230.0
				game.snd("swing")
		LUNGE:
			pos += vel / 60.0
			if timer <= 0 or not bounds.grow(10).has_point(pos):
				pos = pos.clamp(bounds.position, bounds.end)
				lunges += 1
				state = SLUMP
				timer = 56
				game.snd("slam")
				game.shake = maxf(game.shake, 3.0)
		SLUMP:
			vel = Vector2.ZERO
			pos.y += sin(t * 0.2) * 0.4
			if timer <= 0:
				if lunges % 2 == 0:
					state = HIDE
					timer = 60
				else:
					state = PROWL
					timer = 120
		HIDE:
			# slide off into the wall, and come back from another side
			var left := pos.x < bounds.get_center().x
			var edge_x := bounds.position.x - 60.0 if left else bounds.end.x + 60.0
			pos.x = move_toward(pos.x, edge_x, 3.0)
			if timer <= 0:
				# back into view from the dark, just off the edge of the screen
				var side := -1.0 if p.ix > bounds.get_center().x else 1.0
				pos = Vector2(p.ix + side * 150.0, p.center().y)
				state = AIM
				timer = 44
	trail.push_front(pos)
	trail.pop_back()
	x = int(pos.x)
	y = int(pos.y) + 8
	_body_contact(p)


func _body_contact(p: Player) -> void:
	if p.iframes > 0 or dying > 0:
		return
	var pr := p.rect()
	for i in range(SPACING, trail.size(), SPACING):
		var s := trail[i]
		if pr.intersects(Rect2i(int(s.x) - 6, int(s.y) - 6, 12, 12)):
			p.hurt(1, int(s.x))
			return


func on_cast(_aim: Vector2) -> void:
	take_hit(1, Vector2i.ZERO)


func _die_tick() -> void:
	dying += 1
	pos.y += 0.4
	trail.push_front(pos)
	trail.pop_back()
	if dying % 7 == 0:
		var s := trail[randi() % trail.size()]
		game.fx_burst(int(s.x), int(s.y), Color("5fcdbb"), 6)
		game.fx_bubble(int(s.x), int(s.y))
	head.modulate.a = 1.0 - dying / 150.0
	modulate.a = 1.0 - dying / 150.0
	if dying >= 150:
		reveal("conger_dead")
		end_fight()
		dead = true


func render() -> void:
	position = Vector2.ZERO
	head.position = pos
	var d := vel if vel.length() > 2.0 else (aim if state == AIM else Vector2.RIGHT)
	head.rotation = d.angle()
	head.flip_v = d.x < 0.0
	head.modulate = Color(3, 3, 3) if flash > 0 else Color.WHITE
	if flash > 0:
		flash -= 1
	if state == AIM and t % 8 < 4:
		head.modulate = Color(1.6, 1.2, 1.2)
	queue_redraw()


func _draw() -> void:
	var col := Color(1, 1, 1, modulate.a)
	for i in range(trail.size() - 1, SPACING - 1, -SPACING):
		var s := trail[i]
		draw_texture(seg_tex, (s - Vector2(8, 8)).round(), col)
