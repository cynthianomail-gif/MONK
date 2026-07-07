extends Node
## headless 測試：LayoutTuner autoload（規格：佈局調整模式）。
## 跑法：Godot --headless res://test/TestLayoutTuner.tscn
## 驗證：
##   1) F8 切換 tuning_active 旗標與 get_tree().paused
##   2) 對一個假 Sprite2D 選中→移動→F9(save_tuning) 寫出 JSON，
##      內容含正確 old_pos/new_pos/delta（寫到暫存路徑，測完刪除，不留 repo）
##   3) 選中命中測試：面積小的候選優先於覆蓋全螢幕的背景
##
## LayoutTuner 是 autoload（單例），測試直接用它，不用 _make_game 模式。

const TMP_JSON := "user://_test_layout_tuning_tmp.json"

var ok: bool = true

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _ready() -> void:
	await get_tree().process_frame
	_test_f8_toggles_flag_and_paused()
	await get_tree().process_frame
	_test_hit_test_prefers_smallest_area()
	await _test_move_and_save_writes_json()
	print("LAYOUT_TUNER_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().paused = false
	get_tree().quit(0 if ok else 1)

func _f8_event() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = KEY_F8
	ev.pressed = true
	return ev

## ── 1) F8 切換旗標與 paused ──
func _test_f8_toggles_flag_and_paused() -> void:
	_check(LayoutTuner._debug_enabled, "LayoutTuner._debug_enabled true under --headless debug run (OS.is_debug_build())")
	_check(not LayoutTuner.tuning_active, "tuning_active starts false")
	LayoutTuner._unhandled_input(_f8_event())
	_check(LayoutTuner.tuning_active, "F8 toggles tuning_active to true")
	_check(get_tree().paused == true, "F8 on -> get_tree().paused true")
	LayoutTuner._unhandled_input(_f8_event())
	_check(not LayoutTuner.tuning_active, "F8 again toggles tuning_active back to false")
	_check(get_tree().paused == false, "F8 off -> get_tree().paused false")

## ── 2) 命中測試：小面積 Sprite2D 疊在大面積背景 ColorRect 之上，應選中小的那個。
##      LayoutTuner._get_screen_rect 對 Node2D 用 Sprite2D texture 大小換算，
##      用一張 8x8 的 ImageTexture 當「小物件」，背景另建一個大 Sprite2D(拉大 scale)代表「背景」。──
func _test_hit_test_prefers_smallest_area() -> void:
	var scene := Node2D.new()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene

	var bg := Sprite2D.new()
	bg.texture = _make_tex(64, 64)
	bg.centered = false
	bg.scale = Vector2(20, 20)   # 背景：64*20=1280 見方，覆蓋整個測試範圍
	bg.position = Vector2(0, 0)
	scene.add_child(bg)

	var small := Sprite2D.new()
	small.texture = _make_tex(16, 16)
	small.centered = false
	small.position = Vector2(100, 100)   # 16x16，遠小於背景
	scene.add_child(small)

	LayoutTuner.tuning_active = true
	LayoutTuner._try_select(Vector2(105, 105))   # 落在 small 範圍內，也落在 bg 範圍內
	_check(LayoutTuner._selected == small, "hit test picks the smaller Sprite2D over the full-screen background")
	LayoutTuner.tuning_active = false
	LayoutTuner._selected = null
	scene.queue_free()

func _make_tex(w: int, h: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)

## ── 3) 選中一個假 Sprite2D，移動它，F9(save_tuning) 寫出 JSON，
##      內容含正確 old_pos/new_pos/delta；寫到暫存路徑，驗完手動刪除。──
func _test_move_and_save_writes_json() -> void:
	if FileAccess.file_exists(TMP_JSON):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_JSON))

	var scene := Node2D.new()
	scene.name = "FakeScene"
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene

	var sp := Sprite2D.new()
	sp.name = "TunableSprite"
	sp.texture = _make_tex(32, 32)
	sp.position = Vector2(200, 300)
	scene.add_child(sp)
	await get_tree().process_frame

	LayoutTuner.tuning_active = true
	LayoutTuner._moved.clear()
	LayoutTuner._try_select(Vector2(210, 310))
	_check(LayoutTuner._selected == sp, "selected the fake sprite (setup for save test)")

	var old_pos: Vector2 = LayoutTuner._get_pos(sp)
	LayoutTuner._apply_move(sp, Vector2(15, -8))   # 微調一步，走跟方向鍵一樣的路徑
	var new_pos: Vector2 = LayoutTuner._get_pos(sp)
	_check(new_pos == old_pos + Vector2(15, -8), "sprite moved by the expected delta")

	LayoutTuner.save_tuning(TMP_JSON)
	_check(FileAccess.file_exists(TMP_JSON), "save_tuning() writes the JSON file")

	if FileAccess.file_exists(TMP_JSON):
		var f := FileAccess.open(TMP_JSON, FileAccess.READ)
		var txt := f.get_as_text()
		f.close()
		var parsed = JSON.parse_string(txt)
		_check(parsed is Array, "JSON content parses as an Array")
		if parsed is Array:
			var entry: Dictionary = {}
			for e in parsed:
				if String(e.get("node_path", "")) == String(sp.get_path()):
					entry = e
					break
			_check(not entry.is_empty(), "JSON contains an entry for the moved sprite's node_path")
			if not entry.is_empty():
				_check(Vector2(entry.old_pos[0], entry.old_pos[1]) == old_pos, "entry.old_pos matches pre-move position (got %s, want %s)" % [entry.old_pos, old_pos])
				_check(Vector2(entry.new_pos[0], entry.new_pos[1]) == new_pos, "entry.new_pos matches post-move position (got %s, want %s)" % [entry.new_pos, new_pos])
				_check(Vector2(entry.delta[0], entry.delta[1]) == Vector2(15, -8), "entry.delta matches applied delta (got %s)" % [entry.delta])
				_check(String(entry.get("node_class", "")) == "Sprite2D", "entry.node_class = Sprite2D")

	# 收尾：刪掉暫存檔（驗收條件明說「別留 _layout_tuning.json 在 repo」），
	# 這裡用的是 user:// 暫存路徑本來就不在 repo，仍主動清除保持乾淨。
	if FileAccess.file_exists(TMP_JSON):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_JSON))
	LayoutTuner.tuning_active = false
	LayoutTuner._selected = null
	LayoutTuner._moved.clear()
	scene.queue_free()
	await get_tree().process_frame
