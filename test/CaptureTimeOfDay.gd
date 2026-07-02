extends Node
## windowed 四連拍：上午/下午/傍晚/深夜 各截一張（驗證時段光照 profile＋SSAO＋新地面）。
## 用 GameManager.advance_time 推時段 → time_advanced → ShrineStreet._apply_time_profile。
const SCENE := preload("res://src/screens/MapScreen/MapScreen.tscn")
const NAMES := ["morning", "afternoon", "dusk", "night"]

func _ready() -> void:
	GameManager.new_game()
	var s := SCENE.instantiate()
	get_tree().root.add_child.call_deferred(s)
	if not OS.get_cmdline_user_args().has("smoke"):
		return
	for i in 60:
		await get_tree().process_frame
	for pi in NAMES.size():
		if pi > 0:
			GameManager.advance_time(1)
			for i in 20:
				await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("res://_tod_%d_%s.png" % [pi, NAMES[pi]])
	print("CAP_TOD_SAVED 4 shots")
	get_tree().quit()
