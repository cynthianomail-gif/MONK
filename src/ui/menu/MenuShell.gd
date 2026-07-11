extends CanvasLayer
## 選單外殼：手機（入世）× 經書（出世）兩裝置。本輪經書做實、手機放空殼。
## 由 MapScreen 探索中按 open_menu 開啟；暫停地圖；cancel 關閉。
## 美術＝暗金×黑程式佔位框（經書材質正式圖之後抽換）。

const SkillsPage := preload("res://src/ui/menu/pages/SkillsPage.gd")
const StatusPage := preload("res://src/ui/menu/pages/StatusPage.gd")
const EquipPage := preload("res://src/ui/menu/pages/EquipPage.gd")
const QuestsApp := preload("res://src/ui/menu/pages/QuestsApp.gd")
const IntelApp := preload("res://src/ui/menu/pages/IntelApp.gd")
const TravelApp := preload("res://src/ui/menu/pages/TravelApp.gd")
const JobApp := preload("res://src/ui/menu/pages/JobApp.gd")
const BoardApp := preload("res://src/ui/menu/pages/BoardApp.gd")
const SettingsApp := preload("res://src/ui/menu/pages/SettingsApp.gd")
const HelpApp := preload("res://src/ui/menu/pages/HelpApp.gd")

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
			{"title": "佛具", "factory": func() -> Control: return EquipPage.new()},
		]},
		"phone": {"name": "手機", "pages": [
			{"title": "任務", "factory": func() -> Control: return QuestsApp.new()},
			{"title": "情報", "factory": func() -> Control: return IntelApp.new()},
			{"title": "移動", "factory": func() -> Control: return TravelApp.new()},
			{"title": "打工", "factory": func() -> Control: return JobApp.new()},
			{"title": "修行", "factory": func() -> Control: return BoardApp.new()},
			{"title": "設定", "factory": func() -> Control: return SettingsApp.new()},
			{"title": "說明", "factory": func() -> Control: return HelpApp.new()},
		]},
	}
	_build()
	_show_device(_current_device)

func close() -> void:
	AudioManager.play_sfx("ui_cancel")
	if pause_game:
		get_tree().paused = false
	queue_free()

## B-2（2026-07-10）：全鍵盤操作。裝置切換（經書↔手機）＝[ / ]；頁籤切換＝ui_left/ui_right；
## 內容區導航沿用 Godot 內建 focus 系統（ui_up/ui_down/ui_accept 天然生效，見 _wire_content_focus）。
## 不用 Tab 做切換：DialogueHistoryPanel 全域常駐監聽 Tab，避免搶鍵（見 _kb_nav_survey.md 第 3/7 項）。
## [ / ] 用直接 keycode 判斷（非 InputMap action）：cam_left/cam_right 這組 action 只在
## CameraRig._ready() 執行期註冊，MenuShell 可能在 CameraRig 不存在的場景/測試下獨立開啟，
## 依賴該 action 存在會是隱性跨檔耦合，直接判鍵碼更穩妥、也不需要動 project.godot。
## 2026-07-10 review 退回修正（F1）：裝置切換原本用 Q/E，與「interact」action（E 鍵，見
## project.godot:158-163）撞鍵——手機「修行」頁（BoardApp）用 E 長按灌注解鎖，第一下 E 會被
## 這裡先攔截切裝置，摧毀修行盤節點，長按永遠打不完。改用不與任何既有 action/鍵位重疊的
## [ / ]（bracket），CameraRig 的 Q/E 轉視角（D-1，地圖場景另一個獨立情境）不受影響、未改動。
func _input(event: InputEvent) -> void:
	# 2026-07-11（設定頁「儲存」／「回主選單」）：SaveSlotPicker／ExitConfirmDialog 疊在
	# MenuShell 上層開啟時整組讓出鍵盤——它們是後補到 get_tree().root 的兄弟節點，_input()
	# 呼叫順序（同優先度時依場景樹序）比埋在 MapScreen 底下較早的 MenuShell 晚，若不讓出，
	# MenuShell 這裡的 set_input_as_handled() 會搶先吃掉 Esc/方向鍵/Enter，overlay 收不到。
	if get_tree().get_first_node_in_group("modal_overlay") != null:
		return
	if event.is_action_pressed("cancel") or event.is_action_pressed("open_menu"):
		get_viewport().set_input_as_handled()
		close()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_BRACKETLEFT:
			get_viewport().set_input_as_handled()
			_cycle_device(-1)
			return
		elif event.physical_keycode == KEY_BRACKETRIGHT:
			get_viewport().set_input_as_handled()
			_cycle_device(1)
			return
	# 2026-07-10 review 退回修正（F2）：ui_left/ui_right 原本無條件攔截給頁籤切換用，導致設定頁
	# 4 個 HSlider 永遠無法用左右鍵調值（_input 先於 GUI 派發，這裡 set_input_as_handled() 之後
	# 事件根本到不了聚焦中的滑桿，見 LayoutTuner.gd:76-79 對這個引擎階段順序的既有查證）。
	# 焦點在 Range（HSlider 等）上時直接 return、不消費事件，讓它照 Godot 內建 GUI 階段的
	# 方向鍵調值邏輯繼續走；焦點不在 Range 上（按鈕/清單列）才輪到這裡切頁籤。
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		if get_viewport().gui_get_focus_owner() is Range:
			return
	if event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_cycle_tab(-1)
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_cycle_tab(1)
	elif _scroll_fallback != null and is_instance_valid(_scroll_fallback):
		# 純顯示頁（無可聚焦控件，如情報/說明）：ui_up/ui_down 直接捲動內容，方向鍵才不會「看起來沒反應」。
		if event.is_action_pressed("ui_down"):
			get_viewport().set_input_as_handled()
			_scroll_fallback.scroll_vertical += 60
		elif event.is_action_pressed("ui_up"):
			get_viewport().set_input_as_handled()
			_scroll_fallback.scroll_vertical -= 60

