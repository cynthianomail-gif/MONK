extends Node
## windowed 俯視截圖：確認 L 形街道版型（主街+西側支街）、店家/邊界/NPC/敵人分佈。
## 跑：Godot_..._win64.exe --path D:/monk/MONK res://test/CaptureShrineOverview.tscn -- smoke
const SCENE := preload("res://src/screens/MapScreen/MapScreen.tscn")
func _ready() -> void:
	GameManager.new_game()
	var s := SCENE.instantiate()
	get_tree().root.add_child.call_deferred(s)
	if not OS.get_cmdline_user_args().has("smoke"):
		return
	for i in 80:
		await get_tree().process_frame
	# 加一台俯視相機蓋掉街景相機，看整個 L
	var cam := Camera3D.new()
	get_tree().root.add_child(cam)
	cam.position = Vector3(-9, 46, -11)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.fov = 72
	cam.make_current()
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://_shrine_overview.png")
	print("CAP_OVERVIEW_SAVED %dx%d" % [img.get_width(), img.get_height()])
	get_tree().quit()
