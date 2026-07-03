extends Control
## 手機「修行」app：修行盤（人龍0 式圓盤成長，第三期）。
## 極座標佈局：核心置中，環依 radius 畫同心圓；節點依 angle_deg 排列；requires 畫成邊線。
## 節點四態：已解鎖(朱紅實心) / 可解鎖(金框+花費) / 未達前置(灰框) / 劇情鎖(紫虛線)。
## 選中節點右側面板顯示名稱/效果/花費/前置；按住 E(interact) 0.6s 灌注道行滿→解鎖。
## 純 Control+_draw+Tween，不新增圖片素材。

const INK_RED := Color("#C93A2E")
const GOLD := Color(0.788, 0.659, 0.38)
const WARM := Color(0.92, 0.89, 0.82)
const DIM := Color(0.5, 0.47, 0.42)
const LOCKED_GRAY := Color(0.38, 0.36, 0.33)
const STORY_PURPLE := Color(0.52, 0.36, 0.68)
const NEAR_BLACK := Color(0.043, 0.043, 0.043, 1.0)
const CHARGE_TIME := 0.6

const NODE_RADIUS := 16.0

var _center: Vector2 = Vector2(280, 300)
var _node_positions: Dictionary = {}   # node_id -> Vector2 (相對 _board_holder 原點)
var _selected: String = ""
var _charging: bool = false
var _charge_t: float = 0.0
var _charge_target: String = ""

var _board_holder: Control
var _info_panel: VBoxContainer
var _daoxing_label: Label
var _charge_bar: ProgressBar
var _node_buttons: Dictionary = {}   # node_id -> BaseButton（供測試/hit-test）

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_layout_nodes()
	_refresh()
	set_process(true)