## 裝置清單固定順序（Dictionary 於 Godot 4 保留插入序＝book, phone），[ / ] 循環切換。
func _cycle_device(dir: int) -> void:
	var ids: Array = _devices.keys()
	var idx: int = ids.find(_current_device)
	if idx == -1:
		return
	idx = (idx + dir + ids.size()) % ids.size()
	_show_device(ids[idx])

func _cycle_tab(dir: int) -> void:
	var pages: Array = _devices[_current_device].pages
	if pages.is_empty():
		return
	var idx: int = (_current_page + dir + pages.size()) % pages.size()
	_show_page(idx)

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

	# 底部提示（B-2：補上鍵盤操作說明——[/] 切裝置、←/→ 切頁籤、↑/↓+Enter 操作內容）
	var hint := Label.new()
	hint.text = "M/Esc 關閉　｜　[ / ] 切裝置　←/→ 切頁籤　↑/↓ 選擇　Enter 確認"
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
	if id != _current_device:
		AudioManager.play_sfx("ui_select")
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
	if idx != _current_page:
		AudioManager.play_sfx("ui_select", 1.08)
	_current_page = idx
	for c in _content.get_children():
		c.queue_free()
	var pages: Array = _devices[_current_device].pages
	if idx < 0 or idx >= pages.size():
		return
	var page: Control = pages[idx].factory.call()
	_content.add_child(page)
	_refresh_tabs()
	_wire_content_focus(page)

## B-2（2026-07-10）：換頁後把內容區所有可互動控件（Button/HSlider/CheckButton...）串成
## 一條上下 focus_neighbor 鏈並讓第一個取得焦點，讓 ui_up/ui_down/ui_accept 天然可操作。
## 頁面全是 ScrollContainer+VBoxContainer 縱向排列（各 App 既有慣例），DOM 序＝視覺上下序，
## 直接依收集順序串鏈即可，不需要另外算座標。純顯示頁（IntelApp/HelpApp）沒有可聚焦控件時，
## 改把方向鍵交給頁面的 ScrollContainer 捲動（_scroll_fallback 記下該頁的 ScrollContainer）。
var _focus_chain: Array = []
var _scroll_fallback: ScrollContainer = null

func _wire_content_focus(page: Control) -> void:
	_focus_chain.clear()
	_scroll_fallback = null
	_collect_focusables(page, _focus_chain)
	var scroll: ScrollContainer = _find_scroll_container(page)
	for i in _focus_chain.size():
		var ctl: Control = _focus_chain[i]
		ctl.focus_mode = Control.FOCUS_ALL
		var prev: Control = _focus_chain[(i - 1 + _focus_chain.size()) % _focus_chain.size()]
		var nxt: Control = _focus_chain[(i + 1) % _focus_chain.size()]
		ctl.focus_neighbor_top = ctl.get_path_to(prev)
		ctl.focus_neighbor_bottom = ctl.get_path_to(nxt)
		ctl.focus_previous = ctl.get_path_to(prev)
		ctl.focus_next = ctl.get_path_to(nxt)
		# 換頁/清單重建後控件是全新節點，focus_entered 沒有殘留連線可疑——這裡是新掛的，
		# 確保 ScrollContainer 捲動跟著焦點走（ScrollContainer 內建行為在部分版面不保證觸發，
		# 這裡顯式呼叫較保險，見 _kb_nav_survey.md 第 2 項風險備註）。
		if scroll != null:
			ctl.focus_entered.connect(_safe_ensure_visible.bind(scroll, ctl))
	if not _focus_chain.is_empty():
		_focus_chain[0].call_deferred("grab_focus")
	else:
		_scroll_fallback = scroll

## 2026-07-10 review 退回修正（F4）：ensure_control_visible 前置守衛。原本直接 bind
## scroll.ensure_control_visible(ctl) 在換頁時序競態下（舊頁 queue_free() 與新頁
## call_deferred grab_focus 交錯）偶發 "Must be an ancestor of the control."，因為被叫到的
## 控件當下已不是該 ScrollContainer 的子孫。這裡呼叫前先驗證雙方仍有效且真的是祖先/子孫
## 關係，任一條件不成立就靜默跳過（不影響操作，只是不強制捲動可見）。
func _safe_ensure_visible(scroll: ScrollContainer, ctl: Control) -> void:
	if is_instance_valid(scroll) and is_instance_valid(ctl) and scroll.is_ancestor_of(ctl):
		scroll.ensure_control_visible(ctl)

func _collect_focusables(node: Node, out: Array) -> void:
	if node is Button or node is HSlider or node is CheckButton:
		out.append(node)
	for c in node.get_children():
		_collect_focusables(c, out)

func _find_scroll_container(node: Node) -> ScrollContainer:
	if node is ScrollContainer:
		return node
	for c in node.get_children():
		var found := _find_scroll_container(c)
		if found != null:
			return found
	return null

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
