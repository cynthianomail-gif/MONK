extends Node
## 佈局調整模式（debug-only）：讓不會用 Godot 的使用者在遊戲內即時拖曳/微調
## 2D CanvasItem（Sprite2D/TextureRect/Control/Node2D 皆可）的位置，F9 落檔成
## D:\monk\MONK\_layout_tuning.json 供之後由 Claude 讀取、把數值烙進程式常數。
##
## 只在 OS.is_debug_build() 生效（正式版無感，_ready 直接跳過所有註冊）。
## 3D 場景（探索街景）不在範圍——只服務 2D CanvasItem。
##
## F8：切換調整模式（開/關）。開啟時：
##   - 顯示角落操作說明小卡
##   - get_tree().paused = true（凍住遊戲方便對準；與①暫停頁共存規則：
##     F8 模式開啟時 ESC 不再開暫停頁，見 MinigameBase._is_layout_tuner_active）
##   - 滑鼠左鍵點擊 → 命中測試選中最上層 CanvasItem（面積最小者優先，避免選到背景）
##   - 拖曳移動選中節點；方向鍵微調 1px／Shift+方向鍵 10px
## F9：把本次所有被移動過的節點寫進 JSON（讀舊檔合併／append）。

const OUTPUT_PATH := "res://_layout_tuning.json"
const NUDGE_STEP := 1.0
const NUDGE_STEP_FAST := 10.0

var tuning_active: bool = false
var _debug_enabled: bool = false

var _overlay: CanvasLayer
var _info_card: Label
var _highlight_box: Panel
var _selected: CanvasItem = null
var _selected_start_pos: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

## 本次 session 被移動過的節點記錄：node_path(String,唯一鍵) -> 記錄 dict。
## F9 寫檔時會與舊檔內容合併（同 node_path 以本次最新為準）。
var _moved: Dictionary = {}

func _ready() -> void:
	_debug_enabled = OS.is_debug_build()
	if not _debug_enabled:
		return
	# 本節點常駐監聽 F8/F9，process_mode 維持預設即可——調整模式開啟時我們自己把
	# get_tree().paused=true，但 LayoutTuner 自己必須設 ALWAYS 才能在暫停中繼續收
	# F8（關閉）/F9（存檔）與拖曳輸入。
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if not _debug_enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F8:
			toggle_tuning()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F9 and tuning_active:
			save_tuning()
			get_viewport().set_input_as_handled()
			return
	if not tuning_active:
		return
	if event is InputEventKey and event.pressed and _selected != null:
		var step := NUDGE_STEP_FAST if event.shift_pressed else NUDGE_STEP
		var moved := true
		match event.keycode:
			KEY_LEFT:
				_apply_move(_selected, Vector2(-step, 0.0))
			KEY_RIGHT:
				_apply_move(_selected, Vector2(step, 0.0))
			KEY_UP:
				_apply_move(_selected, Vector2(0.0, -step))
			KEY_DOWN:
				_apply_move(_selected, Vector2(0.0, step))
			_:
				moved = false
		if moved:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_select(event.position)
			if _selected != null:
				_dragging = true
				_drag_offset = _get_pos(_selected) - event.position
			get_viewport().set_input_as_handled()
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging and _selected != null:
		_set_pos(_selected, event.position + _drag_offset)
		_refresh_highlight()
		_refresh_info_card()
		get_viewport().set_input_as_handled()

## 切換調整模式。開啟：建說明卡 UI + paused=true；關閉：清掉 UI + 選取 + paused=false。
func toggle_tuning() -> void:
	if tuning_active:
		_disable_tuning()
	else:
		_enable_tuning()

func _enable_tuning() -> void:
	tuning_active = true
	get_tree().paused = true
	_build_overlay()

