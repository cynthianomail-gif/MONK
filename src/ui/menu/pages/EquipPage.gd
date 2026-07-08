extends Control
## 經書「佛具」頁（2026-07-08，第五期）：三欄現況＋該欄持有清單＋裝上/卸下＋三圍加成即時預覽。
## 內容仿 QuestsApp/HelpApp 風格：ScrollContainer + 分節 PanelContainer，避免撐爆 MenuShell
## 內容區（實際可用高 ~570，07-07 BoardApp 已踩過固定高度撐爆的坑）。

const GOLD := Color(0.788, 0.659, 0.38)
const WARM := Color(0.92, 0.89, 0.82)
const DIM := Color(0.5, 0.47, 0.42)
const NEAR_BLACK := Color(0.043, 0.043, 0.043, 1.0)

const SLOT_NAMES := {"beads": "念珠", "kasaya": "袈裟", "bowl": "缽"}
const SLOT_ORDER := ["beads", "kasaya", "bowl"]

var _preview_box: VBoxContainer
var _slot_boxes: Dictionary = {}   # slot -> VBoxContainer（供刷新）

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 18)
	scroll.add_child(col)

	col.add_child(_heading("三圍加成"))
	_preview_box = VBoxContainer.new()
	_preview_box.add_theme_constant_override("separation", 6)
	col.add_child(_panel_wrap(_preview_box))

	for slot in SLOT_ORDER:
		col.add_child(_heading(SLOT_NAMES[slot]))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		_slot_boxes[slot] = box
		col.add_child(_panel_wrap(box))

	_refresh()

func _refresh() -> void:
	_refresh_preview()
	for slot in SLOT_ORDER:
		_refresh_slot(slot)

func _refresh_preview() -> void:
	for c in _preview_box.get_children():
		c.queue_free()
	var bonus: Dictionary = EquipmentSystem.compute_bonus()
	var lines := [
		"攻擊 +%d" % int(bonus.get("atk", 0)),
		"防禦 +%d" % int(bonus.get("def", 0)),
		"HP +%d" % int(bonus.get("hp", 0)),
	]
	var gold_pct: float = float(bonus.get("gold_pct", 0.0))
	if gold_pct > 0.0:
		lines.append("戰勝金幣 +%d%%" % int(round(gold_pct * 100.0)))
	var merit_per_win: int = int(bonus.get("merit_per_win", 0))
	if merit_per_win > 0:
		lines.append("每勝功德 +%d" % merit_per_win)
	for l in lines:
		_preview_box.add_child(_line(l))

func _refresh_slot(slot: String) -> void:
	var box: VBoxContainer = _slot_boxes[slot]
	for c in box.get_children():
		c.queue_free()

	var equipped: String = EquipmentSystem.get_equipped(slot)
	var equipped_lbl := Label.new()
	equipped_lbl.text = "現裝：%s" % (EquipmentSystem.get_item_def(equipped).get("name", "無") if equipped != "" else "無")
	equipped_lbl.add_theme_color_override("font_color", GOLD)
	equipped_lbl.add_theme_font_size_override("font_size", 20)
	box.add_child(equipped_lbl)

	var owned: Array = EquipmentSystem.owned_in_slot(slot)
	if owned.is_empty():
		var hint := Label.new()
		hint.text = "尚未持有此欄佛具（水野佛具店可購入）。"
		hint.add_theme_color_override("font_color", DIM)
		hint.add_theme_font_size_override("font_size", 18)
		box.add_child(hint)
		return

	for item_id in owned:
		box.add_child(_item_row(slot, item_id, item_id == equipped))

	if equipped != "":
		var unequip_btn := Button.new()
		unequip_btn.text = "卸下"
		unequip_btn.add_theme_font_size_override("font_size", 20)
		var s: String = slot
		unequip_btn.pressed.connect(func() -> void: _on_unequip(s))
		box.add_child(unequip_btn)

func _item_row(slot: String, item_id: String, is_equipped: bool) -> Control:
	var d: Dictionary = EquipmentSystem.get_item_def(item_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl := Label.new()
	name_lbl.text = String(d.get("name", item_id)) + ("　（裝備中）" if is_equipped else "")
	name_lbl.add_theme_color_override("font_color", WARM if not is_equipped else GOLD)
	name_lbl.add_theme_font_size_override("font_size", 20)
	info.add_child(name_lbl)
	var desc_lbl := Label.new()
	desc_lbl.text = String(d.get("desc", ""))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", DIM)
	desc_lbl.add_theme_font_size_override("font_size", 16)
	info.add_child(desc_lbl)
	row.add_child(info)

	if not is_equipped:
		var equip_btn := Button.new()
		equip_btn.text = "裝上"
		equip_btn.add_theme_font_size_override("font_size", 20)
		var iid: String = item_id
		equip_btn.pressed.connect(func() -> void: _on_equip(iid))
		row.add_child(equip_btn)

	return row

func _on_equip(item_id: String) -> void:
	if EquipmentSystem.equip(item_id):
		AudioManager.play_sfx("ui_select")
		_refresh()

func _on_unequip(slot: String) -> void:
	EquipmentSystem.unequip(slot)
	AudioManager.play_sfx("ui_select")
	_refresh()

func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", GOLD)
	l.add_theme_font_size_override("font_size", 24)
	return l

func _line(text: String) -> Label:
	var l := Label.new()
	l.text = "· " + text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", WARM)
	l.add_theme_font_size_override("font_size", 20)
	return l

func _panel_wrap(content: Control) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = NEAR_BLACK
	sb.border_color = GOLD.darkened(0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(16)
	pc.add_theme_stylebox_override("panel", sb)
	pc.add_child(content)
	return pc
