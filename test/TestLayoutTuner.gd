extends Node
## headless 測試：LayoutTuner autoload（規格：佈局調整模式）。
## 跑法：Godot --headless res://test/TestLayoutTuner.tscn
## 驗證：
##   1) F8 切換 tuning_active 旗標與 get_tree().paused
##   2) 對一個假 Sprite2D 選中→移動→F9(save_tuning) 寫出 JSON，
##      內容含正確 old_pos/new_pos/delta（寫到暫存路徑，測完刪除，不留 repo）
##   3) 選中命中測試：面積小的候選優先於覆蓋全螢幕的背景
##   4) （2026-07-07 新增）CanvasLayer 底下的 Control/Sprite2D（模擬 Dialogic 對話框/立繪）
##      也能被命中選中、拖曳/微調生效、JSON node_path 從 root 起算
##   5) （2026-07-07 新增）Container 底下的節點：資訊卡顯示警告，但仍照樣讓它移動（不靜默失敗）
##
## LayoutTuner 是 autoload（單例），測試直接用它，不用 _make_game 模式。
## 2026-07-07：LayoutTuner 把輸入處理從 _unhandled_input 改成 _input（GUI 之前攔截，
## 才點得到 Dialogic 對話框等 Control），測試呼叫端同步改叫 LayoutTuner._input(...)。

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
	await _test_canvas_layer_hit_test_and_save()
	await _test_container_child_warns_but_still_moves()
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
	LayoutTuner._input(_f8_event())
	_check(LayoutTuner.tuning_active, "F8 toggles tuning_active to true")
	_check(get_tree().paused == true, "F8 on -> get_tree().paused true")
	LayoutTuner._input(_f8_event())
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

## ── 4) CanvasLayer 底下的 Control（模擬 Dialogic 對話框）與 Sprite2D（模擬立繪）：
##      不掛在 current_scene 底下，而是直接掛在 get_tree().root 之下的獨立 CanvasLayer
##      （這正是 Dialogic.start() 回傳 layout 後 test/CaptureJobDialogue.gd 的用法：
##      get_tree().root.add_child(layout)）。驗證命中測試能選中它們、拖曳/微調生效、
##      JSON node_path 從 root 起算（get_path() 本來就是 root 起算的絕對路徑）。──
func _test_canvas_layer_hit_test_and_save() -> void:
	if FileAccess.file_exists(TMP_JSON):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_JSON))

	# 模擬 Dialogic 的 layout：獨立 CanvasLayer，不是 current_scene 的子孫。
	var dlg_layer := CanvasLayer.new()
	dlg_layer.name = "FakeDialogicLayout"
	get_tree().root.add_child(dlg_layer)

	# 模擬對話框（Control）。
	var textbox := Control.new()
	textbox.name = "@TextboxAutoName123"   # Dialogic 常見的動態 @ 開頭命名
	textbox.position = Vector2(400, 800)
	textbox.size = Vector2(600, 150)
	dlg_layer.add_child(textbox)

	# 模擬立繪（Sprite2D），跟對話框重疊但面積較小，應該優先被選到。
	var portrait := Sprite2D.new()
	portrait.name = "@PortraitAutoName456"
	portrait.texture = _make_tex(40, 40)
	portrait.centered = false
	portrait.position = Vector2(420, 810)   # 落在 textbox 範圍內，但面積遠小於 textbox
	dlg_layer.add_child(portrait)

	await get_tree().process_frame

	# 保持與其他測試場景（current_scene 仍是前一個測試留下的 Node2D，已 queue_free 中）
	# 無關——命中測試現在應該掃 get_tree().root 整棵樹，不受 current_scene 影響。
	LayoutTuner.tuning_active = true
	LayoutTuner._moved.clear()

	# 4a：命中在 textbox 與 portrait 重疊處，應選到面積較小的 portrait（Dialogic 立繪常疊在對話框之上）。
	LayoutTuner._try_select(Vector2(430, 820))
	_check(LayoutTuner._selected == portrait, "CanvasLayer 底下的 Sprite2D（模擬立繪）被命中選中，且面積較小者優先於重疊的 Control 對話框")

	# 4b：拖曳移動它。
	var old_pos: Vector2 = LayoutTuner._get_pos(portrait)
	LayoutTuner._apply_move(portrait, Vector2(10, 5))
	var new_pos: Vector2 = LayoutTuner._get_pos(portrait)
	_check(new_pos == old_pos + Vector2(10, 5), "CanvasLayer 底下的立繪也能被拖曳/微調移動")

	# 4c：改選 textbox 本身（點在 textbox 範圍內、portrait 範圍外），驗證 Control 也能被選中並移動。
	LayoutTuner._try_select(Vector2(410, 900))
	_check(LayoutTuner._selected == textbox, "CanvasLayer 底下的 Control（模擬對話框）也能被命中選中")
	var tb_old: Vector2 = LayoutTuner._get_pos(textbox)
	LayoutTuner._apply_move(textbox, Vector2(-3, 2))
	_check(LayoutTuner._get_pos(textbox) == tb_old + Vector2(-3, 2), "CanvasLayer 底下的 Control 也能被拖曳/微調移動")

	# 4d：F9 存檔，JSON node_path 應從 root 起算，能對應回這兩個節點。
	LayoutTuner.save_tuning(TMP_JSON)
	_check(FileAccess.file_exists(TMP_JSON), "CanvasLayer 節點的移動也能被 save_tuning() 寫出")
	if FileAccess.file_exists(TMP_JSON):
		var f := FileAccess.open(TMP_JSON, FileAccess.READ)
		var txt := f.get_as_text()
		f.close()
		var parsed = JSON.parse_string(txt)
		_check(parsed is Array, "JSON 內容可解析為 Array")
		if parsed is Array:
			var portrait_path := String(portrait.get_path())
			var textbox_path := String(textbox.get_path())
			_check(portrait_path.begins_with("/root/"), "portrait node_path 從 root 起算 (got %s)" % portrait_path)
			_check(textbox_path.begins_with("/root/"), "textbox node_path 從 root 起算 (got %s)" % textbox_path)
			var p_entry: Dictionary = {}
			var t_entry: Dictionary = {}
			for e in parsed:
				if String(e.get("node_path", "")) == portrait_path:
					p_entry = e
				elif String(e.get("node_path", "")) == textbox_path:
					t_entry = e
			_check(not p_entry.is_empty(), "JSON 內有 portrait 的條目，node_path 正確對應 root 起算路徑")
			_check(not t_entry.is_empty(), "JSON 內有 textbox 的條目，node_path 正確對應 root 起算路徑")
			if not p_entry.is_empty():
				_check(String(p_entry.get("node_class", "")) == "Sprite2D", "portrait entry.node_class = Sprite2D")
				var hint: String = String(p_entry.get("hint", ""))
				_check(hint.contains("FakeDialogicLayout") or hint.contains("PortraitAutoName"), "portrait entry.hint 記錄了有意義的祖先名稱（不是純 @ 亂碼），got: %s" % hint)
			if not t_entry.is_empty():
				_check(String(t_entry.get("node_class", "")) == "Control", "textbox entry.node_class = Control")

	if FileAccess.file_exists(TMP_JSON):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_JSON))
	LayoutTuner.tuning_active = false
	LayoutTuner._selected = null
	LayoutTuner._moved.clear()
	dlg_layer.queue_free()
	await get_tree().process_frame