func _disable_tuning() -> void:
	tuning_active = false
	_dragging = false
	_selected = null
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_info_card = null
	_highlight_box = null
	get_tree().paused = false

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.name = "LayoutTunerOverlay"
	_overlay.layer = 4096   # 最上層，蓋過遊戲內任何 UI（含暫停頁 layer=110）
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_overlay)

	_info_card = Label.new()
	_info_card.process_mode = Node.PROCESS_MODE_ALWAYS
	_info_card.position = Vector2(24, 24)
	_info_card.add_theme_font_size_override("font_size", 20)
	_info_card.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	_info_card.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_info_card.add_theme_constant_override("outline_size", 6)
	_overlay.add_child(_info_card)
	_refresh_info_card()

	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = Color(1, 0.85, 0.2, 0.95)
	box.set_border_width_all(3)
	var panel := Panel.new()
	panel.name = "HighlightBox"
	panel.add_theme_stylebox_override("panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	_overlay.add_child(panel)
	_highlight_box = panel

func _refresh_info_card() -> void:
	if _info_card == null:
		return
	var lines := [
		"【佈局調整模式】F8 關閉／點選拖曳／方向鍵微調 1px、Shift+方向鍵 10px／F9 儲存",
	]
	if _selected != null and is_instance_valid(_selected):
		lines.append("已選中：%s @ %s" % [String(_selected.get_path()), _get_pos(_selected)])
	else:
		lines.append("尚未選中任何節點（點擊畫面上的物件）")
	_info_card.text = "\n".join(lines)

func _refresh_highlight() -> void:
	if _highlight_box == null:
		return
	if _selected == null or not is_instance_valid(_selected):
		_highlight_box.visible = false
		return
	var rect := _get_screen_rect(_selected)
	_highlight_box.visible = true
	_highlight_box.position = rect.position
	_highlight_box.size = rect.size

## 命中測試：在 viewport 座標下找滑鼠下方所有候選 CanvasItem，取面積最小者
## （否則永遠選到覆蓋全螢幕的背景層）。排除 LayoutTuner 自己的 overlay UI。
func _try_select(mouse_pos: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var candidates: Array = []
	_collect_candidates(scene, mouse_pos, candidates)
	if candidates.is_empty():
		_selected = null
		_refresh_highlight()
		_refresh_info_card()
		return
	candidates.sort_custom(func(a, b): return a.area < b.area)
	_selected = candidates[0].node
	_selected_start_pos = _get_pos(_selected)
	_refresh_highlight()
	_refresh_info_card()

func _collect_candidates(node: Node, mouse_pos: Vector2, out: Array) -> void:
	if node == _overlay:
		return
	if node is CanvasItem and (node is Node2D or node is Control):
		var rect := _get_screen_rect(node)
		if rect.size.x > 0.0 and rect.size.y > 0.0 and rect.has_point(mouse_pos):
			out.append({"node": node, "area": rect.size.x * rect.size.y})
	for c in node.get_children():
		_collect_candidates(c, mouse_pos, out)

## 取得節點在 viewport 座標系下的螢幕矩形（供命中測試與高亮框用）。
## Node2D：優先用 Sprite2D/TextureRect 貼圖大小換算；沒有貼圖資訊的當作一個點，
## 給個保底小矩形（避免完全選不到）。Control：直接用 global_rect。
func _get_screen_rect(node: CanvasItem) -> Rect2:
	if node is Control:
		return (node as Control).get_global_rect()
	if node is Node2D:
		var n2d := node as Node2D
		var local_rect := Rect2(Vector2(-8, -8), Vector2(16, 16))
		if node is Sprite2D and (node as Sprite2D).texture != null:
			var tex_size: Vector2 = (node as Sprite2D).texture.get_size() * n2d.scale
			var sp := node as Sprite2D
			local_rect = Rect2(-tex_size * 0.5 if sp.centered else Vector2.ZERO, tex_size)
		var gpos := n2d.global_position
		return Rect2(gpos + local_rect.position, local_rect.size)
	return Rect2()

func _get_pos(node: CanvasItem) -> Vector2:
	if node is Control:
		return (node as Control).position
	if node is Node2D:
		return (node as Node2D).position
	return Vector2.ZERO

func _set_pos(node: CanvasItem, pos: Vector2) -> void:
	if node is Control:
		(node as Control).position = pos
	elif node is Node2D:
		(node as Node2D).position = pos
	_record_move(node)

func _apply_move(node: CanvasItem, delta: Vector2) -> void:
	_set_pos(node, _get_pos(node) + delta)
	_refresh_highlight()
	_refresh_info_card()

func _record_move(node: CanvasItem) -> void:
	var path := String(node.get_path())
	var old_pos: Vector2 = _moved.get(path, {}).get("old_pos_v", _selected_start_pos)
	var new_pos := _get_pos(node)
	_moved[path] = {
		"scene_file": _current_scene_file(),
		"node_path": path,
		"node_class": node.get_class(),
		"texture_or_name": _texture_or_name(node),
		"old_pos": [old_pos.x, old_pos.y],
		"new_pos": [new_pos.x, new_pos.y],
		"delta": [new_pos.x - old_pos.x, new_pos.y - old_pos.y],
		"old_pos_v": old_pos,
		"time": Time.get_datetime_string_from_system(),
	}

func _current_scene_file() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	return scene.scene_file_path

func _texture_or_name(node: CanvasItem) -> String:
	if node is Sprite2D and (node as Sprite2D).texture != null:
		return (node as Sprite2D).texture.resource_path
	if node is TextureRect and (node as TextureRect).texture != null:
		return (node as TextureRect).texture.resource_path
	return node.name

## 把 _moved 寫進 JSON（與舊檔合併，同 node_path 以本次為準）。
## 測試可傳自訂 path 寫到暫存位置，避免留檔在 repo。
func save_tuning(path: String = OUTPUT_PATH) -> void:
	var merged: Dictionary = {}
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var txt := f.get_as_text()
			f.close()
			var parsed = JSON.parse_string(txt)
			if parsed is Array:
				for entry in parsed:
					if entry is Dictionary and entry.has("node_path"):
						merged[String(entry.node_path)] = entry
	for k in _moved:
		var e: Dictionary = _moved[k].duplicate()
		e.erase("old_pos_v")
		merged[k] = e
	var out_arr: Array = []
	for k in merged:
		out_arr.append(merged[k])
	var f2 := FileAccess.open(path, FileAccess.WRITE)
	if f2 != null:
		f2.store_string(JSON.stringify(out_arr, "\t"))
		f2.close()
