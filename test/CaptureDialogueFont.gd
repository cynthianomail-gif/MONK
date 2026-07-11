extends Node
## GPU 實機驗證（驗收條件⑤）：對話字級加大後，長句／一般句換行正常、不溢框、名牌立繪不被擠壓。
## 跑法（非 headless，需要實際渲染，每次只截一張——同一 process 內連續 end_timeline()→
## 重新 start() 第二段對話會使畫面停留黑幕，故拆成兩個獨立場景各截一張，較穩）：
## tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureDialogueFont.tscn
## tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureDialogueFont2.tscn
## 輸出：
##   D:\monk\MONK\_cap_dialogue_font_01.png（main_ch1_intel 第 2 行，122 字長句）
##   D:\monk\MONK\_cap_dialogue_font_02.png（cherry_first_meeting，一般句，見 CaptureDialogueFont2.gd）

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await get_tree().process_frame

	# main_ch1_intel 第 1 行 join（跳過，無畫面）→ 第 2 行才是 Liaochen 長句（122 字）。
	# 用 create_timer 等待（同 CaptureJobDialogue.gd 慣例）：typewriter 逐字顯示需要真實秒數，
	# 純 process_frame 計數在高幀率下等不到文字打完。skip_text_reveal() 讓當前行立即顯示完整文字，
	# 不用「多按一次」（那樣會推進到下一行，跳過目標長句）。
	Dialogic.start("main_ch1_intel")
	await get_tree().create_timer(1.0).timeout   # 讓 join 事件（無畫面）自動跑完，停在第 2 行長句
	if Dialogic.current_timeline != null and Dialogic.has_subsystem("Text"):
		Dialogic.Text.skip_text_reveal()
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_cap_dialogue_font_01.png")
	print("CAPTURE_DIALOGUE_FONT_01_SAVED res://_cap_dialogue_font_01.png")

	print("CAPTURE_DIALOGUE_FONT_DONE")
	get_tree().quit(0)
