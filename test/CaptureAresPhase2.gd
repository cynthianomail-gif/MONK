extends Node
## GPU 視窗截圖：實機播放 ares_phase2 變身（CutsceneScreen 逐幀+audio.ogg），
## 在受擊/蓄能/爆發/戰神四個時間點截圖，確認 okami 新幀實際渲染。
## ⚠ 只用視窗版 Godot 跑（headless 會卡 frame_post_draw）：
##   tools/godot/Godot_v4.5-stable_win64.exe --path D:/monk/MONK res://test/CaptureAresPhase2.tscn
const OUT_DIR := "res://_cap_ares_phase2"
const SHOTS := {
	0.6: "cap_1_brace",
	1.8: "cap_2_charge",
	3.0: "cap_3_burst",
	4.4: "cap_4_wargod",
}

var _cs: Control

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var ps: PackedScene = load("res://src/screens/CutsceneScreen/CutsceneScreen.tscn")
	var cl := CanvasLayer.new()
	add_child(cl)
	_cs = ps.instantiate()
	cl.add_child(_cs)
	await get_tree().process_frame
	await get_tree().process_frame
	_cs.play("ares_phase2")
	await _run_captures()
	print("CAPTURE_ARES_PHASE2: DONE")
	get_tree().quit(0)

func _run_captures() -> void:
	var times: Array = SHOTS.keys()
	times.sort()
	var prev := 0.0
	for t in times:
		await get_tree().create_timer(float(t) - prev).timeout
		prev = float(t)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s.png" % [OUT_DIR, SHOTS[t]])
		print("captured %s @ %.1fs" % [SHOTS[t], t])
