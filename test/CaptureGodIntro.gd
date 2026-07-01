extends Node
## GPU：實機跑 main_ch1_aftermath(了塵介紹 12 神)，沿對話推進截圖，
## 確認 12 神 CG 背景已換成 okami。
const OUT := "res://_cap_godintro"

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await get_tree().process_frame
	Dialogic.start("main_ch1_aftermath")
	for i in 26:
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/g_%02d.png" % [OUT, i])
		if Dialogic.current_timeline != null:
			Dialogic.handle_next_event()
	print("CAPTURE_GODINTRO: DONE")
	get_tree().quit(0)
