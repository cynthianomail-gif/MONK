extends Node
## GPU：實機驗證對話立繪依職業切換。設 job=chanter → 開一段有無戒的對話 →
## 推進到無戒說話 → 截圖，看立繪是不是誦經僧(okami 金袍)。
## 跑法(視窗版)：Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureJobDialogue.tscn
const OUT := "res://_cap_jobdlg"

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	GameManager.player["job"] = "chanter"
	await get_tree().process_frame
	var layout := Dialogic.start("cherry_first_meeting")
	get_tree().root.add_child(layout)
	# 推進對話到無戒開口(cherry_first_meeting 第 5 行 Wujie）
	for i in 12:
		await get_tree().create_timer(0.45).timeout
		await RenderingServer.frame_post_draw
		var spk := ""
		if Dialogic.current_state_info.has("character_state"):
			pass
		# 截當前畫面
		get_viewport().get_texture().get_image().save_png("%s/step_%02d.png" % [OUT, i])
		# 嘗試推進
		if Dialogic.current_timeline != null:
			Dialogic.handle_next_event()
	print("CAPTURE_JOBDLG: DONE")
	get_tree().quit(0)
