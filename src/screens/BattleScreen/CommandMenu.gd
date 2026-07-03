class_name CommandMenu
extends Control

## 主指令選單（第一期，貼玩家立繪右側）：縱向斜切按鈕（skew -10°）。
## 五項：攻擊／技能／防禦／道具／護法。選中放大＋位移＋朱紅底；未選深灰。
## 鍵盤上下＋interact(E) 確認，滑鼠可點。出現時從左滑入 0.15s。
## 純 Control+Tween，不新增圖片素材。護法為第四期接點（顯示但灰置）。

signal command_chosen(cmd: String)   # "attack" | "skill" | "defend" | "item" | "summon"

const INK_RED := Color("#C93A2E")
const GOLD := Color(0.788, 0.659, 0.38)
const SKEW := deg_to_rad(-10.0)

const COMMANDS := [
	{"id": "attack", "label": "攻擊"},
	{"id": "skill",  "label": "技能"},
	{"id": "defend", "label": "防禦"},
	{"id": "item",   "label": "道具"},
	{"id": "summon", "label": "護法"},  # 第四期接點
]

var _rows: Array = []          # Array[PanelContainer]
var _selected: int = 0
var _active: bool = false
var _disabled: Dictionary = {}  # cmd_id → true 表示灰置不可選

var _vbox: VBoxContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = false
	set_process_input(false)

func _build() -> void:
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 8)
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vbox)
	_rows.clear()
	for i in COMMANDS.size():
		var cmd: Dictionary = COMMANDS[i]
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(230, 52)
		row.pivot_offset = Vector2(0, 26)
		row.set("theme_override_styles/panel", _row_style(false))
		# 斜切：整列做 skew（用 Transform2D via material 不便，改用 rotation 近似不行；
		# Godot Control 無直接 skew，故以「內部 Label 斜切」＋外框 stylebox 表現斜角）
		var lbl := Label.new()
		lbl.text = cmd.label
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 26)
		lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.72))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 斜切字：用 material skew（Label 支援 rotation，斜切以 pivot+shear 近似 → 用旋轉不合適）
		# 這裡以 Control 的 material shader 過重；改用 transform：把 label 放進一個帶 skew 的容器。
		var skewer := Control.new()
		skewer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		skewer.set_anchors_preset(Control.PRESET_FULL_RECT)
		skewer.add_child(lbl)
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.add_child(skewer)
		# 用滑鼠 Button 覆蓋整列做點擊 + hover
		var btn := Button.new()
		btn.flat = true
		btn.modulate = Color(1, 1, 1, 0)
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.pressed.connect(_on_row_pressed.bind(i))
		btn.mouse_entered.connect(func(): _hover(i))
		row.add_child(btn)
		row.set_meta("label", lbl)
		row.set_meta("btn", btn)
		_vbox.add_child(row)
		_rows.append(row)

func _row_style(selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.skew = Vector2(0.176, 0.0)   # tan(10°)≈0.176 → 斜切外框（第一期 skew -10°視覺）
	sb.set_corner_radius_all(4)
	if selected:
		sb.bg_color = INK_RED
		sb.set_border_width_all(2)
		sb.border_color = GOLD
	else:
		sb.bg_color = Color(0.12, 0.12, 0.13, 0.92)
		sb.set_border_width_all(1)
		sb.border_color = Color(0.3, 0.3, 0.32)
	sb.set_content_margin_all(6)
	return sb

## 顯示選單並啟用輸入。disabled_cmds：要灰置的指令 id 陣列（如無護法時 ["summon"]）。
func open_menu(disabled_cmds: Array = []) -> void:
	_disabled.clear()
	for d in disabled_cmds:
		_disabled[d] = true
	_selected = _first_enabled()
	_active = true
	visible = true
	set_process_input(true)
	_refresh()
	_slide_in()

func close_menu() -> void:
	_active = false
	visible = false
	set_process_input(false)

func _first_enabled() -> int:
	for i in COMMANDS.size():
		if not _disabled.get(COMMANDS[i].id, false):
			return i
	return 0

func _slide_in() -> void:
	var target := position
	position = target - Vector2(120, 0)
	modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", target, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.15)

func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_down"):
		_move(1)
		accept_event()
	elif event.is_action_pressed("ui_up"):
		_move(-1)
		accept_event()
	elif event.is_action_pressed("interact") or event.is_action_pressed("confirm"):
		_confirm()
		accept_event()

func _move(dir: int) -> void:
	var n: int = COMMANDS.size()
	var i: int = _selected
	for _k in n:
		i = (i + dir + n) % n
		if not _disabled.get(COMMANDS[i].id, false):
			_selected = i
			break
	_refresh()

func _hover(i: int) -> void:
	if _disabled.get(COMMANDS[i].id, false):
		return
	_selected = i
	_refresh()

func _on_row_pressed(i: int) -> void:
	if _disabled.get(COMMANDS[i].id, false):
		return
	_selected = i
	_refresh()
	_confirm()

func _confirm() -> void:
	var cmd: String = COMMANDS[_selected].id
	if _disabled.get(cmd, false):
		return
	command_chosen.emit(cmd)

func _refresh() -> void:
	for i in _rows.size():
		var row: PanelContainer = _rows[i]
		var cmd: Dictionary = COMMANDS[i]
		var is_sel: bool = (i == _selected)
		var is_dis: bool = _disabled.get(cmd.id, false)
		row.set("theme_override_styles/panel", _row_style(is_sel and not is_dis))
		var lbl: Label = row.get_meta("label")
		if is_dis:
			lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.42))
		else:
			lbl.add_theme_color_override("font_color", Color(0.98, 0.98, 0.95) if is_sel else Color(0.72, 0.72, 0.74))
		# 選中放大＋位移
		var tw := row.create_tween()
		var target_scale := Vector2(1.12, 1.12) if (is_sel and not is_dis) else Vector2.ONE
		var target_x := 14.0 if (is_sel and not is_dis) else 0.0
		row.pivot_offset = Vector2(0, row.size.y * 0.5)
		tw.set_parallel(true)
		tw.tween_property(row, "scale", target_scale, 0.1)
		tw.tween_property(row, "position:x", target_x, 0.1)
