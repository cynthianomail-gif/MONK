extends CanvasLayer
## 水野佛具店：消耗道具＋佛具裝備商店 overlay（DEMO）。
## 仿 MenuShell：layer=100、process_mode ALWAYS、暫停地圖、cancel 關閉、暗金×黑框。
## 由 MapScreen 的 shop 動作開啟（已 gate zheng_ma_shop_unlocked）。時段推進由
## MapScreen.perform_action 開頭統一處理，本檔不碰時間。
##
## 2026-07-08 佛具裝備位（第五期）：加「消耗品／佛具」分頁。佛具分頁只列已達進貨門檻
## 的品項（EquipmentSystem.is_unlocked）；已持有顯示「已購入」灰置（每件限購一次）；
## 佛具購買不進 inventory（EquipmentSystem.purchase），不會混入戰鬥道具選單。

const GOLD := Color(0.788, 0.659, 0.38)
const NEAR_BLACK := Color(0.043, 0.043, 0.043, 0.97)
const PANEL_BG := Color(0.08, 0.075, 0.07, 1.0)
const WARM := Color(0.92, 0.89, 0.82)
const DIM := Color(0.55, 0.52, 0.46)
const PRICE_COL := Color(0.85, 0.78, 0.5)
const ITEMS_PATH := "res://data/items.json"

const TABS := ["消耗品", "佛具"]

@export var pause_game: bool = true   # 測試時設 false

var _items: Dictionary = {}
var _equipment: Dictionary = {}
var _rows: Dictionary = {}        # item_id -> Button
var _detail_box: VBoxContainer
var _gold_label: Label
var _selected: String = ""
var _current_tab: int = 0
var _list: VBoxContainer
var _tab_row: HBoxContainer

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	if pause_game:
		get_tree().paused = true
	_items = JsonLoader.load_json(ITEMS_PATH)
	_equipment = EquipmentSystem.get_items()
	_build()

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
	panel.anchor_left = 0.5; panel.anchor_top = 0.5
	panel.anchor_right = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -720; panel.offset_top = -410
	panel.offset_right = 720; panel.offset_bottom = 410
	panel.add_theme_stylebox_override("panel", _frame_style(PANEL_BG, GOLD, 3))
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	# 標題列：店名 + 金幣
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "水野佛具店"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 26)
	_gold_label.add_theme_color_override("font_color", PRICE_COL)
	header.add_child(_gold_label)

	root.add_child(_hsep())

	# 分頁列：消耗品／佛具
	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override("separation", 8)
	root.add_child(_tab_row)
	_refresh_tabs()

	var hb := HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 24)
	root.add_child(hb)

	# 左：道具清單
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	# 右：詳情
	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", _frame_style(NEAR_BLACK, GOLD.darkened(0.3), 1))
	hb.add_child(detail_panel)
	_detail_box = VBoxContainer.new()
	_detail_box.add_theme_constant_override("separation", 10)
	detail_panel.add_child(_detail_box)

	# 底部提示
	var hint := Label.new()
	hint.text = "Esc 離開"
	hint.add_theme_color_override("font_color", DIM)
	hint.add_theme_font_size_override("font_size", 20)
	root.add_child(hint)

	_refresh_gold()
	_show_tab(0)

func _refresh_tabs() -> void:
	for c in _tab_row.get_children():
		c.queue_free()
	for i in TABS.size():
		var btn := Button.new()
		btn.text = TABS[i]
		btn.add_theme_font_size_override("font_size", 24)
		btn.add_theme_color_override("font_color", GOLD if i == _current_tab else DIM)
		var idx: int = i
		btn.pressed.connect(func() -> void: _show_tab(idx))
		_tab_row.add_child(btn)

func _show_tab(idx: int) -> void:
	_current_tab = idx
	_selected = ""
	_refresh_tabs()
	_rebuild_list()
	_show_detail("")

