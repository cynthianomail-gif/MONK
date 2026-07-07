extends Node
## GPU 實機驗證（規格驗收條件④）：佈局調整模式要能點中 Dialogic 對話框/立繪。
## headless 驗不到「GUI 吃事件」這件事本身，必須真的跑視窗版才能證明修法有效。
## 跑法（非 headless，需要實際渲染）：
## tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureLayoutTunerDialogic.tscn
## 輸出：D:\monk\MONK\_cap_tuner_dialogic.png（開啟調整模式、程式注入滑鼠點擊到
## Dialogic 立繪位置，若高亮框出現在該位置＝證明命中測試+_input 攔截都生效）。

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await get_tree().process_frame

	# 觸發一段真實對話（cherry_first_meeting，跟 CaptureJobDialogue.gd 同一條，已知會顯示立繪）。
	# 這版 Dialogic 的 start() 內部已經自己把 layout 掛到 get_tree().root 之下了
	# （不是 current_scene 的子孫）——這正是規格描述的根因情境①，用它來證明新版
	# 命中測試掃得到。不要再手動 add_child 一次，否則會炸「already has a parent」。
	Dialogic.start("cherry_first_meeting")
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	# 開啟調整模式（走真正的 toggle_tuning，會建 overlay/info_card/highlight_box）。
	LayoutTuner._debug_enabled = true
	LayoutTuner.toggle_tuning()
	await get_tree().process_frame

	# 在畫面中央偏下（VN 對話框慣常位置）注入一次「滑鼠點擊」：直接呼叫 _try_select
	# 模擬使用者左鍵點擊——這就是規格要的「程式注入滑鼠點擊到立繪/對話框位置」。
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var click_pos := Vector2(vp_size.x * 0.5, vp_size.y * 0.85)   # VN 文字框通常在畫面下方
	LayoutTuner._try_select(click_pos)

	var selected_info := "NONE"
	if LayoutTuner._selected != null and is_instance_valid(LayoutTuner._selected):
		selected_info = "%s (%s)" % [String(LayoutTuner._selected.get_path()), LayoutTuner._selected.get_class()]
	print("TUNER_DIALOGIC_SELECTED: ", selected_info)

	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var out_img: Image = get_viewport().get_texture().get_image()
	out_img.save_png("res://_cap_tuner_dialogic.png")
	print("TUNER_DIALOGIC_SHOT_SAVED res://_cap_tuner_dialogic.png")

	# 第二張：點在立繪（畫面左側，人物站立處）上，證明 Node2D/Sprite2D 類立繪
	# （不只是 Control 對話框）也命中得到。
	var portrait_click := Vector2(vp_size.x * 0.18, vp_size.y * 0.55)
	LayoutTuner._try_select(portrait_click)
	var portrait_info := "NONE"
	if LayoutTuner._selected != null and is_instance_valid(LayoutTuner._selected):
		portrait_info = "%s (%s)" % [String(LayoutTuner._selected.get_path()), LayoutTuner._selected.get_class()]
	print("TUNER_DIALOGIC_PORTRAIT_SELECTED: ", portrait_info)
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_cap_tuner_dialogic_portrait.png")
	print("TUNER_DIALOGIC_PORTRAIT_SHOT_SAVED res://_cap_tuner_dialogic_portrait.png")

	LayoutTuner.toggle_tuning()
	get_tree().paused = false
	get_tree().quit()
