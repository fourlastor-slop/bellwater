extends Node
## Renders the boot splash from the game itself: the sea risen under the bleached sky, your boat
## lifted off the sand, and the title over it. Run it with tools/gen_splash.sh.

const OUT := "res://assets/gfx/splash.png"
const DECK := Vector2i(11 * 320 + 124, 891)

var title: Node2D


func _ready() -> void:
	G.new_run()
	G.headless_sim = true
	G.s.level = 1
	G.s.wet_y = G.tide_px(1)
	G.s.cp = [DECK.x, DECK.y]
	var pad := Pad.new()
	var game := Game.new()
	add_child(game)
	game.setup(pad, false)
	game.set_physics_process(false)
	game.hud.hidden = true
	game.begin(false)
	game.fade = 0.0
	for i in 120:
		pad.clear()
		game.tick()
	game.player.facing = 1
	game.cam = game._camera_target()
	game.tick()
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	title = Node2D.new()
	layer.add_child(title)
	title.draw.connect(_paint)
	title.queue_redraw()
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT)
	print("wrote ", OUT)
	get_tree().quit()


func _paint() -> void:
	title.draw_set_transform(Vector2.ZERO, 0.0, Vector2(4, 4))
	var x := 40.0 - PixelFont.width("BELLWATER") / 2.0
	PixelFont.draw(title, Vector2(x, 3.5), "BELLWATER", Color("2a1f1c"))
	PixelFont.draw(title, Vector2(x, 3), "BELLWATER", Color("efe6d0"))
