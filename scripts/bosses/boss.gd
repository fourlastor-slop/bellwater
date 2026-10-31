class_name Boss
extends Ent
## Shared by the four bosses: waking, the health bar, dying, and the reward.

var boss_name := "BOSS"
var max_hp := 10
var awake := false
var dying := 0
var phase_t := 0


func start_fight(track := "boss") -> void:
	awake = true
	hp = max_hp
	game.boss = self
	game.locked_room = true
	game.snd("roar")
	game.shake = maxf(game.shake, 4.0)
	Sfx.music(track)


func end_fight() -> void:
	game.boss = null
	game.locked_room = false
	game.unlock_all()
	game.fx.ring_wave(x, y - 20)
	Sfx.music(game.room.music)


## Bring out the bell (or anything else) the room held back until this boss fell.
func reveal(flag: String) -> void:
	G.set_flag(flag)
	for e in game.room.ents:
		if e.get("requires", "") == flag:
			game.spawn(e)
	G.save_game()


func take_hit(dmg: int, _dir: Vector2i) -> void:
	if dying > 0:
		return
	hp -= dmg
	flash = 6
	game.snd("bosshit")
	game.fx_burst(x, y - hh / 2, Color.WHITE, 5)
	game.hitstop = 5
	if hp <= 0:
		dying = 1
		contact = 0
		hittable = false
		game.snd("bossdie")
		game.boss = null


func clang() -> void:
	game.snd("clang")
	game.fx_burst(game.player.ix + game.player.facing * 12, game.player.iy - 8, Color("f7d154"), 4)
