extends Node
## 小遊戲「結尾過場停格當底＋結算/重試面板疊上」流程 GPU 截圖驗收（2026-07-07 定版流程）。
## ⚠ 只用視窗版 Godot 跑（headless 會卡 frame_post_draw）：
##   tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureRetryPanel.tscn

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await get_tree().process_frame

	var gs = load("res://src/screens/Minigames/Darts.gd")
	var g = gs.new()
	g.auto_start = false
	add_child(g)
	await get_tree().process_frame

	g.show_result_panel("飛鏢", "神射手", [{"label": "得分", "value": "301"}], g.make_result({"win": true}))
	# 等 0.3s 淡入完、CutsceneScreen 建立後，模擬點擊跳過（skip_to_last 停在最後一幀）。
	await get_tree().create_timer(0.6, true).timeout
	var cs := _find_cutscene_screen(get_tree().current_scene)
	if cs != null:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		cs._input(ev)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000:
		await get_tree().process_frame
		if g.is_result_panel_open():
			break
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_cap_retry_panel.png")
	print("SAVED res://_cap_retry_panel.png")
	print("CAPTURE_RETRY_DONE")
	get_tree().quit(0)

func _find_cutscene_screen(root: Node) -> Node:
	if root == null:
		return null
	if root.has_method("play") and root.has_signal("finished"):
		return root
	for c in root.get_children():
		var found := _find_cutscene_screen(c)
		if found != null:
			return found
	return null