func _rebuild_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	_rows.clear()
	if _current_tab == 0:
		for id in _items:
			_list.add_child(_item_row(id, false))
	else:
		for id in _equipment:
			if not EquipmentSystem.is_unlocked(id):
				continue  # 未達進貨門檻的不顯示（不劇透）
			_list.add_child(_item_row(id, true))

func _item_row(id: String, is_equip: bool) -> Button:
	var btn := Button.new()
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 22)
	var iid: String = id
	btn.pressed.connect(func() -> void: _select(iid))
	_rows[id] = btn
	_style_row(id, is_equip)
	return btn

func _style_row(id: String, is_equip: bool) -> void:
	var btn: Button = _rows[id]
	if is_equip:
		var d: Dictionary = _equipment[id]
		var owned: bool = EquipmentSystem.is_owned(id)
		btn.text = "%s　%d 金　%s" % [d.get("name", id), int(d.get("price", 0)), "（已購入）" if owned else ""]
		btn.add_theme_color_override("font_color", DIM if owned else WARM)
	else:
		var d: Dictionary = _items[id]
		btn.text = "%s　%d 金　(持有 ×%d)" % [d.get("name", id), int(d.get("price", 0)), GameManager.item_count(id)]
		btn.add_theme_color_override("font_color", WARM)

func _select(id: String) -> void:
	_selected = id
	_show_detail(id)

func _show_detail(id: String) -> void:
	for c in _detail_box.get_children():
		c.queue_free()
	if id == "":
		var hint := Label.new()
		hint.text = "選擇左側道具以檢視詳情。"
		hint.add_theme_color_override("font_color", DIM)
		hint.add_theme_font_size_override("font_size", 22)
		_detail_box.add_child(hint)
		return
	if _current_tab == 1:
		_show_equipment_detail(id)
		return
	var d: Dictionary = _items[id]
	_add_label(d.get("name", id), 34, GOLD)
	var desc := _add_label(d.get("desc", ""), 22, WARM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(640, 0)
	_add_label("價格：%d 金" % int(d.get("price", 0)), 22, PRICE_COL)
	_add_label("持有：×%d" % GameManager.item_count(id), 20, DIM)
	var buy := Button.new()
	buy.text = "購買"
	buy.add_theme_font_size_override("font_size", 24)
	buy.disabled = GameManager.player.gold < int(d.get("price", 0))
	var iid: String = id
	buy.pressed.connect(func() -> void: _on_buy(iid))
	_detail_box.add_child(buy)

func _show_equipment_detail(id: String) -> void:
	var d: Dictionary = _equipment[id]
	_add_label(d.get("name", id), 34, GOLD)
	var desc := _add_label(d.get("desc", ""), 22, WARM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(640, 0)
	_add_label("價格：%d 金" % int(d.get("price", 0)), 22, PRICE_COL)
	var owned: bool = EquipmentSystem.is_owned(id)
	if owned:
		_add_label("已購入（每件限購一次，於經書「佛具」頁換裝）", 20, DIM)
	else:
		var buy := Button.new()
		buy.text = "購買"
		buy.add_theme_font_size_override("font_size", 24)
		buy.disabled = GameManager.player.gold < int(d.get("price", 0))
		var iid: String = id
		buy.pressed.connect(func() -> void: _on_buy_equipment(iid))
		_detail_box.add_child(buy)

func _on_buy(id: String) -> void:
	var price: int = int(_items[id].get("price", 0))
	if not GameManager.spend_gold(price):
		return
	GameManager.add_item(id)
	AudioManager.play_sfx("gold_collect")
	_style_row(id, false)
	_refresh_gold()
	_show_detail(id)

func _on_buy_equipment(id: String) -> void:
	if not EquipmentSystem.purchase(id):
		return
	AudioManager.play_sfx("gold_collect")
	_style_row(id, true)
	_refresh_gold()
	_show_detail(id)

func _refresh_gold() -> void:
	_gold_label.text = "金幣：%d" % GameManager.player.gold

func _add_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_detail_box.add_child(l)
	return l

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
