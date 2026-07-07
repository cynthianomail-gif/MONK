extends Control
## 手機「修行」app：修行盤（曼荼羅法輪盤，2026-07-07 四脈放射重製）。
## 極座標佈局：核心置中，四脈（剛=上/體=右/迅=下/柔=左）同角度、半徑遞增放射；
## 節點優先讀自身 radius 欄位（ring 半徑僅作 fallback＋畫參考圓）；requires 畫成邊線。
## 節點四態：已解鎖(朱紅實心) / 可解鎖(金框+呼吸脈動) / 未達前置(灰框) / 劇情鎖(紫虛線)。
## 節點形狀編碼：屬性=圓 / 技能=菱形(旋轉方塊) / 匯流被動=同心雙圓 / 核心=大金圓。
## 選中節點右側面板顯示類型/名稱/描述/花費/前置/充能進度＋常駐圖例。
## 按住 E(interact) 0.6s 灌注道行滿→解鎖。
## 純 Control+_draw+Tween，不新增圖片素材。

const INK_RED := Color("#D4483A")
const INK_RED_GLOW := Color("#E8674F")
const GOLD := Color("#D9B36A")
const GOLD_BRIGHT := Color("#F0CE8A")
const WARM := Color("#F2E9D8")
const DIM := Color("#A79C8A")
const LOCKED_GRAY := Color("#756D60")
const STORY_PURPLE := Color("#A879D6")
const NEAR_BLACK := Color("#0E0C0A")
const BG_DEEP := Color("#14100D")      # 全 app 深墨底（字的對比靠這個）
const BG_PANEL := Color("#191410")     # 右側詳情面板底
const CHARGE_TIME := 0.6

const NODE_RADIUS := 13.0
const SKILL_RADIUS := 17.0   # 菱形節點明顯大一號
const PASSIVE_RADIUS := 14.0
const CORE_RADIUS := 26.0
const MASTER_RING_RADIUS := 380.0

## 佈局基準：node radius 是以此設計解析度為準（1080p 高度），_layout_nodes() 依實際
## board_holder 尺寸換算等比 _scale，讓盤面在任意視窗高度都能滿版置中。
const DESIGN_HALF_EXTENT := 430.0  # 380(師鎖環) + 外圈標籤/呼吸脈動預留邊距

var _center: Vector2 = Vector2(280, 300)
var _layout_scale: float = 1.0
var _node_positions: Dictionary = {}   # node_id -> Vector2 (相對 _board_holder 原點)
var _selected: String = ""
var _charging: bool = false
var _charge_t: float = 0.0
var _charge_target: String = ""
var _pulse_t: float = 0.0   # 可解鎖節點呼吸脈動計時（累積秒數）

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
	_board_holder.resized.connect(_on_holder_resized)

