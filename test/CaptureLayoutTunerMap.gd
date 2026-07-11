extends Node
## GPU 實機驗證（佈局工具 v2 P2 擴充）：進地圖 HUD→開調整模式→驗證 map/* 綠框
## 出現＋LayoutStore.live_entries() 含登記 key 且 free==true。
## headless 驗不到「GUI 渲染/命中測試」這件事本身，必須真的跑視窗版才能截圖佐證。
## 跑法（非 headless，需要實際渲染）：
## tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureLayoutTunerMap.tscn
## 輸出：D:\monk\MONK\_cap_tuner_v2_map.png（開調整模式，map/* 全框標註）

const MAP_SCREEN := "res://src/screens/MapScreen/MapScreen.tscn"

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await get_tree().process_frame  # 避免 first-capture 渲染成黑

	GameManager.new_game()
	var inst: Node = (load(MAP_SCREEN) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	# 開啟調整模式（走真正的 toggle_tuning，會建 overlay + map/* 綠框）。
	LayoutTuner._debug_enabled = true
	LayoutTuner.toggle_tuning()
	for i in 4:
		await get_tree().process_frame

	# 驗收條件①：LayoutStore.live_entries() 含登記的 map/* key，各自 free==true。
	var live := LayoutStore.live_entries()
	var expect_keys := [
		"map/stats_label", "map/interaction_prompt",
		"map/action_menu", "map/toast", "map/minimap", "map/action_hints",
	]
	var got_keys: Array = []
	for e in live:
		got_keys.append(e.key)
	for k in expect_keys:
		var idx: int = got_keys.find(k)
		var free_ok: bool = idx != -1 and live[idx].free == true
		print("LIVE_ENTRY_CHECK %s -> present=%s free=%s" % [k, idx != -1, live[idx].free if idx != -1 else "N/A"])
	print("LIVE_ENTRY_TOTAL_KEYS: ", got_keys)

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_cap_tuner_v2_map.png")
	print("TUNER_V2_MAP_SHOT_SAVED res://_cap_tuner_v2_map.png")

	print("CAPTURE_TUNER_V2_MAP_DONE")
	LayoutTuner.toggle_tuning()
	get_tree().paused = false
	get_tree().quit(0)
