extends Ent
## A crack in the sea floor breathing bubbles. Stay in the stream to refill your air.

const RADIUS_X := 12
const HEIGHT := 56


func begin() -> void:
	solid_body = false
	sprite = make_sprite("res://assets/gfx/vent.png", 1)


func tick() -> void:
	t += 1
	if y > game.water_y and t % 7 == 0:
		game.fx.add(x + randf_range(-4, 4), y - 4, randf_range(-3, 3), randf_range(-46, -30), 70, Color(0.78, 0.96, 0.9, 0.9), 1, -6.0)
	var p := game.player
	if y > game.water_y and absi(p.ix - x) < RADIUS_X and p.iy > y - HEIGHT and p.iy <= y + 4:
		p.breath = minf(p.breath + 1.0 / 60.0 * 8.0, G.max_breath())
