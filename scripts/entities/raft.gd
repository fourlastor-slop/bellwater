extends Ent
## Driftwood that rests on the ground and rides the tide. Stand on it. Rises and falls with the sea.

var rest_y := 0
var half := 12
var fy := 0.0
var deck := 5
var draft := 2


func begin() -> void:
	solid_body = false
	rest_y = y
	if props.has("deco"):
		var r: Array = Sprites.deco()[props.deco]
		sprite = Sprite2D.new()
		sprite.texture = Sprites.deco_tex()
		sprite.region_enabled = true
		sprite.region_rect = Rect2(r[0], r[1], r[2], r[3])
		sprite.centered = false
		sprite.position = Vector2(-int(r[2]) / 2, -int(r[3]))
		sprite.material = game.grade
		add_child(sprite)
		half = int(r[2]) / 2 - 8
		deck = int(props.get("deck", 24))
		draft = int(props.get("draft", 8))
	else:
		sprite = make_sprite("res://assets/gfx/raft.png", 1)
		half = sprite.texture.get_width() / 2
	fy = float(y)
	_settle(true)
	game.platforms.append(self)


func top() -> int:
	return y - deck


func left() -> int:
	return x - half


func right() -> int:
	return x + half


func _settle(instant: bool) -> void:
	var target := minf(float(rest_y), game.water_y + draft + sin(t * 0.03) * 1.0)
	fy = target if instant else move_toward(fy, target, 1.3)
	var ny := roundi(fy)
	var dy := ny - y
	y = ny
	if dy != 0 and game.player.ride == self:
		game.player.iy += dy


func tick() -> void:
	t += 1
	_settle(false)
