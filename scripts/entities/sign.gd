extends Ent
## A wooden sign, or a brass plaque for the Belfry.


func begin() -> void:
	solid_body = false
	sprite = make_sprite("res://assets/gfx/plaque.png" if props.has("plain") else "res://assets/gfx/sign.png", 1)


func interactive() -> bool:
	return true


func interact() -> void:
	game.snd("text")
	game.hud.say(tr(str(props.get("text", "..."))))
