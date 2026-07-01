extends Control
## 3D 探索右上角小地圖（雷達式）：北向固定（N 在上）、玩家置中。
## 白點＝地標，黃點＋外環＝有任務的地點，紅箭頭＝玩家（含朝向）。
## 世界 X→右(東)、世界 +Z→下(南)、-Z→上(北)。

const RADIUS := 74.0        # 半徑(px)
const WORLD_SCALE := 4.2    # 1 世界單位 = px（玩家為中心的可視範圍 ≈ RADIUS/SCALE 單位）
const BG := Color(0.05, 0.05, 0.06, 0.72)
const RING := Color(0.79, 0.659, 0.38, 0.9)         # 暗金環
const DOT_LANDMARK := Color(0.86, 0.86, 0.92, 0.95)
const DOT_QUEST := Color(1.0, 0.86, 0.12, 1.0)      # 任務黃
const PLAYER_COL := Color(0.92, 0.32, 0.26, 1.0)    # 玩家紅

var _n_label: Label = null

func _ready() -> void:
	custom_minimum_size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# N 羅盤字（頂端）
	_n_label = Label.new()
	_n_label.text = "N"
	_n_label.add_theme_font_size_override("font_size", 16)
	_n_label.add_theme_color_override("font_color", RING)
	_n_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_n_label.add_theme_constant_override("shadow_offset_y", 1)
	_n_label.position = Vector2(RADIUS - 6.0, -2.0)
	_n_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_n_label)

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	var c := Vector2(RADIUS, RADIUS)
	draw_circle(c, RADIUS, BG)
	# 十字準星（淡）
	draw_line(c - Vector2(RADIUS - 4, 0), c + Vector2(RADIUS - 4, 0), Color(1, 1, 1, 0.06), 1.0)
	draw_line(c - Vector2(0, RADIUS - 4), c + Vector2(0, RADIUS - 4), Color(1, 1, 1, 0.06), 1.0)
	draw_arc(c, RADIUS, 0, TAU, 56, RING, 2.5, true)

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var pp := player.global_position

	# 地點標記
	for t in get_tree().get_nodes_in_group("location_trigger"):
		if not (t is Node3D):
			continue
		var lp: Vector3 = (t as Node3D).global_position
		var rel := Vector2(lp.x - pp.x, lp.z - pp.z) * WORLD_SCALE
		var clamped := false
		if rel.length() > RADIUS - 7.0:
			rel = rel.normalized() * (RADIUS - 7.0)
			clamped = true
		var pos := c + rel
		var is_quest: bool = "loc_data" in t and QuestManager.location_has_quest(t.loc_data)
		if is_quest:
			draw_circle(pos, 5.5, DOT_QUEST)
			draw_arc(pos, 8.0, 0, TAU, 20, DOT_QUEST, 1.5, true)   # 任務外環（吸睛）
		else:
			draw_circle(pos, 4.0, DOT_LANDMARK)
		if clamped:
			# 邊緣的地點畫成小三角箭頭指向它（在圈外方向）
			pass

	# 玩家（置中）＋朝向箭頭。forward = -Z 軸投影到 XZ。
	var fwd3: Vector3 = -player.global_transform.basis.z
	var fwd := Vector2(fwd3.x, fwd3.z)
	if fwd.length() < 0.01:
		fwd = Vector2(0, -1)
	fwd = fwd.normalized()
	var side := Vector2(-fwd.y, fwd.x)
	var tip := c + fwd * 9.0
	var b1 := c - fwd * 5.0 + side * 5.5
	var b2 := c - fwd * 5.0 - side * 5.5
	draw_colored_polygon(PackedVector2Array([tip, b1, b2]), PLAYER_COL)
