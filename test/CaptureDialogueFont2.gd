extends Node
## GPU 實機驗證（驗收條件⑤，第二張）：對話字級加大後，一般句長度＋立繪同框，
## 驗證名牌／立繪不被字級擠壓。跑法與輸出見 CaptureDialogueFont.gd 開頭註解。
## 沿用 CaptureJobDialogue.gd 已驗證過的單段對話擷取模式（獨立 process，不連著跑第二段對話）。

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await get_tree().process_frame

	# 這版 Dialogic 的 start() 內部已自己把 layout 掛到 get_tree().root 之下（同
	# CaptureLayoutTunerDialogic.gd 註解的根因說明），不要再手動 add_child 一次，
	# 否則會炸「already has a parent」。
	Dialogic.start("cherry_first_meeting")
	await get_tree().create_timer(1.0).timeout
	if Dialogic.current_timeline != null and Dialogic.has_subsystem("Text"):
		Dialogic.Text.skip_text_reveal()
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_cap_dialogue_font_02.png")
	print("CAPTURE_DIALOGUE_FONT_02_SAVED res://_cap_dialogue_font_02.png")

	print("CAPTURE_DIALOGUE_FONT2_DONE")
	get_tree().quit(0)
