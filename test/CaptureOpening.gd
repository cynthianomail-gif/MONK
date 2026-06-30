extends Node
## GPU 視窗：實機從頭到尾播放 opening_temple_falls（音樂/字幕/配音/運鏡/揮拳影片全跑），
## 沿全長每 INTERVAL 秒截一張，組成整段逐格總覽。
## 跑法（視窗版 Godot）：tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureOpening.tscn
const OUT_DIR := "res://_cap_opening"
const SHOTS := {
	23.2: "k_a_windup",
	23.6: "k_b_pov_fist",
	23.78: "k_c_pov_fist2",
	24.0: "k_d_flash_black",
	28.7: "k_e_eyeopen_gods",
}

var _cs: Control

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var ps: PackedScene = load("res://src/screens/CutsceneScreen/StoryCutscene.tscn")
	var cl := CanvasLayer.new()
	add_child(cl)
	_cs = ps.instantiate()
	cl.add_child(_cs)
	await get_tree().process_frame
	await get_tree().process_frame
	_cs.play("opening_temple_falls")
	var times: Array = SHOTS.keys()
	times.sort()
	var prev := 0.0
	for t in times:
		await get_tree().create_timer(float(t) - prev).timeout
		prev = float(t)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT_DIR, SHOTS[t]])
		print("cap %s @ %.1fs" % [SHOTS[t], t])
	print("CAPTURE_OPENING: DONE")
	get_tree().quit(0)
