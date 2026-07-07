extends Node
## GPU 實機驗證（佈局工具 v2 擴到 P4 小遊戲，驗收條件③）：進 Blackjack（21點）
## 小遊戲 → 開調整模式 → 驗證登記的自由塊（籌碼區/HUD/結算橫幅等）綠框 + 名牌
## 同時出現。headless 驗不到 GUI 渲染/命中測試，必須真的跑視窗版才能截圖佐證。
## 跑法（非 headless，需要實際渲染）：
## tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureLayoutTunerMinigame.tscn
## 輸出：D:\monk\MONK\_cap_tuner_v2_minigame_blackjack.png

const BLACKJACK := "res://src/screens/Minigames/Blackjack.tscn"

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await get_tree().process_frame  # 避免 first-capture 渲染成黑

	var inst: Node = (load(BLACKJACK) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	# 開啟調整模式（走真正的 toggle_tuning，會建 overlay + 綠框 + 名牌）。
	LayoutTuner._debug_enabled = true
	LayoutTuner.toggle_tuning()
	for i in 4:
		await get_tree().process_frame

	# 驗收：LayoutStore.live_entries() 含本場景登記的 key 且各自 free==true。
	var live := LayoutStore.live_entries()
	var expect_keys := [
		"minigame/common/result_panel", "minigame/common/pause_panel",
		"minigame/blackjack/chip_zone", "minigame/blackjack/result_banner",
		"minigame/blackjack/hud_label", "minigame/blackjack/tip_label",
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
	get_viewport().get_texture().get_image().save_png("res://_cap_tuner_v2_minigame_blackjack.png")
	print("TUNER_V2_MINIGAME_SHOT_SAVED res://_cap_tuner_v2_minigame_blackjack.png")

	print("CAPTURE_TUNER_V2_MINIGAME_DONE")
	LayoutTuner.toggle_tuning()
	get_tree().paused = false
	get_tree().quit(0)
