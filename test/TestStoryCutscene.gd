extends Node
## headless 測試：StoryCutscene 分鏡＋字幕系統（美術未填時走黑底 fallback）。
## 跑法：Godot --headless res://test/TestStoryCutscene.tscn

var ok: bool = true
var _finished := false

func _ready() -> void:
	await get_tree().process_frame
	_test_data()
	await _test_player()
	print("STORY_CUTSCENE_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _test_data() -> void:
	var all: Dictionary = JsonLoader.load_json("res://data/cutscenes.json")
	_check(all.has("opening_temple_falls"), "cutscenes.json 有 opening_temple_falls")
	var o: Dictionary = all.get("opening_temple_falls", {})
	_check(o.get("shots", []).size() == 8, "opening 8 shots (got %d)" % o.get("shots", []).size())
	_check(o.get("captions", []).size() == 10, "opening 10 captions (got %d)" % o.get("captions", []).size())
	# okami 重做後每個 shot 都有實際圖（image 或 black），不應再有缺圖
	for s in o.get("shots", []):
		var has_visual: bool = s.has("black") or (s.has("image") and ResourceLoader.exists(s.image)) or s.has("frames_dir")
		_check(has_visual, "shot 有可載入視覺來源: %s" % str(s.get("image", s.get("frames_dir", "black"))))
	# 字幕時間單調不重疊（start < end）
	for c in o.get("captions", []):
		_check(float(c.start) < float(c.end), "caption start<end: %s" % c.get("text", ""))
	# ch1 過場（okami 重做）：ares_intro / ch1_aftermath_wake 的 image shot 應可載入
	for cid in ["ares_intro", "ch1_aftermath_wake"]:
		for s in all.get(cid, {}).get("shots", []):
			if s.has("image"):
				_check(ResourceLoader.exists(s.image), "%s 圖可載入: %s" % [cid, s.image])

func _test_player() -> void:
	var ps: PackedScene = load("res://src/screens/CutsceneScreen/StoryCutscene.tscn")
	if ps == null:
		_check(false, "load StoryCutscene.tscn"); return
	var cs = ps.instantiate()
	get_tree().root.add_child(cs)
	await get_tree().process_frame
	cs.finished.connect(func() -> void: _finished = true)
	cs.play("opening_temple_falls")
	# 美術未填→每個 shot 走黑底 fallback；逐 shot 推進不應崩，最終 finished。
	var guard := 0
	while not _finished and guard < 30:
		cs._advance_shot()
		await get_tree().process_frame
		guard += 1
	_check(_finished, "cutscene 推進至 finished")
	# 字幕查找：t=5.0 顯示無戒台詞（旁白 0.8→無戒 5.0），t=10.5 顯示阿瑞斯台詞（9.9–13.7）
	var cs2 = ps.instantiate()
	get_tree().root.add_child(cs2)
	await get_tree().process_frame
	cs2.play("opening_temple_falls")
	cs2._t = 5.0
	cs2._update_caption()
	_check(cs2._cap_box.visible and cs2._cap_speaker.text == "無戒",
		"t=5s 顯示無戒字幕 (got speaker='%s' visible=%s)" % [cs2._cap_speaker.text, cs2._cap_box.visible])
	cs2._t = 10.5
	cs2._update_caption()
	_check(cs2._cap_box.visible and cs2._cap_speaker.text == "阿瑞斯",
		"t=10.5s 顯示阿瑞斯字幕 (got speaker='%s' visible=%s)" % [cs2._cap_speaker.text, cs2._cap_box.visible])
	cs.queue_free()
	cs2.queue_free()
	await get_tree().process_frame
