extends Node
## headless 測試：LayoutStore autoload（規格：佈局工具 v2，
## docs/superpowers/specs/2026-07-07-layout-tuner-v2-design.md 驗收條件 1）。
## 跑法：Godot --headless res://test/TestLayoutStore.tscn
##
## 驗證：
##   1) register 後 live_entries() 含該節點；節點離開樹後不再列出（tree_exited 自動反登記）。
##   2) capture -> save -> 重建 store 狀態(模擬重載 _load) -> apply_override 後，節點位置
##      與存檔一致（Control 用 offsets、Node2D 用 position 各測一個）。
##   3) is_free：Container 的子節點回 false、CanvasLayer/一般 Control 的直接子節點回 true。
##   4) apply_group：兩個同 group 的 live 節點，capture 其一後 apply_group，兩者 local
##      position 相同。
##
## LayoutStore 是 autoload（單例），測試直接用它。用 user:// 暫存路徑寫 JSON，
## 測完清除，不留 repo（驗收條件 6）。

const TMP_JSON := "user://_test_layout_overrides_tmp.json"

var ok: bool = true

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _ready() -> void:
	await get_tree().process_frame
	_reset_store()
	_test_register_and_live_entries()
	await _test_unregister_on_tree_exit()
	_reset_store()
	_test_is_free()
	_reset_store()
	await _test_capture_save_load_apply_control()
	_reset_store()
	await _test_capture_save_load_apply_node2d()
	_reset_store()
	await _test_apply_group()
	_reset_store()
	print("LAYOUT_STORE_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

## 每個子測試前重置 LayoutStore 的暫態/持久狀態，避免互相汙染
## （真實遊戲一次只會有一份 _overrides，測試需要乾淨狀態才能各自斷言存讀正確）。
func _reset_store() -> void:
	LayoutStore._live.clear()
	LayoutStore._overrides.clear()
	if FileAccess.file_exists(TMP_JSON):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_JSON))

## ── 1) register 後 live_entries() 含該節點；節點離開樹後不再列出。──
func _test_register_and_live_entries() -> void:
	var host := Control.new()
	host.name = "TestHost1"
	get_tree().root.add_child(host)

	var free_ctrl := Control.new()
	free_ctrl.name = "FreeCtrl"
	host.add_child(free_ctrl)  # 父是普通 Control（非 Container）＝自由定位

	LayoutStore.register(free_ctrl, "test/free_ctrl")
	var entries := LayoutStore.live_entries()
	var found := false
	for e in entries:
		if e.key == "test/free_ctrl":
			found = true
			_check(e.node == free_ctrl, "live_entries 條目的 node 是註冊的節點本身")
			_check(e.free == true, "live_entries 條目 free==true（父非 Container）")
	_check(found, "register 後 live_entries() 含該節點")
	_check(free_ctrl.get_meta("layout_key", "") == "test/free_ctrl", "register 掛上 layout_key meta")
	_check(free_ctrl.is_in_group("layout_tunable"), "register 加入 layout_tunable group")

	host.queue_free()

func _test_unregister_on_tree_exit() -> void:
	await get_tree().process_frame
	var host := Control.new()
	host.name = "TestHost2"
	get_tree().root.add_child(host)
	var ctrl := Control.new()
	ctrl.name = "ExitCtrl"
	host.add_child(ctrl)
	LayoutStore.register(ctrl, "test/exit_ctrl")
	_check(LayoutStore._live.has("test/exit_ctrl"), "register 後 _live 有這個 key（反登記測試前置）")

	ctrl.queue_free()
	await get_tree().process_frame
	# tree_exited 訊號在 queue_free 完成離開樹時觸發，process_frame 後應已反登記。
	_check(not LayoutStore._live.has("test/exit_ctrl"), "節點離開樹後 _live 不再有這個 key（自動反登記）")
	var still_listed := false
	for e in LayoutStore.live_entries():
		if e.key == "test/exit_ctrl":
			still_listed = true
	_check(not still_listed, "節點離開樹後 live_entries() 不再列出")
	host.queue_free()
	await get_tree().process_frame

## ── 3) is_free：Container 子節點 false、CanvasLayer/一般 Control 直接子節點 true。──
func _test_is_free() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TestLayer"
	get_tree().root.add_child(layer)

	var direct_child := Control.new()
	direct_child.name = "DirectChild"
	layer.add_child(direct_child)
	_check(LayoutStore.is_free(direct_child), "CanvasLayer 的直接子節點 is_free() == true")

	var plain_host := Control.new()
	plain_host.name = "PlainHost"
	layer.add_child(plain_host)
	var direct_child2 := Control.new()
	direct_child2.name = "DirectChild2"
	plain_host.add_child(direct_child2)
	_check(LayoutStore.is_free(direct_child2), "一般 Control 的直接子節點 is_free() == true")

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	layer.add_child(vbox)
	var contained := Label.new()
	contained.name = "Contained"
	vbox.add_child(contained)
	_check(not LayoutStore.is_free(contained), "Container 的子節點 is_free() == false")

	layer.queue_free()