func _build() -> void:
	# 深墨底：修行盤自帶背景，不吃選單殼的中灰底（中灰底是先前字不清楚的主因之一）。
	var bg := ColorRect.new()
	bg.color = BG_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

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
	# 高度下限 420（原 600 會把左欄撐到 674 高、超過選單框內容區 ~570 而戳出框底，
	# 2026-07-07 使用者回報超框）；EXPAND_FILL 會自動填滿實際可用高度，盤面依 holder.size
	# 縮放置中（見 _layout_nodes），所以下限只要「不強迫超高」即可。
	_board_holder.custom_minimum_size = Vector2(520, 420)
	_board_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_holder.clip_contents = false
	_board_holder.draw.connect(_draw_board)
	left.add_child(_board_holder)

	var hint := Label.new()
	hint.text = "點選節點查看詳情；按住 [E] 灌注道行解鎖"
	hint.add_theme_color_override("font_color", DIM)
	hint.add_theme_font_size_override("font_size", 18)
	left.add_child(hint)

	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(340, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_PANEL
	sb.border_color = GOLD.darkened(0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(18)
	right.add_theme_stylebox_override("panel", sb)
	hb.add_child(right)

	# 詳情內容包一層 ScrollContainer：選到「習得技能＋前置多項＋長描述」的節點時，
	# VBox 內容可能比面板高，沒這層會把面板整個撐高、戳出選單框（2026-07-07 使用者回報）。
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)

	_info_panel = VBoxContainer.new()
	_info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_panel.add_theme_constant_override("separation", 8)
	scroll.add_child(_info_panel)

func _on_holder_resized() -> void:
	_layout_nodes()
	if is_instance_valid(_board_holder):
		_board_holder.queue_redraw()

## 依環半徑／節點自帶 radius 與 angle_deg 算出每個節點的畫面座標（相對 _board_holder 原點）。
## 滿版置中：中心＝_board_holder 正中；scale 依 holder 實際尺寸（取高寬較小者的一半）
## 對 DESIGN_HALF_EXTENT 等比縮放，讓師鎖環＋外圈標籤剛好吃滿版面。
func _layout_nodes() -> void:
	_node_positions.clear()
	var holder_size: Vector2 = _board_holder.size
	if holder_size.x <= 1.0 or holder_size.y <= 1.0:
		holder_size = _board_holder.custom_minimum_size
	_center = holder_size * 0.5
	var half_extent: float = minf(holder_size.x, holder_size.y) * 0.5
	# 最外圈節點（半徑 MASTER_RING_RADIUS=380）要落在「holder 半徑 − 標籤邊距」上，
	# 讓外圈節點的名字標籤（往節點外延伸文字半寬／字高，屬螢幕固定像素、不隨盤等比縮小）
	# 有固定空間，不會畫出 holder（clip_contents=false 會一路溢到選單框外）。
	# 舊版 half_extent/DESIGN_HALF_EXTENT 把邊距當成 design 空間固定比例，盤一小邊距就不足，
	# 外圈標籤（了塵傳·柔/迅/剛…）就穿出金框（2026-07-07 使用者回報）。
	var rough_s: float = half_extent / DESIGN_HALF_EXTENT
	# 邊距＝最外圈橫脈節點名字的半寬（中文約 1 字寬/字，最長名 ~5 字）＋描邊／間距餘裕。
	var fs_est: int = _label_font_size(rough_s)
	var label_margin: float = 3.4 * float(fs_est) + 18.0
	var usable: float = maxf(half_extent - label_margin, 60.0)
	_layout_scale = usable / MASTER_RING_RADIUS

	var ring_radius: Dictionary = {}
	for r in CultivationBoard.get_rings():
		ring_radius[int(r.ring)] = float(r.get("radius", 0.0))
	for n in CultivationBoard.get_nodes():
		var ring_idx: int = int(n.get("ring", 0))
		var radius: float = float(n.get("radius", ring_radius.get(ring_idx, 0.0)))
		var angle: float = deg_to_rad(float(n.get("angle_deg", 0.0)))
		var pos := _center + Vector2(cos(angle), sin(angle)) * radius * _layout_scale
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
		var hit_r: float = _node_hit_radius(node_id) * _layout_scale
		var btn := Button.new()
		btn.flat = true
		btn.modulate = Color(1, 1, 1, 0)
		btn.position = pos - Vector2(hit_r, hit_r)
		btn.size = Vector2(hit_r * 2, hit_r * 2)
		var nid: String = node_id
		btn.pressed.connect(func() -> void: select_node(nid))
		_board_holder.add_child(btn)
		_node_buttons[node_id] = btn

func _node_hit_radius(node_id: String) -> float:
	var n: Dictionary = CultivationBoard.get_node_def(node_id)
	if node_id == "core":
		return CORE_RADIUS
	match String(n.get("type", "")):
		"skill":
			return SKILL_RADIUS
		"passive":
			return PASSIVE_RADIUS
		_:
			return NODE_RADIUS

func _draw_board() -> void:
	var s: float = _layout_scale

	# 盤心暖光暈：多層低 alpha 同心圓由內而外淡出，讓深墨底不死黑、盤面有「法輪發光」的縱深。
	var glow_steps := 6
	for i in glow_steps:
		var t: float = float(i) / float(glow_steps - 1)
		var glow_r: float = lerpf(70.0, MASTER_RING_RADIUS * 1.02, t) * s
		var glow_a: float = lerpf(0.085, 0.008, t)
		_board_holder.draw_circle(_center, glow_r, Color(0.95, 0.80, 0.52, glow_a))

	# 畫參考圓：依實際出現的半徑值畫圈（同脈同半徑節點共用一圈），非固定 ring 索引。
	var radii_seen: Dictionary = {}
	var ring_radius: Dictionary = {}
	for r in CultivationBoard.get_rings():
		ring_radius[int(r.ring)] = float(r.get("radius", 0.0))
	for n in CultivationBoard.get_nodes():
		var ring_idx: int = int(n.get("ring", 0))
		var radius: float = float(n.get("radius", ring_radius.get(ring_idx, 0.0)))
		if radius > 0.0:
			radii_seen[radius] = true
	var master_flag: String = ""
	for r in CultivationBoard.get_rings():
		if String(r.get("unlock_flag", "")) != "":
			master_flag = String(r.get("unlock_flag", ""))
	var master_locked: bool = master_flag != "" and not GameManager.get_flag(master_flag)
	for radius in radii_seen:
		var is_master: bool = is_equal_approx(float(radius), MASTER_RING_RADIUS)
		if is_master:
			var col: Color = STORY_PURPLE.darkened(0.1) if master_locked else GOLD.darkened(0.2)
			if master_locked:
				_draw_dashed_circle(_center, float(radius) * s, col)
			else:
				_board_holder.draw_arc(_center, float(radius) * s, 0, TAU, 96, col, 1.2)
			# 師鎖環刻度：72 格細刻度（曼荼羅法輪的輪輻感），每 18 格一長刻對準四脈方位。
			var tick_col := Color(col.r, col.g, col.b, 0.35)
			for i in 72:
				var ta: float = TAU * float(i) / 72.0
				var tick_len: float = 8.0 if i % 18 == 0 else 3.5
				var dir_t := Vector2(cos(ta), sin(ta))
				var p0: Vector2 = _center + dir_t * (float(radius) - tick_len) * s
				var p1: Vector2 = _center + dir_t * (float(radius) + tick_len) * s
				_board_holder.draw_line(p0, p1, tick_col, 1.0)
		else:
			_board_holder.draw_arc(_center, float(radius) * s, 0, TAU, 64, Color(GOLD.r, GOLD.g, GOLD.b, 0.22), 1.2)

	# 師鎖環標語：環頂偏右（避開 270°/master_atk 節點名字標籤，落在 300° 方向外側淨空處）。
	if master_flag != "":
		var label_text: String = "了塵傳・師鎖環（完成師父試煉開啟）"
		var font: Font = ThemeDB.fallback_font
		var fs: int = _label_font_size(s)
		var text_w: float = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var label_angle: float = deg_to_rad(300.0)
		var label_anchor: Vector2 = _center + Vector2(cos(label_angle), sin(label_angle)) * (MASTER_RING_RADIUS * s + 22.0)
		var label_pos: Vector2 = label_anchor - Vector2(text_w * 0.5, 0)
		var label_col: Color = STORY_PURPLE if master_locked else GOLD
		_board_holder.draw_string_outline(font, label_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.85))
		_board_holder.draw_string(font, label_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, label_col)

	# 畫 requires 邊：已解鎖=亮金加粗＋柔光底線；師鎖目標=紫虛線；其餘=暖灰細線。
	for n in CultivationBoard.get_nodes():
		var nid: String = String(n.id)
		var to_pos: Vector2 = _node_positions.get(nid, _center)
		var nid_unlocked: bool = CultivationBoard.is_unlocked(nid)
		var nid_story_locked: bool = CultivationBoard.node_state(nid) == "story_locked"
		for req in n.get("requires", []):
			var from_pos: Vector2 = _node_positions.get(String(req), _center)
			if nid_unlocked:
				_board_holder.draw_line(from_pos, to_pos, Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, 0.18), 8.0)
				_board_holder.draw_line(from_pos, to_pos, GOLD_BRIGHT, 3.0)
			elif nid_story_locked:
				_draw_dashed_line(from_pos, to_pos, Color(STORY_PURPLE.r, STORY_PURPLE.g, STORY_PURPLE.b, 0.55), 1.5)
			else:
				_board_holder.draw_line(from_pos, to_pos, Color(0.42, 0.39, 0.35, 0.8), 1.5)

	# 畫節點（_pulse_t 由 _process 每幀累加，這裡只讀取算呼吸脈動相位）
	var pulse_frac: float = (sin(_pulse_t * TAU * 0.6) + 1.0) * 0.5  # 0..1 呼吸
	for n in CultivationBoard.get_nodes():
		var nid: String = String(n.id)
		var pos: Vector2 = _node_positions.get(nid, _center)
		var state: String = CultivationBoard.node_state(nid)
		var ntype: String = String(n.get("type", "stat"))
		var is_core: bool = nid == "core"
		var base_r: float = _node_hit_radius(nid) * s

		if is_core:
			_draw_glow(pos, base_r, INK_RED_GLOW, 0.5)
			_draw_node_shape(pos, base_r, ntype, true, INK_RED, GOLD_BRIGHT, 2.5)
			# 蓮瓣環：核心外圈 8 段開口弧＋間隙金點，曼荼羅盤心裝飾。
			var petal_r: float = base_r + 8.0 * s
			for i in 8:
				var pa: float = TAU * float(i) / 8.0
				_board_holder.draw_arc(pos, petal_r, pa + 0.10, pa + TAU / 8.0 - 0.10, 10, GOLD, 1.5)
				var dot_a: float = pa + TAU / 16.0
				_board_holder.draw_circle(pos + Vector2(cos(dot_a), sin(dot_a)) * (petal_r + 5.0 * s), 1.8 * s, GOLD)
			var font: Font = ThemeDB.fallback_font
			var core_fs: int = clampi(int(round(16.0 * s)), 14, 22)
			var core_text := "本心"
			var tw: float = font.get_string_size(core_text, HORIZONTAL_ALIGNMENT_LEFT, -1, core_fs).x
			_board_holder.draw_string(font, pos + Vector2(-tw * 0.5, core_fs * 0.35), core_text, HORIZONTAL_ALIGNMENT_LEFT, -1, core_fs, NEAR_BLACK)
		else:
			match state:
				"unlocked":
					_draw_glow(pos, base_r, INK_RED_GLOW, 0.35)
					_draw_node_shape(pos, base_r, ntype, true, INK_RED, GOLD_BRIGHT, 2.0)
				"available":
					var pulse_r: float = base_r + pulse_frac * 3.0 * s
					_draw_glow(pos, base_r, GOLD_BRIGHT, 0.18 + 0.16 * pulse_frac)
					_draw_node_shape(pos, pulse_r, ntype, false, Color(), GOLD_BRIGHT, 2.5)
				"story_locked":
					_board_holder.draw_circle(pos, base_r, Color(0.05, 0.04, 0.03, 0.75))
					_draw_dashed_circle(pos, base_r, STORY_PURPLE)
				_:  # locked
					_draw_node_shape(pos, base_r, ntype, false, Color(), LOCKED_GRAY, 2.0)

		if nid == _selected:
			var sel_r: float = base_r + 6.0 * s
			_board_holder.draw_arc(pos, sel_r + 2.0, 0, TAU, 28, Color(WARM.r, WARM.g, WARM.b, 0.25), 4.0)
			_board_holder.draw_arc(pos, sel_r, 0, TAU, 28, WARM, 1.8)

		# 名字常駐
		if not is_core:
			var ring_step: int = _radius_rank(nid)
			_draw_node_label(pos, String(n.get("name", nid)), state, float(n.get("angle_deg", 0.0)), base_r, ring_step)

	# 充能進度環（選中節點灌注中）
	if _charging and _charge_target != "" and _node_positions.has(_charge_target):
		var cpos: Vector2 = _node_positions[_charge_target]
		var frac: float = clampf(_charge_t / CHARGE_TIME, 0.0, 1.0)
		var cr: float = _node_hit_radius(_charge_target) * s + 9.0 * s
		_board_holder.draw_arc(cpos, cr, -PI / 2.0, -PI / 2.0 + TAU * frac, 32, Color(INK_RED_GLOW.r, INK_RED_GLOW.g, INK_RED_GLOW.b, 0.35), 7.0)
		_board_holder.draw_arc(cpos, cr, -PI / 2.0, -PI / 2.0 + TAU * frac, 32, INK_RED_GLOW, 3.5)

