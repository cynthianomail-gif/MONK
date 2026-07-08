extends CanvasLayer
## 存檔槽選擇 overlay（2026-07-08，J3 存檔多槽）：純程式建構，比照 DialogueHistoryPanel
## 風格（近黑底＋金框、金字＋白字）。兩種模式：
##   save：三槽皆可點，點下＝存入該槽並切換 active_slot，有資料的槽顯示摘要，覆蓋不二次確認但 toast 回饋。
##   load：只有有資料的槽可點，點下＝載入該槽進遊戲。
## 鍵盤上下+Enter／滑鼠皆可操作；ESC 關閉（load 模式關閉＝取消，不載入任何東西）。
##
## 用法：
##   var picker := SAVE_SLOT_PICKER.instantiate()
##   get_tree().root.add_child(picker)
##   picker.open("save")  # 或 "load"
##   picker.slot_chosen.connect(func(n): ...)   # 可選：外部想知道結果
##   picker.closed.connect(func(): ...)          # 可選：外部想知道關閉（含取消）

signal slot_chosen(n: int)
signal closed

const GOLD := Color(0.957, 0.851, 0.541)
const PANEL_BG := Color(0.08, 0.075, 0.07, 1.0)
const WARM := Color(0.941, 0.913, 0.847)
const DIM := Color(0.55, 0.52, 0.46)
const EMPTY_COLOR := Color(0.4, 0.38, 0.34)

var mode: String = "save"  # "save" | "load"

var _panel: PanelContainer
var _title: Label
var _slot_box: VBoxContainer
var _slot_buttons: Array[Button] = []
var _focus_index: int = 0


func _ready() -> void:
	name = "SaveSlotPicker"
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			AudioManager.play_sfx("ui_cancel")
			_close(false)
			return
		if event.keycode == KEY_UP:
			get_viewport().set_input_as_handled()
			_move_focus(-1)
			return
		if event.keycode == KEY_DOWN:
			get_viewport().set_input_as_handled()
			_move_focus(1)
			return
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			_activate_focused()
			return
	# 開啟期間吞掉其餘輸入，避免穿透到底下畫面。
	if event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


## 開啟 picker。mode = "save" 或 "load"。
func open(p_mode: String) -> void:
	mode = p_mode
	_title.text = "選擇存檔槽" if mode == "save" else "讀取進度"
	_refresh()
	visible = true
	_focus_index = 0
	_apply_focus_visual()


func close() -> void:
	_close(false)


func _close(chosen: bool) -> void:
	visible = false
	closed.emit()
	if not chosen:
		return


func _refresh() -> void:
	for c in _slot_box.get_children():
		c.queue_free()
	_slot_buttons.clear()
	for n in range(1, SaveManager.SLOT_COUNT + 1):
		var summary: Dictionary = SaveManager.slot_summary(n)
		var btn := _make_slot_button(n, summary)
		_slot_box.add_child(btn)
		_slot_buttons.append(btn)


func _make_slot_button(n: int, summary: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(420, 64)
	btn.focus_mode = Control.FOCUS_NONE
	var exists: bool = bool(summary.get("exists", false))
	if exists:
		btn.text = "槽位 %d ── 第 %d 日 %s ｜ %d 金 ｜ %s" % [
			n, int(summary.get("day", 1)), String(summary.get("period_name", "?")),
			int(summary.get("gold", 0)), String(summary.get("area_name", "?"))
		]
	else:
		btn.text = "槽位 %d ── 空" % n
	if mode == "load" and not exists:
		btn.disabled = true
	btn.pressed.connect(func(): _on_slot_pressed(n))
	btn.mouse_entered.connect(func():
		var idx := _slot_buttons.find(btn)
		if idx != -1:
			_focus_index = idx
			_apply_focus_visual()
	)
	return btn


func _on_slot_pressed(n: int) -> void:
	if mode == "save":
		SaveManager.save_to_slot(n)
		AudioManager.play_sfx("save_done")
		slot_chosen.emit(n)
		_close(true)
	else:  # load
		if not SaveManager.slot_exists(n):
			return
		AudioManager.play_sfx("ui_select")
		SaveManager.load_from_slot(n)
		slot_chosen.emit(n)
		_close(true)


func _move_focus(delta: int) -> void:
	if _slot_buttons.is_empty():
		return
	var n := _slot_buttons.size()
	_focus_index = ((_focus_index + delta) % n + n) % n
	AudioManager.play_sfx("ui_select", 1.15)
	_apply_focus_visual()


func _activate_focused() -> void:
	if _focus_index < 0 or _focus_index >= _slot_buttons.size():
		return
	var btn := _slot_buttons[_focus_index]
	if btn.disabled:
		return
	btn.pressed.emit()


func _apply_focus_visual() -> void:
	for i in _slot_buttons.size():
		var btn := _slot_buttons[i]
		if i == _focus_index and not btn.disabled:
			btn.add_theme_color_override("font_color", GOLD)
		else:
			btn.remove_theme_color_override("font_color")


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5; _panel.anchor_top = 0.5
	_panel.anchor_right = 0.5; _panel.anchor_bottom = 0.5
	_panel.offset_left = -260; _panel.offset_top = -200
	_panel.offset_right = 260; _panel.offset_bottom = 200
	_panel.add_theme_stylebox_override("panel", _frame_style(PANEL_BG, GOLD, 3))
	add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	_panel.add_child(root)

	_title = Label.new()
	_title.text = "選擇存檔槽"
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_title)

	var sep := ColorRect.new()
	sep.color = GOLD.darkened(0.4)
	sep.custom_minimum_size = Vector2(0, 2)
	root.add_child(sep)

	_slot_box = VBoxContainer.new()
	_slot_box.add_theme_constant_override("separation", 10)
	root.add_child(_slot_box)

	var hint := Label.new()
	hint.text = "↑↓選擇／Enter確認／Esc取消"
	hint.add_theme_color_override("font_color", DIM)
	hint.add_theme_font_size_override("font_size", 16)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)


func _frame_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(20)
	return sb