## ── 2a) Control：capture -> save -> 模擬重載(_load 邏輯) -> apply_override，
##      位置(offsets)與存檔一致。──
func _test_capture_save_load_apply_control() -> void:
	var host := Control.new()
	host.name = "TestHost3"
	get_tree().root.add_child(host)
	var ctrl := Control.new()
	ctrl.name = "CapturedCtrl"
	ctrl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	ctrl.position = Vector2(100, 200)
	ctrl.size = Vector2(300, 150)
	host.add_child(ctrl)
	await get_tree().process_frame

	LayoutStore.register(ctrl, "test/captured_ctrl")
	# 移到新位置再 capture（模擬 tuner 拖曳後呼叫）。
	ctrl.position = Vector2(555, 321)
	LayoutStore.capture("test/captured_ctrl")
	var expect_offsets: Array = [ctrl.offset_left, ctrl.offset_top, ctrl.offset_right, ctrl.offset_bottom]
	_check(LayoutStore._overrides.has("test/captured_ctrl"), "capture 後 _overrides 有這個 key")
	_check(LayoutStore._overrides["test/captured_ctrl"].get("kind", "") == "control", "capture 記錄 kind=control")

	LayoutStore.save_to_path(TMP_JSON)
	_check(FileAccess.file_exists(TMP_JSON), "save_to_path 寫出 JSON")

	# 模擬「重建 store」：清空 _overrides，改從暫存路徑重新載入（等同重開遊戲的 _load）。
	LayoutStore._overrides.clear()
	LayoutStore.load_from_path(TMP_JSON)
	_check(LayoutStore._overrides.has("test/captured_ctrl"), "重新載入後 _overrides 仍有這個 key")

	# 把節點挪回別的位置，證明 apply_override 真的把「存檔值」套回去，不是巧合沒動過。
	ctrl.position = Vector2(0, 0)
	LayoutStore.apply_override(ctrl, "test/captured_ctrl")
	var got_offsets: Array = [ctrl.offset_left, ctrl.offset_top, ctrl.offset_right, ctrl.offset_bottom]
	_check(got_offsets == expect_offsets, "apply_override 後 Control offsets 與存檔一致 (got %s want %s)" % [got_offsets, expect_offsets])
	_check(ctrl.position == Vector2(555, 321), "apply_override 後 Control position 回到 capture 時的新值")

	host.queue_free()

## ── 2b) Node2D：capture -> save -> 重載 -> apply_override，position 與存檔一致。──
func _test_capture_save_load_apply_node2d() -> void:
	var scene := Node2D.new()
	scene.name = "TestScene4"
	get_tree().root.add_child(scene)
	var sp := Sprite2D.new()
	sp.name = "CapturedSprite"
	sp.position = Vector2(10, 20)
	scene.add_child(sp)
	await get_tree().process_frame

	LayoutStore.register(sp, "test/captured_sprite")
	sp.position = Vector2(444, 88)
	LayoutStore.capture("test/captured_sprite")
	_check(LayoutStore._overrides["test/captured_sprite"].get("kind", "") == "node2d", "capture 記錄 kind=node2d")

	LayoutStore.save_to_path(TMP_JSON)
	LayoutStore._overrides.clear()
	LayoutStore.load_from_path(TMP_JSON)
	_check(LayoutStore._overrides.has("test/captured_sprite"), "重新載入後 _overrides 仍有 node2d 這個 key")

	sp.position = Vector2(0, 0)
	LayoutStore.apply_override(sp, "test/captured_sprite")
	_check(sp.position == Vector2(444, 88), "apply_override 後 Node2D position 與存檔一致 (got %s)" % [sp.position])

	scene.queue_free()

## ── 4) apply_group：兩個同 group 的 live 節點，capture 其一後 apply_group，
##      兩者 local position 相同。──
func _test_apply_group() -> void:
	var host := Control.new()
	host.name = "TestHost5"
	get_tree().root.add_child(host)
	var a := Control.new()
	a.name = "GroupA"
	a.position = Vector2(10, 10)
	host.add_child(a)
	var b := Control.new()
	b.name = "GroupB"
	b.position = Vector2(50, 60)
	host.add_child(b)
	await get_tree().process_frame

	LayoutStore.register(a, "test/group_a", "test_group")
	LayoutStore.register(b, "test/group_b", "test_group")

	a.position = Vector2(777, 333)
	LayoutStore.apply_group("test_group")
	_check(b.position == a.position, "apply_group 後同 group 的兩個節點 local position 相同 (a=%s b=%s)" % [a.position, b.position])

	host.queue_free()