## 依節點形狀編碼繪製：stat=圓／skill=菱形(旋轉方塊)／passive(非core)=同心雙圓／core=大金圓。
## filled=true 時實心＋外框弧；filled=false 時僅外框（可解鎖/未達前置態）。
func _draw_node_shape(pos: Vector2, r: float, ntype: String, filled: bool, fill_col: Color, outline_col: Color, outline_w: float) -> void:
	# 空心態（可解鎖/未達前置）墊一層深色底盤：把光暈/參考圈從節點內部隔開，輪廓更利。
	var hollow_fill := Color(0.05, 0.04, 0.03, 0.75)
	match ntype:
		"skill":
			var pts := PackedVector2Array([
				pos + Vector2(0, -r), pos + Vector2(r, 0), pos + Vector2(0, r), pos + Vector2(-r, 0)
			])
			_board_holder.draw_colored_polygon(pts, fill_col if filled else hollow_fill)
			var closed := pts.duplicate()
			closed.append(pts[0])
			_board_holder.draw_polyline(closed, outline_col, outline_w)
		"passive":
			_board_holder.draw_circle(pos, r, fill_col if filled else hollow_fill)
			_board_holder.draw_arc(pos, r, 0, TAU, 24, outline_col, outline_w)
			_board_holder.draw_arc(pos, r * 0.6, 0, TAU, 20, outline_col, outline_w)
		_:
			_board_holder.draw_circle(pos, r, fill_col if filled else hollow_fill)
			_board_holder.draw_arc(pos, r, 0, TAU, 24, outline_col, outline_w)

