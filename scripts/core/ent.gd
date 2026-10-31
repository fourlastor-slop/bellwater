class_name Ent
extends Node2D
## Base for everything that lives in a room. x,y is the middle of the feet, in world pixels.

var game: Game
var props := {}
var x := 0
var y := 0
var hw := 4
var hh := 8
var hp := 1
var dead := false
var hittable := true
var solid_body := true
var contact := 1
var flash := 0
var t := 0
var sprite: Sprite2D


func should_spawn() -> bool:
	return true


func begin() -> void:
	pass


func tick() -> void:
	pass


func interactive() -> bool:
	return false


func interact_point() -> Vector2:
	return Vector2(x, y - 6)


func prompt() -> String:
	return ""


func interact() -> void:
	pass


func body_rect() -> Rect2i:
	return Rect2i(x - hw, y - hh, hw * 2, hh)


func take_hit(dmg: int, _dir: Vector2i) -> void:
	hp -= dmg
	flash = 6
	game.snd("hit")
	game.fx_burst(x, y - hh / 2, Color.WHITE, 3)
	if hp <= 0:
		die()


func die() -> void:
	dead = true
	game.snd("kill")
	game.fx_burst(x, y - hh / 2, Color("f29a4a"), 10)
	game.shake = maxf(game.shake, 1.5)


## The line touched this entity without a ring in play.
func on_cast(_aim: Vector2) -> void:
	take_hit(1, Vector2i.ZERO)


func render() -> void:
	position = Vector2(x, y)
	if sprite:
		sprite.modulate = Color(3, 3, 3) if flash > 0 else Color.WHITE
	if flash > 0:
		flash -= 1


func make_sprite(path: String, frames_h: int, frames_v := 1) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.hframes = frames_h
	s.vframes = frames_v
	s.centered = false
	var size := s.texture.get_size() / Vector2(frames_h, frames_v)
	s.position = Vector2(-size.x / 2.0, -size.y).round()
	add_child(s)
	return s


func tile_block(px: int, py: int) -> bool:
	return game.map.solid_at(px >> 3, py >> 3)


func stand_tile(px: int, py: int) -> bool:
	var tt := game.map.get_tile(px >> 3, py >> 3)
	return game.map.is_block(tt) or tt == WorldMap.ONEWAY