func _build() -> void:
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 20)
	add_child(hb)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 2.0
	hb.add_child(left)

	var head := HBoxContainer.new()
	var title := Label.new()
	title.text = "修行盤"
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_daoxing_label = Label.new()
	_daoxing_label.add_theme_color_override("font_color", WARM)
	_daoxing_label.add_theme_font_size_override("font_size", 24)
	head.add_child(_daoxing_label)
	left.add_child(head)

	_board_holder = Control.new()
	_board_holder.custom_minimum_size = Vector2(560, 600)
	_board_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_holder.draw.connect(_draw_board)
	left.add_child(_board_holder)

	var hint := Label.new()
	hint.text = "點選節點查看詳情；按住 [E] 灌注道行解鎖"
	hint.add_theme_color_override("font_color", DIM)
	hint.add_theme_font_size_override("font_size", 18)
	left.add_child(hint)

	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(320, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = NEAR_BLACK
	sb.border_color = GOLD.darkened(0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(16)
	right.add_theme_stylebox_override("panel", sb)
	hb.add_child(right)

	_info_panel = VBoxContainer.new()
	_info_panel.add_theme_constant_override("separation", 8)
	right.add_child(_info_panel)

## 依環半徑與 angle_deg 算出每個節點的畫面座標（相對 _board_holder 中心）。
func _layout_nodes() -> void:
	_node_positions.clear()
	var rings: Dictionary = {}
	for r in CultivationBoard.get_rings():
		rings[int(r.ring)] = float(r.get("radius", 0.0))
	for n in CultivationBoard.get_nodes():
		var ring_idx: int = int(n.get("ring", 0))
		var radius: float = rings.get(ring_idx, 0.0)
		var angle: float = deg_to_rad(float(n.get("angle_deg", 0.0)))
		var pos := _center + Vector2(cos(angle), sin(angle)) * radius
		_node_positions[String(n.id)] = pos
	_ensure_node_buttons()

## 每個節點建一個透明按鈕覆蓋，供滑鼠點選（畫面本體用 _draw 畫視覺）。
func _ensure_node_buttons() -> void:
	for c in _node_buttons.values():
		if is_instance_valid(c):
			c.queue_free()
	_node_buttons.clear()
	for node_id in _node_positions:
		var pos: Vector2 = _node_positions[node_id]
		var btn := Button.new()
		btn.flat = true
		btn.modulate = Color(1, 1, 1, 0)
		btn.position = pos - Vector2(NODE_RADIUS, NODE_RADIUS)
		btn.size = Vector2(NODE_RADIUS * 2, NODE_RADIUS * 2)
		var nid: String = node_id
		btn.pressed.connect(func() -> void: select_node(nid))
		_board_holder.add_child(btn)
		_node_buttons[node_id] = btn

func _draw_board() -> void:
	# 畫環
	for r in CultivationBoard.get_rings():
		var radius: float = float(r.get("radius", 0.0))
		if radius <= 0.0:
			continue
		var flag: String = String(r.get("unlock_flag", ""))
		var col: Color = STORY_PURPLE.darkened(0.3) if (flag != "" and not GameManager.get_flag(flag)) else GOLD.darkened(0.55)
		_board_holder.draw_arc(_center, radius, 0, TAU, 64, col, 1.0)

	# 畫 requires 邊
	for n in CultivationBoard.get_nodes():
		var nid: String = String(n.id)
		var to_pos: Vector2 = _node_positions.get(nid, _center)
		for req in n.get("requires", []):
			var from_pos: Vector2 = _node_positions.get(String(req), _center)
			var edge_col: Color = GOLD.darkened(0.35) if CultivationBoard.is_unlocked(nid) else Color(0.3, 0.3, 0.32)
			_board_holder.draw_line(from_pos, to_pos, edge_col, 1.5)

	# 畫節點
	for n in CultivationBoard.get_nodes():
		var nid: String = String(n.id)
		var pos: Vector2 = _node_positions.get(nid, _center)
		var state: String = CultivationBoard.node_state(nid)
		match state:
			"unlocked":
				_board_holder.draw_circle(pos, NODE_RADIUS, INK_RED)
				_board_holder.draw_arc(pos, NODE_RADIUS, 0, TAU, 24, GOLD, 2.0)
			"available":
				_board_holder.draw_arc(pos, NODE_RADIUS, 0, TAU, 24, GOLD, 2.5)
			"story_locked":
				_draw_dashed_circle(pos, NODE_RADIUS, STORY_PURPLE)
			_:  # locked
				_board_holder.draw_arc(pos, NODE_RADIUS, 0, TAU, 24, LOCKED_GRAY, 2.0)
		if nid == _selected:
			_board_holder.draw_arc(pos, NODE_RADIUS + 5.0, 0, TAU, 24, WARM, 1.5)

	# 充能進度環（選中節點灌注中）
	if _charging and _charge_target != "" and _node_positions.has(_charge_target):
		var cpos: Vector2 = _node_positions[_charge_target]
		var frac: float = clampf(_charge_t / CHARGE_TIME, 0.0, 1.0)
		_board_holder.draw_arc(cpos, NODE_RADIUS + 9.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 32, INK_RED, 3.0)

func _draw_dashed_circle(center: Vector2, radius: float, col: Color) -> void:
	var segs := 24
	for i in segs:
		if i % 2 == 0:
			continue
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		_board_holder.draw_arc(center, radius, a0, a1, 4, col, 2.0)

## 選中節點：刷新右側資訊面板＋重繪。供測試直接呼叫。
func select_node(node_id: String) -> void:
	_selected = node_id
	_refresh_info_panel()
	_board_holder.queue_redraw()

func _refresh() -> void:
	_daoxing_label.text = "道行 %d" % int(GameManager.player.get("daoxing", 0))
	_refresh_info_panel()
	if is_instance_valid(_board_holder):
		_board_holder.queue_redraw()

func _refresh_info_panel() -> void:
	for c in _info_panel.get_children():
		c.queue_free()
	if _selected == "":
		var l := Label.new()
		l.text = "選擇一個節點查看詳情"
		l.add_theme_color_override("font_color", DIM)
		l.add_theme_font_size_override("font_size", 20)
		_info_panel.add_child(l)
		return
	var n: Dictionary = CultivationBoard.get_node_def(_selected)
	if n.is_empty():
		return
	var name_lbl := Label.new()
	name_lbl.text = String(n.get("name", _selected))
	name_lbl.add_theme_color_override("font_color", WARM)
	name_lbl.add_theme_font_size_override("font_size", 24)
	_info_panel.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = String(n.get("desc", ""))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", DIM)
	desc_lbl.add_theme_font_size_override("font_size", 18)
	_info_panel.add_child(desc_lbl)

	var state: String = CultivationBoard.node_state(_selected)
	var state_lbl := Label.new()
	state_lbl.add_theme_font_size_override("font_size", 18)
	match state:
		"unlocked":
			state_lbl.text = "已解鎖"
			state_lbl.add_theme_color_override("font_color", INK_RED)
		"available":
			state_lbl.text = "花費 %d 道行" % int(n.get("cost", 0))
			state_lbl.add_theme_color_override("font_color", GOLD)
		"story_locked":
			var ring: Dictionary = _ring_of(_selected)
			state_lbl.text = "劇情鎖：%s 尚未達成" % String(ring.get("unlock_flag", ""))
			state_lbl.add_theme_color_override("font_color", STORY_PURPLE)
		_:
			state_lbl.text = "前置未達"
			state_lbl.add_theme_color_override("font_color", LOCKED_GRAY)
	_info_panel.add_child(state_lbl)

	if not n.get("requires", []).is_empty():
		var req_lbl := Label.new()
		var names: Array = []
		for r in n.requires:
			var rn: Dictionary = CultivationBoard.get_node_def(String(r))
			names.append(String(rn.get("name", r)))
		req_lbl.text = "前置：%s" % ", ".join(names)
		req_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		req_lbl.add_theme_color_override("font_color", DIM)
		req_lbl.add_theme_font_size_override("font_size", 16)
		_info_panel.add_child(req_lbl)

	if state == "available":
		_charge_bar = ProgressBar.new()
		_charge_bar.min_value = 0.0
		_charge_bar.max_value = 1.0
		_charge_bar.value = 0.0
		_charge_bar.show_percentage = false
		_charge_bar.custom_minimum_size = Vector2(0, 18)
		_info_panel.add_child(_charge_bar)
		var cap := Label.new()
		cap.text = "按住 [E] 灌注解鎖"
		cap.add_theme_color_override("font_color", DIM)
		cap.add_theme_font_size_override("font_size", 16)
		_info_panel.add_child(cap)
	else:
		_charge_bar = null

func _ring_of(node_id: String) -> Dictionary:
	var n: Dictionary = CultivationBoard.get_node_def(node_id)
	var ring_idx: int = int(n.get("ring", 0))
	for r in CultivationBoard.get_rings():
		if int(r.get("ring", -1)) == ring_idx:
			return r
	return {}

func _process(delta: float) -> void:
	if _selected == "" or not CultivationBoard.can_unlock(_selected):
		if _charging:
			_stop_charge()
		return
	var pressed: bool = Input.is_action_pressed("interact")
	if pressed:
		if not _charging or _charge_target != _selected:
			_start_charge(_selected)
		_charge_t += delta
		if _charge_bar:
			_charge_bar.value = clampf(_charge_t / CHARGE_TIME, 0.0, 1.0)
		_board_holder.queue_redraw()
		if _charge_t >= CHARGE_TIME:
			_finish_charge()
	else:
		if _charging:
			_stop_charge()

func _start_charge(node_id: String) -> void:
	_charging = true
	_charge_target = node_id
	_charge_t = 0.0

func _stop_charge() -> void:
	_charging = false
	_charge_target = ""
	_charge_t = 0.0
	if _charge_bar:
		_charge_bar.value = 0.0
	_board_holder.queue_redraw()

func _finish_charge() -> void:
	var node_id: String = _charge_target
	_stop_charge()
	if CultivationBoard.unlock_node(node_id):
		AudioManager.play_sfx("merit_chime")
		_bloom_node(node_id)
		_refresh()

## 灌注滿成功：節點綻放（scale 彈跳＋白閃）。用臨時 Sprite/ColorRect 疊在節點座標上做視覺回饋，
## 不改動 _draw 的持久狀態（下一幀 queue_redraw 會照 node_state 正常畫出已解鎖朱紅實心）。
func _bloom_node(node_id: String) -> void:
	if not _node_positions.has(node_id):
		return
	var pos: Vector2 = _node_positions[node_id]
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.9)
	flash.size = Vector2(NODE_RADIUS, NODE_RADIUS) * 2.4
	flash.position = pos - flash.size * 0.5
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_holder.add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "scale", Vector2(1.6, 1.6), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(flash, "modulate:a", 0.0, 0.3)
	tw.tween_callback(flash.queue_free)