## ── 5) Container 底下的節點：position 移動可能被容器排版蓋回去，資訊卡要顯示警告，
##      但仍然照樣讓它移動（不能因為在 Container 底下就靜默拒絕移動）。──
func _test_container_child_warns_but_still_moves() -> void:
	var scene := Control.new()
	scene.name = "FakeContainerScene"
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.position = Vector2(50, 50)
	scene.add_child(vbox)

	var label := Label.new()
	label.name = "ChildLabel"
	label.text = "hint text"
	label.position = Vector2(0, 0)
	label.size = Vector2(200, 40)
	vbox.add_child(label)
	await get_tree().process_frame

	# 走真正的 _enable_tuning() 路徑（而非直接改旗標）才會建出 _info_card，
	# 資訊卡文字才驗得到（其他測試只需要 tuning_active 旗標本身，這個測試要驗卡片文字）。
	LayoutTuner._enable_tuning()
	LayoutTuner._moved.clear()
	LayoutTuner._try_select(label.get_global_rect().get_center())
	_check(LayoutTuner._selected == label, "選中 Container 底下的 Label 節點")
	_check(LayoutTuner._is_in_container(label), "_is_in_container 正確判斷父層是 Container")

	LayoutTuner._refresh_info_card()
	var card_text: String = LayoutTuner._info_card.text if LayoutTuner._info_card != null else ""
	_check(card_text.contains("容器排版"), "資訊卡顯示容器排版警告文字 (got: %s)" % card_text)

	var old_pos: Vector2 = LayoutTuner._get_pos(label)
	LayoutTuner._apply_move(label, Vector2(7, 3))
	_check(LayoutTuner._get_pos(label) == old_pos + Vector2(7, 3), "Container 底下的節點 position 仍照樣被設定（不靜默失敗，即便排版可能之後蓋回去）")

	LayoutTuner._disable_tuning()
	LayoutTuner._moved.clear()
	scene.queue_free()
	await get_tree().process_frame
