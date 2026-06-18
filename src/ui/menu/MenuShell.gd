extends CanvasLayer
## 選單外殼：手機（入世）× 經書（出世）兩裝置。本輪經書做實、手機放空殼。
## 由 MapScreen 探索中按 open_menu 開啟；暫停地圖；cancel 關閉。
## 美術＝暗金×黑程式佔位框（經書材質正式圖之後抽換）。

const SkillsPage := preload("res://src/ui/menu/pages/SkillsPage.gd")
const StatusPage := preload("res://src/ui/menu/pages/StatusPage.gd")
const QuestsApp := preload("res://src/ui/menu/pages/QuestsApp.gd")
const IntelApp := preload("res://src/ui/menu/pages/IntelApp.gd")
const TravelApp := preload("res://src/ui/menu/pages/TravelApp.gd")
const JobApp := preload("res://src/ui/menu/pages/JobApp.gd")
const SettingsApp := preload("res://src/ui/menu/pages/SettingsApp.gd")

const GOLD := Color(0.788, 0.659, 0.38)
const NEAR_BLACK := Color(0.043, 0.043, 0.043, 0.97)
const PANEL_BG := Color(0.08, 0.075, 0.07, 1.0)
const WARM := Color(0.92, 0.89, 0.82)
const DIM := Color(0.55, 0.52, 0.46)

@export var pause_game: bool = true   # 測試時設 false

var _devices: Dictionary = {}
var _current_device: String = "book"
var _current_page: int = 0
var _device_row: HBoxContainer
var _tab_row: HBoxContainer
var _content: PanelContainer
var _title_label: Label

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("menu_shell")  # 供頁面（如任務 app）取得外殼以 close()
	# 可學招紅點：習得（skill_unlocked）或新可學（skill_learnable）時即時刷新裝置鈕/頁籤紅點。
	EventBus.skill_unlocked.connect(func(_n): _refresh_badges())
	EventBus.skill_learnable.connect(func(_n): _refresh_badges())
	if pause_game:
		get_tree().paused = true
	_devices = {
		"book": {"name": "經書", "pages": [
			{"title": "技能", "factory": func() -> Control: return SkillsPage.new()},
			{"title": "狀態", "factory": func() -> Control: return StatusPage.new()},
		]},
		"phone": {"name": "手機", "pages": [
			{"title": "任務", "factory": func() -> Control: return QuestsApp.new()},
			{"title": "情報", "factory": func() -> Control: return IntelApp.new()},
			{"title": "移動", "factory": func() -> Control: return TravelApp.new()},
			{"title": "打工", "factory": func() -> Control: return JobApp.new()},
			{"title": "設定", "factory": func() -> Control: return SettingsApp.new()},
		]},
	}
	_build()
	_show_device(_current_device)

func close() -> void:
	if pause_game:
		get_tree().paused = false
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel") or event.is_action_pressed("open_menu"):
		get_viewport().set_input_as_handled()
		close()

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(1440, 820)
	panel.add_theme_stylebox_override("panel", _frame_style(PANEL_BG, GOLD, 3))
	# 置中
	panel.anchor_left = 0.5; panel.anchor_top = 0.5
	panel.anchor_right = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -720; panel.offset_top = -410
	panel.offset_right = 720; panel.offset_bottom = 410
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	# 標題列：經書 ｜ 手機（裝置切換）
	_device_row = HBoxContainer.new()
	_device_row.add_theme_constant_override("separation", 8)
	root.add_child(_device_row)

	root.add_child(_hsep())

	# 頁籤列
	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override("separation", 8)
	root.add_child(_tab_row)

	# 內容
	_content = PanelContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_stylebox_override("panel", _frame_style(NEAR_BLACK, GOLD.darkened(0.3), 1))
	root.add_child(_content)

	# 底部提示
	var hint := Label.new()
	hint.text = "[M] / Esc 關閉"
	hint.add_theme_color_override("font_color", DIM)
	hint.add_theme_font_size_override("font_size", 20)
	root.add_child(hint)

func _refresh_device_row() -> void:
	for c in _device_row.get_children():
		c.queue_free()
	var has_learn: bool = SkillUnlockManager.learnable_skills().size() > 0
	for id in _devices:
		var btn := Button.new()
		btn.text = _devices[id].name
		btn.add_theme_font_size_override("font_size", 30)
		btn.toggle_mode = true
		btn.button_pressed = (id == _current_device)
		btn.add_theme_color_override("font_color", GOLD if id == _current_device else DIM)
		var dev_id: String = id
		btn.pressed.connect(func() -> void: _show_device(dev_id))
		_device_row.add_child(btn)
		if id == "book" and has_learn:
			_attach_badge(btn)  # 經書有可學的招

func _show_device(id: String) -> void:
	_current_device = id
	_current_page = 0
	_refresh_device_row()
	_refresh_tabs()
	_show_page(0)

func _refresh_tabs() -> void:
	for c in _tab_row.get_children():
		c.queue_free()
	var has_learn: bool = SkillUnlockManager.learnable_skills().size() > 0
	var pages: Array = _devices[_current_device].pages
	for i in pages.size():
		var btn := Button.new()
		btn.text = pages[i].title
		btn.add_theme_font_size_override("font_size", 24)
		btn.add_theme_color_override("font_color", WARM if i == _current_page else DIM)
		var idx: int = i
		btn.pressed.connect(func() -> void: _show_page(idx))
		_tab_row.add_child(btn)
		if pages[i].title == "技能" and has_learn:
			_attach_badge(btn)  # 技能頁有可學的招

func _show_page(idx: int) -> void:
	_current_page = idx
	for c in _content.get_children():
		c.queue_free()
	var pages: Array = _devices[_current_device].pages
	if idx < 0 or idx >= pages.size():
		return
	var page: Control = pages[idx].factory.call()
	_content.add_child(page)
	_refresh_tabs()

## 重畫裝置鈕/頁籤的「可學」紅點（習得後即時清掉）。內容頁不動。
func _refresh_badges() -> void:
	if not is_instance_valid(_device_row):
		return
	_refresh_device_row()
	_refresh_tabs()

## 在按鈕右上角掛一顆紅點。命名 LearnBadge 供測試/清除辨識。
func _attach_badge(parent: Control) -> void:
	var dot := Label.new()
	dot.name = "LearnBadge"
	dot.text = "●"
	dot.add_theme_color_override("font_color", Color(0.85, 0.22, 0.18))
	dot.add_theme_font_size_override("font_size", 16)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dot.offset_left = -18
	dot.offset_top = -2
	dot.offset_right = -2
	dot.offset_bottom = 18
	parent.add_child(dot)

func _frame_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(20)
	return sb

func _hsep() -> Control:
	var line := ColorRect.new()
	line.color = GOLD.darkened(0.4)
	line.custom_minimum_size = Vector2(0, 2)
	return line
