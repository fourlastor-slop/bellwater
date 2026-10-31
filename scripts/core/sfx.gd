extends Node
## Sound effects, layered music, and the muffling you hear under water.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const VOICES := 12

var streams := {}
var players: Array[AudioStreamPlayer] = []
var next_voice := 0
var music_a: AudioStreamPlayer
var music_b: AudioStreamPlayer
var current := ""
var rumble_player: AudioStreamPlayer
var rumble_on := false
var wind: AudioStreamPlayer
var muffle: AudioEffectLowPassFilter
var muffled := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		return
	AudioServer.add_bus(1)
	AudioServer.set_bus_name(1, "World")
	AudioServer.set_bus_send(1, "Master")
	muffle = AudioEffectLowPassFilter.new()
	muffle.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(1, muffle)
	AudioServer.add_bus(2)
	AudioServer.set_bus_name(2, "Music")
	AudioServer.set_bus_send(2, "World")
	AudioServer.add_bus(3)
	AudioServer.set_bus_name(3, "Effects")
	AudioServer.set_bus_send(3, "World")
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Effects"
		add_child(p)
		players.append(p)
	music_a = _music_player()
	music_b = _music_player()
	rumble_player = AudioStreamPlayer.new()
	rumble_player.bus = "Effects"
	add_child(rumble_player)
	wind = AudioStreamPlayer.new()
	wind.bus = "Effects"
	add_child(wind)
	apply_volume()


func _music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	return p


func apply_volume() -> void:
	if players.is_empty():
		return
	AudioServer.set_bus_volume_db(2, linear_to_db(maxf(float(G.settings.music), 0.0001)))
	AudioServer.set_bus_volume_db(3, linear_to_db(maxf(float(G.settings.sfx), 0.0001)))


func _stream(path_base: String) -> AudioStream:
	if streams.has(path_base):
		return streams[path_base]
	var s: AudioStream = null
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(path_base + ext):
			s = load(path_base + ext)
			break
	streams[path_base] = s
	return s


func play(name: String, pitch := 1.0, db := 0.0) -> void:
	if players.is_empty():
		return
	var s := _stream(SFX_DIR + name)
	if s == null:
		return
	var p := players[next_voice]
	next_voice = (next_voice + 1) % VOICES
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = db
	p.play()


func music(track: String) -> void:
	if players.is_empty() or track == current:
		return
	current = track
	var s := _stream(MUSIC_DIR + track)
	var out := music_a
	var inc := music_b
	music_a = inc
	music_b = out
	var tw := create_tween().set_parallel(true)
	tw.tween_property(out, "volume_db", -60.0, 1.2)
	if s != null:
		if s is AudioStreamOggVorbis:
			s.loop = true
		inc.stream = s
		inc.volume_db = -40.0
		inc.play()
		tw.tween_property(inc, "volume_db", 0.0, 1.0)


func rumble(on: bool) -> void:
	if rumble_player == null or on == rumble_on:
		return
	rumble_on = on
	if on:
		var s := _stream(SFX_DIR + "rumble")
		if s:
			s.loop = true
			rumble_player.stream = s
			rumble_player.volume_db = -30.0
			rumble_player.play()
			create_tween().tween_property(rumble_player, "volume_db", -4.0, 0.8)
	else:
		var tw := create_tween()
		tw.tween_property(rumble_player, "volume_db", -50.0, 1.4)
		tw.tween_callback(rumble_player.stop)


func set_muffled(on: bool) -> void:
	if muffle == null or on == muffled:
		return
	muffled = on
	create_tween().tween_property(muffle, "cutoff_hz", 700.0 if on else 20000.0, 0.25)
