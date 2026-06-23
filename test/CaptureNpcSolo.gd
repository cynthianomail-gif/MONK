extends Node3D
## 單體 NPC 驗證：用 NpcFigure 載入指定模型(吃 `-- <name>`)、中性燈近拍、存 PNG。
## 材質走 NpcFigure._fix_materials(修透明)＝跟遊戲內一致。6 隻都可用。
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var nm: String = args[0] if args.size() > 0 else "liaochen"
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.85, 0.83, 0.78)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 1.0
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 3.2)
	cam.rotation_degrees = Vector3(-9, 0, 0)
	cam.current = true
	add_child(cam)
	var NF := load("res://src/screens/MapScreen/npc_figure.gd")
	var fig: Node3D = NF.new()
	add_child(fig)
	fig.setup(nm)
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://_npc_solo_%s.png" % nm)
	print("NPC_SOLO_SAVED _npc_solo_%s.png %dx%d" % [nm, img.get_width(), img.get_height()])
	get_tree().quit()
