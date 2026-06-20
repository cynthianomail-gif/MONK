extends Node
## 模擬按住 ui_up 數秒，沿途連拍 3 張驗證走動＋相機跟隨＋描邊持續正確。
## 跑：...console.exe --path D:/monk/MONK res://test/CaptureShrineWalk.tscn -- smoke
const SCENE := preload("res://src/screens/MapScreen/environments/ShrineStreet.tscn")

func _ready() -> void:
	var s := SCENE.instantiate()
	get_tree().root.add_child.call_deferred(s)
	if not OS.get_cmdline_user_args().has("smoke"):
		return
	for i in 20:
		await get_tree().process_frame
	Input.action_press("ui_up")
	for shot in 3:
		for i in 40:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("res://_shrine_walk_%d.png" % shot)
		print("CAP_WALK_SAVED _shrine_walk_%d.png" % shot)
	Input.action_release("ui_up")
	get_tree().quit()
