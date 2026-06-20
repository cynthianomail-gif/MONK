extends Node
## 環境截圖驗證（自帶固定相機，先不放玩家）。
## 跑：...console.exe --path D:/monk/MONK res://test/CaptureShrineStreet.tscn -- smoke
const SHRINE := preload("res://src/screens/MapScreen/environments/ShrineStreet.gd")

func _ready() -> void:
	var root := Node3D.new()
	get_tree().root.add_child.call_deferred(root)
	await get_tree().process_frame
	var shrine := SHRINE.new()
	root.add_child(shrine)
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.current = true
	root.add_child(cam)
	cam.position = Vector3(0.0, 4.2, 6.0)
	cam.look_at(Vector3(0, 1.6, -16.0), Vector3.UP)
	print("CAP_SHRINE ready")
	if OS.get_cmdline_user_args().has("smoke"):
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("res://_shrine_shot.png")
		print("CAP_SHRINE_SAVED _shrine_shot.png ", img.get_width(), "x", img.get_height())
		get_tree().quit()
