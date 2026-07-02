extends Control
## 3D 探索右上角小地圖（雷達式）：上方＝相機朝向（視角可旋轉，地圖跟著轉）、玩家置中。
## 街道淡色帶＝可走範圍（由環境節點 minimap_streets() 提供世界 XZ Rect2）。
## 白點＝地標，黃點＋外環＝有任務的地點，紅箭頭＝玩家（含朝向），N＝北方羅盤沿環移動。
## 世界 X→右(東)、世界 +Z→下(南)、-Z→上(北)，再整體旋轉對齊相機。

const RADIUS := 74.0        # 半徑(px)
const WORLD_SCALE := 4.2    # 1 世界單位 = px（玩家為中心的可視範圍 ≈ RADIUS/SCALE 單位）
const BG := Color(0.05, 0.05, 0.06, 0.72)
const RING := Color(0.79, 0.659, 0.38, 0.9)         # 暗金環
const STREET_FILL := Color(0.88, 0.86, 0.78, 0.16)  # 街道淡墨帶
const STREET_EDGE := Color(0.88, 0.86, 0.78, 0.30)
const DOT_LANDMARK := Color(0.86, 0.86, 0.92, 0.95)
const DOT_QUEST := Color(1.0, 0.86, 0.12, 1.0)      # 任務黃
const PLAYER_COL := Color(0.92, 0.32, 0.26, 1.0)    # 玩家紅

var _clip_poly := PackedVector2Array()   # 圓形裁切用多邊形（快取）

func _ready() -> void:
	custom_minimum_size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := Vector2(RADIUS, RADIUS)
	for i in range(40):
		var a := TAU * float(i) / 40.0
		_clip_poly.append(c + Vector2(cos(a), sin(a)) * (RADIUS - 3.0))

func _process(_d: float) -> void:
	queue_redraw()

## 相機 yaw → 小地圖旋轉量：把相機前方向轉到畫面正上方。
func _map_rot() -> float:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return 0.0
	var f := -cam.global_transform.basis.z
	var f2 := Vector2(f.x, f.z)
	if f2.length() < 0.01:
		return 0.0
	return -PI * 0.5 - f2.angle()

func _draw() -> void:
	var c := Vector2(RADIUS, RADIUS)
	draw_circle(c, RADIUS, BG)

	var player := get_tree().get_first_node_in_group("player") as Node3D
	var rot := _map_rot()
	if player != null:
		_draw_streets(c, player.global_position, rot)

	# 十字準星（淡）
	draw_line(c - Vector2(RADIUS - 4, 0), c + Vector2(RADIUS - 4, 0), Color(1, 1, 1, 0.06), 1.0)
	draw_line(c - Vector2(0, RADIUS - 4), c + Vector2(0, RADIUS - 4), Color(1, 1, 1, 0.06), 1.0)
	draw_arc(c, RADIUS, 0, TAU, 56, RING, 2.5, true)

	if player == null:
		_draw_compass(c, rot)
		return
	var pp := player.global_position

	# 地點標記
	for t in get_tree().get_nodes_in_group("location_trigger"):
		if not (t is Node3D):
			continue
		var lp: Vector3 = (t as Node3D).global_position
		var rel := Vector2(lp.x - pp.x, lp.z - pp.z).rotated(rot) * WORLD_SCALE
		if rel.length() > RADIUS - 7.0:
			rel = rel.normalized() * (RADIUS - 7.0)
		var pos := c + rel
		var is_quest: bool = "loc_data" in t and QuestManager.location_has_quest(t.loc_data)
		if is_quest:
			draw_circle(pos, 5.5, DOT_QUEST)
			draw_arc(pos, 8.0, 0, TAU, 20, DOT_QUEST, 1.5, true)   # 任務外環（吸睛）
		else:
			draw_circle(pos, 4.0, DOT_LANDMARK)

	# 玩家（置中）＋朝向箭頭。forward = -Z 軸投影到 XZ，再套地圖旋轉。
	var fwd3: Vector3 = -player.global_transform.basis.z
	var fwd := Vector2(fwd3.x, fwd3.z)
	if fwd.length() < 0.01:
		fwd = Vector2(0, -1)
	fwd = fwd.normalized().rotated(rot)
	var side := Vector2(-fwd.y, fwd.x)
	var tip := c + fwd * 9.0
	var b1 := c - fwd * 5.0 + side * 5.5
	var b2 := c - fwd * 5.0 - side * 5.5
	draw_colored_polygon(PackedVector2Array([tip, b1, b2]), PLAYER_COL)
	_draw_compass(c, rot)   # 最後畫：N 不被地點點蓋住

## 街道帶：環境節點（group "minimap_streets"）給世界 XZ Rect2 清單，投影後裁到圓內。
func _draw_streets(c: Vector2, pp: Vector3, rot: float) -> void:
	var env := get_tree().get_first_node_in_group("minimap_streets")
	if env == null or not env.has_method("minimap_streets"):
		return
	for r in env.minimap_streets():
		var rect := r as Rect2
		var poly := PackedVector2Array()
		for corner in [rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]:
			poly.append(c + (Vector2(corner.x - pp.x, corner.y - pp.z)).rotated(rot) * WORLD_SCALE)
		for clipped in Geometry2D.intersect_polygons(poly, _clip_poly):
			draw_colored_polygon(clipped, STREET_FILL)
			var outline := clipped.duplicate()
			outline.append(outline[0])
			draw_polyline(outline, STREET_EDGE, 1.0, true)

## N 羅盤字：北＝世界 -Z 方向，沿外環隨旋轉移動。
func _draw_compass(c: Vector2, rot: float) -> void:
	var n_dir := Vector2(0, -1).rotated(rot)
	var pos := c + n_dir * (RADIUS - 11.0)
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var fs := 15
	var sz := font.get_string_size("N", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var at := pos + Vector2(-sz.x * 0.5, sz.y * 0.32)
	draw_string(font, at + Vector2(0, 1), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.9))
	draw_string(font, at, "N", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, RING)
