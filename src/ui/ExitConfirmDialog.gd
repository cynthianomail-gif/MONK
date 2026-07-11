extends CanvasLayer
## 「未儲存進度」離開確認框（2026-07-11，設定頁「回主選單」用）：三選一 overlay，
## 比照 SaveSlotPicker 的建構風格（純程式建構、近黑底＋金框、鍵盤全操作）。
## 三選項：save（儲存並離開，呼叫端接著開 SaveSlotPicker）／discard（不儲存直接離開）／
## cancel（取消，留在原頁，不動任何檔）。本身不寫檔、不換場，全部交給呼叫端依 choice 執行。
##
## 用法：
##   var dlg := EXIT_CONFIRM_DIALOG.new()
##   get_tree().root.add_child(dlg)
##   dlg.choice_made.connect(func(choice: String): ...)   # "save" / "discard" / "cancel"
##   dlg.open()
##
## 加入 "modal_overlay" 群組：MenuShell._input() 會在此群組有成員時整個略過自己的按鍵處理
## （見 MenuShell.gd 開頭守衛），避免 Esc/方向鍵/Enter 被 MenuShell 搶先攔截（MenuShell 深埋在
## 場景樹較早的節點下，一般 _input() 呼叫順序早於這裡用 get_tree().root.add_child 後補的 overlay，
## 兩邊都會對同一個按鍵事件呼叫 set_input_as_handled()，不加守衛的話 MenuShell 會先吃掉輸入）。

signal choice_made(choice: String)

const GOLD := Color(0.957, 0.851, 0.541)
const PANEL_BG := Color(0.08, 0.075, 0.07, 1.0)
const WARM := Color(0.941, 0.913, 0.847)
const DIM := Color(0.55, 0.52, 0.46)

var _buttons: Array[Button] = []
var _focus_index: int = 0


func _ready() -> void:
	name = "ExitConfirmDialog"
	layer = 105  # 壓過 MenuShell(100)／SaveSlotPicker(100)，確保視覺上疊在最上層。
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("modal_overlay")
	visible = false
	_build()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			AudioManager.play_sfx("ui_cancel")
			_choose("cancel")
			return
		if event.keycode == KEY_UP or event.keycode == KEY_LEFT:
			get_viewport().set_input_as_handled()
			_move_focus(-1)
			return
		if event.keycode == KEY_DOWN or event.keycode == KEY_RIGHT:
			get_viewport().set_input_as_handled()
			_move_focus(1)
			return
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			if _focus_index >= 0 and _focus_index < _buttons.size():
				_buttons[_focus_index].pressed.emit()
			return
	# 開啟期間吞掉其餘輸入，避免穿透到底下畫面（同 SaveSlotPicker 慣例）。
	if event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	_focus_index = 0
	_apply_focus_visual()


func _choose(choice: String) -> void:
	visible = false
	choice_made.emit(choice)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5; panel.anchor_top = 0.5
	panel.anchor_right = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -260; panel.offset_top = -160
	panel.offset_right = 260; panel.offset_bottom = 160
	panel.add_theme_stylebox_override("panel", _frame_style(PANEL_BG, GOLD, 3))
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	panel.add_child(root)

	var title := Label.new()
	title.text = "本次進度尚未儲存，要怎麼做？"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(title)

	var sep := ColorRect.new()
	sep.color = GOLD.darkened(0.4)
	sep.custom_minimum_size = Vector2(0, 2)
	root.add_child(sep)

	_buttons.clear()
	_add_choice_button(root, "儲存並離開", "save", "ui_select")
	_add_choice_button(root, "不儲存離開", "discard", "ui_select")
	_add_choice_button(root, "取消", "cancel", "ui_cancel")

	var hint := Label.new()
	hint.text = "↑↓選擇／Enter確認／Esc取消"
	hint.add_theme_color_override("font_color", DIM)
	hint.add_theme_font_size_override("font_size", 16)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)


func _add_choice_button(parent: VBoxContainer, text: String, choice: String, sfx: String) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(420, 56)
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = text
	btn.add_theme_color_override("font_color", WARM)
	btn.pressed.connect(func() -> void:
		AudioManager.play_sfx(sfx)
		_choose(choice)
	)
	btn.mouse_entered.connect(func() -> void:
		var idx := _buttons.find(btn)
		if idx != -1:
			_focus_index = idx
			_apply_focus_visual()
	)
	parent.add_child(btn)
	_buttons.append(btn)


func _move_focus(delta: int) -> void:
	if _buttons.is_empty():
		return
	var n := _buttons.size()
	_focus_index = ((_focus_index + delta) % n + n) % n
	AudioManager.play_sfx("ui_select", 1.15)
	_apply_focus_visual()


func _apply_focus_visual() -> void:
	for i in _buttons.size():
		var btn := _buttons[i]
		if i == _focus_index:
			btn.add_theme_color_override("font_color", GOLD)
		else:
			btn.add_theme_color_override("font_color", WARM)


func _frame_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(20)
	return sb
