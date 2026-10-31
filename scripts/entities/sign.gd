extends Ent
## A wooden sign, or a plaque if drawn with no sprite.


func begin() -> void:
	solid_body = false
	if not props.has("plain"):
		sprite = make_sprite("res://assets/gfx/sign.png", 1)


func interactive() -> bool:
	return true


func interact() -> void:
	game.snd("text")
	game.hud.say(str(props.get("text", "...")))