## 節點在其所屬鏈上的半徑名次（0=最內層），供水平脈標籤交錯（奇偶列上下互換）判斷用。
func _radius_rank(node_id: String) -> int:
	var n: Dictionary = CultivationBoard.get_node_def(node_id)
	var angle: float = float(n.get("angle_deg", 0.0))
	var pos: Vector2 = _node_positions.get(node_id, _center)
	var d: float = pos.distance_to(_center)
	var rank: int = 0
	# 只跟「同角度（同一脈）」的其他節點比半徑排名，讓交錯規則沿著同一條放射線連續切換，
	# 不受其他脈節點半徑分佈影響（先前用全域排名會導致同一脈的相鄰節點名次不連續、交錯失效）。
	for other_id in _node_positions:
		if other_id == node_id:
			continue
		var other_n: Dictionary = CultivationBoard.get_node_def(String(other_id))
		if not is_equal_approx(float(other_n.get("angle_deg", -999.0)), angle):
			continue
		var od: float = _node_positions[other_id].distance_to(_center)
		if od < d - 0.5:
			rank += 1
	return rank

## 名字常駐標籤：依角度決定文字錨點方向，避免壓線（spec 第2節）——
## 上脈(270°,剛)/下脈(90°,迅)：標籤靠右排（文字起點貼齊節點右側）。
## 左脈(180°,柔)：標籤靠左排，text-anchor end（文字尾端貼齊節點左側）。
## 右脈(0°,體)：同一水平線節點密集，標籤改「上下交錯」（依半徑名次奇偶切上/下）避免彼此壓字。
## 其餘（技能/被動旁枝，斜角）：沿該節點自身角度方向外推。
func _draw_node_label(pos: Vector2, name_text: String, state: String, angle_deg: float, node_r: float, radius_rank: int) -> void:
	var font: Font = ThemeDB.fallback_font
	var fs: int = _label_font_size(_layout_scale)
	var col: Color
	match state:
		"unlocked":
			col = WARM
		"available":
			col = GOLD_BRIGHT
		"story_locked":
			col = STORY_PURPLE
		_:
			col = LOCKED_GRAY
	var text_size: Vector2 = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var a: float = deg_to_rad(angle_deg)
	var dir := Vector2(cos(a), sin(a))
	var draw_pos: Vector2
	var margin := 10.0

	var is_left_vein: bool = dir.x < -0.9 and absf(dir.y) < 0.1
	var is_right_vein: bool = dir.x > 0.9 and absf(dir.y) < 0.1

	if is_left_vein or is_right_vein:
		# 橫脈（柔/左、體/右）：標籤置中在節點「正上／正下」交錯，完全離開鏈線——
		# 貼齊節點側邊的排法在字級放大後會橫躺在鏈線上、壓到隔壁節點（截圖親驗過的坑）。
		var cx: float = pos.x - text_size.x * 0.5
		if radius_rank % 2 == 0:
			draw_pos = Vector2(cx, pos.y - node_r - 8.0)
		else:
			draw_pos = Vector2(cx, pos.y + node_r + 8.0 + fs * 0.8)
	elif absf(dir.x) < 0.35:
		# 剛／上脈 or 迅／下脈：標籤靠右排。
		var anchor: Vector2 = pos + dir * (node_r + margin)
		draw_pos = anchor + Vector2(6, fs * 0.35)
	elif dir.x < 0.0:
		# 斜角旁枝偏左（技能節點等）：靠左排。
		var anchor: Vector2 = pos + dir * (node_r + margin)
		draw_pos = anchor - Vector2(text_size.x, -fs * 0.35)
	else:
		# 斜角旁枝偏右：靠右排。
		var anchor: Vector2 = pos + dir * (node_r + margin)
		draw_pos = anchor + Vector2(0, fs * 0.35)
	# 深色描邊墊底再上色字：不論字落在光暈/連線/參考圈上都保持可讀。
	_board_holder.draw_string_outline(font, draw_pos, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.85))
	_board_holder.draw_string(font, draw_pos, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

## 盤上標籤字級：隨盤面等比縮放（1080p 滿版時約 17px），下限 12 保底可讀。
func _label_font_size(s: float) -> int:
	return clampi(int(round(15.0 * s)), 12, 20)

## 節點柔光：三層遞減 alpha 同心圓，畫在節點本體底下。
func _draw_glow(pos: Vector2, r: float, col: Color, strength: float) -> void:
	_board_holder.draw_circle(pos, r * 1.45, Color(col.r, col.g, col.b, strength * 0.30))
	_board_holder.draw_circle(pos, r * 1.95, Color(col.r, col.g, col.b, strength * 0.15))
	_board_holder.draw_circle(pos, r * 2.6, Color(col.r, col.g, col.b, strength * 0.07))

func _draw_dashed_line(from_pos: Vector2, to_pos: Vector2, col: Color, width: float) -> void:
	var seg_len := 7.0
	var gap_len := 5.0
	var total: float = from_pos.distance_to(to_pos)
	if total <= 0.001:
		return
	var dir: Vector2 = (to_pos - from_pos) / total
	var d := 0.0
	while d < total:
		var d2: float = minf(d + seg_len, total)
		_board_holder.draw_line(from_pos + dir * d, from_pos + dir * d2, col, width)
		d = d2 + gap_len

func _draw_dashed_circle(center: Vector2, radius: float, col: Color) -> void:
	var segs := 32
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

const TYPE_BADGE := {
	"stat": "屬性",
	"skill": "技能",
	"passive": "被動",
}

func _refresh_info_panel() -> void:
	for c in _info_panel.get_children():
		c.queue_free()
	if _selected == "":
		var l := Label.new()
		l.text = "選擇一個節點查看詳情"
		l.add_theme_color_override("font_color", DIM)
		l.add_theme_font_size_override("font_size", 20)
		_info_panel.add_child(l)
		_add_legend()
		return
	var n: Dictionary = CultivationBoard.get_node_def(_selected)
	if n.is_empty():
		return
	var state: String = CultivationBoard.node_state(_selected)

	# 類型 badge（技能/屬性/被動/師鎖，金底）
	var badge_text: String = "師鎖" if state == "story_locked" else String(TYPE_BADGE.get(String(n.get("type", "")), "屬性"))
	var badge := Label.new()
	badge.text = "  %s  " % badge_text
	badge.add_theme_color_override("font_color", NEAR_BLACK)
	badge.add_theme_font_size_override("font_size", 14)
	var badge_sb := StyleBoxFlat.new()
	badge_sb.bg_color = GOLD
	badge_sb.set_corner_radius_all(4)
	badge_sb.set_content_margin_all(3)
	badge.add_theme_stylebox_override("normal", badge_sb)
	_info_panel.add_child(badge)

	var name_lbl := Label.new()
	name_lbl.text = String(n.get("name", _selected))
	name_lbl.add_theme_color_override("font_color", WARM)
	name_lbl.add_theme_font_size_override("font_size", 22)
	_info_panel.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = String(n.get("desc", ""))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", DIM)
	desc_lbl.add_theme_font_size_override("font_size", 18)
	_info_panel.add_child(desc_lbl)

	_info_panel.add_child(HSeparator.new())

	var cost_lbl := Label.new()
	cost_lbl.text = "花費 %d 道行" % int(n.get("cost", 0))
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_lbl.add_theme_color_override("font_color", GOLD)
	cost_lbl.add_theme_font_size_override("font_size", 18)
	_info_panel.add_child(cost_lbl)

	if not n.get("requires", []).is_empty():
		for r in n.requires:
			var rid: String = String(r)
			var rn: Dictionary = CultivationBoard.get_node_def(rid)
			var met: bool = CultivationBoard.is_unlocked(rid)
			var req_lbl := Label.new()
			req_lbl.text = "%s %s" % ["✓" if met else "✗", String(rn.get("name", rid))]
			req_lbl.add_theme_color_override("font_color", Color(0.55, 0.78, 0.55) if met else DIM)
			req_lbl.add_theme_font_size_override("font_size", 16)
			_info_panel.add_child(req_lbl)

	match state:
		"unlocked":
			var state_lbl := Label.new()
			state_lbl.text = "已解鎖"
			state_lbl.add_theme_color_override("font_color", INK_RED)
			state_lbl.add_theme_font_size_override("font_size", 18)
			_info_panel.add_child(state_lbl)
		"story_locked":
			var ring: Dictionary = _ring_of(_selected)
			var state_lbl := Label.new()
			state_lbl.text = "劇情鎖：%s 尚未達成" % String(ring.get("unlock_flag", ""))
			state_lbl.add_theme_color_override("font_color", STORY_PURPLE)
			state_lbl.add_theme_font_size_override("font_size", 18)
			_info_panel.add_child(state_lbl)
		"available":
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
		_:
			var state_lbl := Label.new()
			state_lbl.text = "前置未達"
			state_lbl.add_theme_color_override("font_color", LOCKED_GRAY)
			state_lbl.add_theme_font_size_override("font_size", 18)
			_info_panel.add_child(state_lbl)
			_charge_bar = null

	if state != "available":
		_charge_bar = null

	_info_panel.add_child(HSeparator.new())
	_add_legend()

## 圖例常駐：四態＋形狀說明。
func _add_legend() -> void:
	var legend_title := Label.new()
	legend_title.text = "圖例"
	legend_title.add_theme_color_override("font_color", DIM)
	legend_title.add_theme_font_size_override("font_size", 14)
	_info_panel.add_child(legend_title)
	var lines := [
		["● 朱紅實心＝已解鎖", INK_RED],
		["○ 金框＝可解鎖", GOLD],
		["○ 灰框＝前置未達", LOCKED_GRAY],
		["┄ 紫虛線＝師鎖", STORY_PURPLE],
		["◇ 菱形＝技能／◎ 雙圈＝被動", DIM],
	]
	for line in lines:
		var l := Label.new()
		l.text = line[0]
		l.add_theme_color_override("font_color", line[1])
		l.add_theme_font_size_override("font_size", 15)
		_info_panel.add_child(l)

func _ring_of(node_id: String) -> Dictionary:
	var n: Dictionary = CultivationBoard.get_node_def(node_id)
	var ring_idx: int = int(n.get("ring", 0))
	for r in CultivationBoard.get_rings():
		if int(r.get("ring", -1)) == ring_idx:
			return r
	return {}

func _process(delta: float) -> void:
	_pulse_t += delta
	if is_instance_valid(_board_holder):
		_board_holder.queue_redraw()
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
	var r: float = _node_hit_radius(node_id) * _layout_scale
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.9)
	flash.size = Vector2(r, r) * 2.4
	flash.position = pos - flash.size * 0.5
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_holder.add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "scale", Vector2(1.6, 1.6), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(flash, "modulate:a", 0.0, 0.3)
	tw.tween_callback(flash.queue_free)
