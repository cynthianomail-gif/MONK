extends Node
## 軍火庫區環境截圖驗證（自帶固定相機）。
## 跑：...console.exe --path D:/monk/MONK res://test/CaptureArmoryDistrict.tscn -- smoke
const ARMORY := preload("res://src/screens/MapScreen/environments/ArmoryDistrict.gd")

func _ready() -> void:
	var root := Node3D.new()
	get_tree().root.add_child.call_deferred(root)
	await get_tree().process_frame
	var armory := ARMORY.new()
	root.add_child(armory)
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.current = true
	root.add_child(cam)
	cam.position = Vector3(3.0, 4.4, 8.0)
	cam.look_at(Vector3(-1.5, 2.0, -15.0), Vector3.UP)
	print("CAP_ARMORY ready")
	if OS.get_cmdline_user_args().has("smoke"):
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("res://_armory_shot.png")
		print("CAP_ARMORY_SAVED _armory_shot.png ", img.get_width(), "x", img.get_height())
		get_tree().quit()
