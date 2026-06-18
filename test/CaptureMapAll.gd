extends Node
## 視窗截圖：走正式流程進地圖後，依序切到各區/內景/城市地圖各存一張 PNG，供美術自檢。
## 跑法（非 headless）：Godot_..._win64.exe --path D:/monk/MONK res://test/CaptureMapAll.tscn
## 新圖跑前先：Godot --headless --path D:/monk/MONK --import

func _ready() -> void:
	await get_tree().process_frame
	get_tree().current_scene = null  # 脫離 current_scene，換場時才不會釋放本截圖器
	GameManager.new_game()
	GameManager.set_flag("linsen_unlocked", true)  # 解鎖林森才看得到該街景
	SceneRouter.go_to_map()
	var map: Node = await _wait_for_scene("MapScreen")
	if map == null:
		push_error("CAP FAIL: MapScreen 未載入")
		get_tree().quit(1)
		return

	# 1) 西門（開場自動載入）
	await _shoot("res://_cap_ximen.png")

	# 2) 萬華舊區
	map.show_district("wanhua_old")
	await _shoot("res://_cap_wanhua.png")

	# 3) 林森商圈
	map.show_district("linsen")
	await _shoot("res://_cap_linsen.png")

	# 4) 內景（破舊古廟，主線樞紐）
	map._on_location_entered("old_temple")
	await _shoot("res://_cap_interior_temple.png")
	map.leave_location()

	# 5) 城市地圖
	map.show_city_map()
	await _shoot("res://_cap_citymap.png")

	print("MAP_CAP_ALL_DONE")
	get_tree().quit(0)

func _shoot(path: String) -> void:
	for i in 60:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(path)
	print("CAP ", path, " ", img.get_width(), "x", img.get_height())

func _wait_for_scene(scene_name: String, max_frames: int = 600) -> Node:
	for i in max_frames:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs and cs.name == scene_name:
			return cs
	return null
