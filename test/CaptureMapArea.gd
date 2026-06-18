extends Node
## 視窗截圖：走正式流程 go_to_map 進西門區，等街景穩定後存 PNG。
## 跑法（非 headless）：Godot_..._console.exe --path D:/monk/MONK res://test/CaptureMapArea.tscn

func _ready() -> void:
	await get_tree().process_frame
	get_tree().current_scene = null  # 脫離 current_scene，換場時才不會釋放本截圖器
	GameManager.new_game()
	SceneRouter.go_to_map()
	var map: Node = await _wait_for_scene("MapScreen")
	if map == null:
		push_error("CAP FAIL: MapScreen 未載入")
		get_tree().quit(1)
		return
	for i in 200:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://_mapscreen_ximen.png")
	print("MAP_CAP_DONE ", img.get_width(), "x", img.get_height())
	get_tree().quit(0)

func _wait_for_scene(scene_name: String, max_frames: int = 600) -> Node:
	for i in max_frames:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs and cs.name == scene_name:
			return cs
	return null
