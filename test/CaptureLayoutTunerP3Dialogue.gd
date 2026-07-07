extends Node
## GPU 實機驗證（佈局工具 v2 P3 擴充）：開一段對話→驗證 dialogue/* 綠框(立繪/對話框/
## 名牌)出現＋LayoutStore.live_entries() 含登記 key 且 free==true。
## 跟既有 test/CaptureLayoutTunerDialogic.gd 不同：那支驗證的是「命中測試/整棵樹掃描」
## 這個修復（P1 前置修法）；這支驗證的是 P3 新增的 LayoutStore 登記本身。
## headless 驗不到「GUI 渲染」這件事本身，必須真的跑視窗版才能截圖佐證。
## 跑法（非 headless，需要實際渲染）：
## tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureLayoutTunerP3Dialogue.tscn
## 輸出：D:\monk\MONK\_cap_tuner_v2_dialogue.png（開調整模式，dialogue/* 全框標註）

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await get_tree().process_frame

	# 觸發一段真實對話（cherry_first_meeting，跟 CaptureLayoutTunerDialogic.gd 同一條，
	# 已知會顯示立繪＋對話框＋名牌，走 SpeakerBustLayer 這個本專案自己的 layout layer）。
	Dialogic.start("cherry_first_meeting")
	for i in 16:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	# 開啟調整模式（走真正的 toggle_tuning，會建 overlay + dialogue/* 綠框）。
	LayoutTuner._debug_enabled = true
	LayoutTuner.toggle_tuning()
	for i in 4:
		await get_tree().process_frame

	# 驗收條件②：LayoutStore.live_entries() 含登記的 dialogue/* key，各自 free==true。
	var live := LayoutStore.live_entries()
	var expect_keys := ["dialogue/portrait", "dialogue/textbox", "dialogue/nameplate"]
	var got_keys: Array = []
	for e in live:
		got_keys.append(e.key)
	for k in expect_keys:
		var idx: int = got_keys.find(k)
		var free_ok: bool = idx != -1 and live[idx].free == true
		print("LIVE_ENTRY_CHECK %s -> present=%s free=%s" % [k, idx != -1, live[idx].free if idx != -1 else "N/A"])
	print("LIVE_ENTRY_TOTAL_KEYS: ", got_keys)

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_cap_tuner_v2_dialogue.png")
	print("TUNER_V2_DIALOGUE_SHOT_SAVED res://_cap_tuner_v2_dialogue.png")

	print("CAPTURE_TUNER_V2_DIALOGUE_DONE")
	LayoutTuner.toggle_tuning()
	get_tree().paused = false
	get_tree().quit(0)
