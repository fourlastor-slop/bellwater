extends Walker
## Scuttles along a ledge. Tough enough to need two hits.


func begin() -> void:
	hp = 2
	hw = 7
	hh = 9
	dir = -1 if x % 16 == 4 else 1
	sprite = make_sprite("res://assets/gfx/crab.png", 2)


func tick() -> void:
	t += 1
	apply_gravity()
	if grounded():
		walk(24.0)


func render() -> void:
	super()
	sprite.frame = (t / 10) % 2
