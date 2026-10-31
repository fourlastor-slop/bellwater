extends Ent
## An item floating in the world. Abilities and upgrades alike.

const ORDER: Array[String] = ["reel", "helm", "bellows", "fork", "pearl", "air", "line", "barb"]
const INFO := {
	"reel": ["THE REEL", "A ringer's line on a brass reel.\nPress CAST (C or L, gamepad B) near an iron ring, in the direction you hold, to reel yourself in."],
	"helm": ["THE BRASS HELM", "An old diver's helm. Heavy enough to sink you.\nHold DOWN in water to dive. Watch your breath, and look for bubble vents."],
	"bellows": ["THE BELLOWS", "Your grandmother's forge bellows.\nPress JUMP in mid-air for a second leap. Under water, it's a burst of speed."],
	"fork": ["THE TUNING FORK", "Struck, it sings every tide you have called.\nPress FORK (F or V, gamepad Y) anywhere to send the sea to any mark you know."],
	"pearl": ["A PEARL", "The sea made this, and left it behind.\nYou feel sturdier. One more pearl of health."],
	"air": ["AN AIR SAC", "A fish's swim bladder, still full.\nYou can hold your breath for longer."],
	"line": ["THE LONG LINE", "Good tarred line, and plenty of it.\nThe Reel now reaches much further."],
	"barb": ["THE BARBED HOOK", "A cruel old gaff, sharper than yours.\nYour boathook strikes twice as hard."],
}

var item := "pearl"
var key := ""


func should_spawn() -> bool:
	key = "item_%d_%d" % [x, y]
	var need: String = props.get("requires", "")
	return not G.taken(key) and (need == "" or G.flag(need))


func begin() -> void:
	solid_body = false
	item = str(props.get("item", "pearl"))
	sprite = make_sprite("res://assets/gfx/pickups.png", ORDER.size())
	sprite.frame = ORDER.find(item)


func tick() -> void:
	t += 1
	if t % 24 == 0:
		game.fx.add(x + randf_range(-6, 6), y - 6 + randf_range(-6, 4), 0, -10.0, 30, Color("f7d154"))
	if body_rect().intersects(game.player.rect()):
		_collect()


func body_rect() -> Rect2i:
	return Rect2i(x - 8, y - 14, 16, 16)


func _collect() -> void:
	dead = true
	G.take(key)
	match item:
		"pearl":
			G.s.max_hp = int(G.s.max_hp) + 1
			game.player.hp = int(G.s.max_hp)
		"air":
			G.s.air = int(G.s.air) + 1
			game.player.breath = G.max_breath()
		_:
			G.give(item)
	game.snd("pickup")
	game.fx.ring_wave(x, y - 6, Color(1.0, 0.9, 0.5))
	game.fx_burst(x, y - 6, Color("f7d154"), 12)
	var info: Array = INFO[item]
	game.hud.say("%s\n\n%s" % [tr(info[0]), tr(info[1])])
	G.save_game()


func render() -> void:
	position = Vector2(x, y + roundf(sin(t * 0.07) * 1.5) - 2)
