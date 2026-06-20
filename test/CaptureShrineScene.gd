extends Node
## 整場景截圖（ShrineStreet.tscn＝環境＋玩家＋CameraRig）。
## 跑：...console.exe --path D:/monk/MONK res://test/CaptureShrineScene.tscn -- smoke
const SCENE := preload("res://src/screens/MapScreen/environments/ShrineStreet.tscn")

func _ready() -> void:
	var s := SCENE.instantiate()
	get_tree().root.add_child.call_deferred(s)
	if OS.get_cmdline_user_args().has("smoke"):
		for i in 50:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("res://_shrine_scene_shot.png")
		print("CAP_SCENE_SAVED _shrine_scene_shot.png ", img.get_width(), "x", img.get_height())
		get_tree().quit()
