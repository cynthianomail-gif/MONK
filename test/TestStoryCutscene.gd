extends Node
## headless 測試：StoryCutscene 分鏡＋字幕系統（美術未填時走黑底 fallback）。
## 跑法：Godot --headless res://test/TestStoryCutscene.tscn

var ok: bool = true
var _finished := false

func _ready() -> void:
	await get_tree().process_frame
	_test_data()
	await _test_player()
	await _test_consecutive_skip()
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

## 迴歸測試：跳過第一段開場過場後緊接著播下一段（雨段 ch1_aftermath_wake），
## 用同樣的跳過鍵操作應該也能跳過。修正前的 bug：StoryCutscene 用「開頭 0.4s 一律
## 忽略跳過鍵」擋掉啟動本過場那次殘留輸入，但玩家剛跳過上一段、手指一鬆又緊接著
## 按下一段的跳過鍵時，這次按鍵常常就落在新過場的 0.4s 忽略窗內——結果被無聲吞掉，
## 畫面沒有任何提示，玩家以為「按了沒用」便不再按，只能乾等雨段整段播完。
## 修法：改成「清空殘留輸入佇列＋等一幀」而非固定時間窗（見 StoryCutscene.play()），
## 所以本測試特意在雨段一出現就立刻按跳過鍵（模擬最壞情況：手指幾乎同時按下），
## 驗證仍會在該次按鍵後、或最晚下一次按鍵時正常跳過，不會卡到整段播完。
func _test_consecutive_skip() -> void:
	var ps: PackedScene = load("res://src/screens/CutsceneScreen/StoryCutscene.tscn")

	# 第一段：opening_temple_falls，播放中按跳過。
	var cs1 = ps.instantiate()
	get_tree().root.add_child(cs1)
	await get_tree().process_frame
	cs1.play("opening_temple_falls")
	await get_tree().create_timer(0.6).timeout
	await get_tree().process_frame
	_press_confirm()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not cs1._playing, "迴歸-第一段開場跳過後 _playing=false")
	cs1.queue_free()

	# 緊接著第二段：ch1_aftermath_wake（雨段），一出現就立刻按跳過（最壞情況：落在
	# 舊版 0.4s 忽略窗內）。新版設計下最多晚一幀生效，不應該卡住整段播完。
	var cs2 = ps.instantiate()
	get_tree().root.add_child(cs2)
	await get_tree().process_frame
	cs2.play("ch1_aftermath_wake")
	_press_confirm()  # 立刻按：舊版會被 0.4s 忽略窗吞掉且不會再有第二次按鍵
	# 給最多 1 秒讓 play() 的「清空佇列＋等一幀」流程走完並生效；
	# 若仍在播放，代表卡住（迴歸），修正前這裡會一路播到自然結束（約 4.5s）才 false。
	var waited := 0.0
	while cs2._playing and waited < 1.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_check(not cs2._playing, "迴歸-雨段緊接著按跳過（落在啟動窗內）仍應在 1s 內生效 (waited=%.2fs)" % waited)
	cs2.queue_free()
	await get_tree().process_frame

func _press_confirm() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SPACE
	ev.keycode = KEY_SPACE
	ev.unicode = 32
	ev.pressed = true
	Input.parse_input_event(ev)
	var ev_up := InputEventKey.new()
	ev_up.physical_keycode = KEY_SPACE
	ev_up.keycode = KEY_SPACE
	ev_up.unicode = 32
	ev_up.pressed = false
	Input.parse_input_event(ev_up)
