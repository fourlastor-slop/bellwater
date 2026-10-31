extends Ent
## One of the townsfolk, turned to salt the day the sea left. The tide dissolves them.

var melting := 0


func should_spawn() -> bool:
	return float(y) < float(G.s.wet_y) or props.get("name", "") == "gran"


func begin() -> void:
	solid_body = false
	sprite = make_sprite("res://assets/gfx/statue.png", 3)
	sprite.frame = int(props.get("pose", 0)) % 3


func tick() -> void:
	t += 1
	if melting == 0 and float(y) >= game.wet_y:
		melting = 1
	if melting > 0:
		melting += 1
		if melting % 4 == 0:
			game.fx.add(x + randf_range(-4, 4), y - randf_range(0, 15), 0, -20.0, 30, Color(0.95, 0.93, 0.85))
		if melting > 60:
			if props.get("name", "") == "gran":
				_wake()
			else:
				dead = true


func _wake() -> void:
	melting = -1
	sprite.texture = load("res://assets/gfx/gran.png")
	sprite.hframes = 2
	sprite.frame = 0
	sprite.modulate = Color.WHITE


func render() -> void:
	position = Vector2(x, y)
	if melting > 0:
		sprite.modulate.a = 1.0 - melting / 60.0
	elif melting < 0:
		sprite.frame = (t / 30) % 2
