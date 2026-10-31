extends Node
## Dev tool: drive the game with a script of timed inputs and save screenshots.
## usage: godot --path . res://tests/shot.tscn -- out_dir script.json

var game: Game
var pad := Pad.new()
var steps: Array = []
var step_i := 0
var wait := 0
var out := ""
var started := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	if args.size() > 1:
		steps = JSON.parse_string(FileAccess.get_file_as_string(args[1]))


func _process(_d: float) -> void:
	if not started:
		G.new_run()
		game = Game.new()
		add_child(game)
		game.setup(pad, false)
		game.set_physics_process(false)
		if steps.size() > 0 and steps[0] is Dictionary and steps[0].has("setup"):
			var s: Dictionary = steps[0].setup
			for a: String in s.get("give", []):
				G.give(a)
			if s.has("level"):
				G.s.level = int(s.level)
				G.s.wet_y = G.tide_px(int(s.level))
			if s.has("wet"):
				G.s.wet_y = float(s.wet)
			if s.has("cp"):
				G.s.cp = s.cp
			step_i = 1
		game.begin(false)
		started = true
		return
	if step_i >= steps.size():
		get_tree().quit()
		return
	var st: Dictionary = steps[step_i]
	if st.has("tp"):
		var at: Array = st.tp
		game.player.place(int(at[0]), int(at[1]))
		var r := game.map.room_at(int(at[0]), int(at[1]) - 4)
		for e in game.ents:
			e.queue_free()
		game.ents = []
		game._enter_room(r)
		game.cam = game._camera_target()
	if st.has("tide"):
		game.set_tide_instant(int(st.tide))
	if st.has("wet"):
		game.wet_y = float(st.wet)
		G.s.wet_y = game.wet_y
	if st.has("flag"):
		G.set_flag(st.flag)
	if st.has("shot"):
		game.hud.banner_t = 0
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s.png" % [out, st.shot])
		print("shot ", st.shot, " player ", game.player.ix, ",", game.player.iy, " state ", game.player.state, " water ", game.water_y)
		step_i += 1
		wait = 0
		return
	var n := int(st.get("t", 1))
	for i in n:
		pad.clear()
		pad.x = int(st.get("x", 0))
		pad.y = int(st.get("y", 0))
		var first: bool = wait == 0
		pad.jump = st.get("jump", false)
		pad.jump_p = pad.jump and first
		pad.attack_p = st.get("attack", false) and first
		pad.cast_p = st.get("cast", false) and first
		pad.interact_p = st.get("use", false) and first
		pad.up_p = pad.interact_p
		game.tick()
		wait += 1
	wait = 0
	step_i += 1
