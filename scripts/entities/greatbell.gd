extends Ent
## The Great Bell of Bellwater. Nothing else in the game is this big.

var swing := 0.0
var swing_v := 0.0
var bell: Sprite2D


func begin() -> void:
	solid_body = false
	bell = Sprite2D.new()
	bell.texture = load("res://assets/gfx/greatbell.png")
	bell.offset = Vector2(0, 40)
	bell.position = Vector2(0, -130)
	add_child(bell)
	z_index = -1


func interactive() -> bool:
	return game.ending == 0


func prompt() -> String:
	return "ring" if G.flag("drinker_dead") else ""


func interact_point() -> Vector2:
	return Vector2(x, y - 8)


func interact() -> void:
	if not G.flag("drinker_dead"):
		game.hud.say("You pull the rope. It lifts the weight of a house, and the bell makes no sound at all.\n\nThere is no sea in the world for it to call.")
		return
	swing_v = 0.03
	game.start_finale()


func tick() -> void:
	t += 1
	swing_v += -swing * 0.02
	swing_v *= 0.995
	swing += swing_v


func render() -> void:
	position = Vector2(x, y)
	bell.rotation = swing
