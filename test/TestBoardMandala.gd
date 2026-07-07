extends Node
## headless 驗證：修行盤曼荼羅法輪盤佈局（2026-07-07 重製，spec 見
## docs/superpowers/specs/2026-07-07-cultivation-board-mandala-design.md）。
## 涵蓋：四脈（剛/體/迅/柔）同鏈節點同角度、半徑嚴格遞增、全節點落在 1920x1080 視窗內、
## 盤心位於盤區中心 ±10px。
## 跑法：Godot --headless res://test/TestBoardMandala.tscn

var ok: bool = true

const WINDOW_SIZE := Vector2i(1920, 1080)

## 四脈鏈（由內而外，不含旁枝技能/匯流被動/core）：spec 第1節「節點鏈（由內而外）」。
const CHAINS := {
	"剛(atk)": ["atk_1", "atk_2", "atk_3", "atk_4", "atk_5", "master_atk"],
	"體(hp)": ["hp_1", "hp_2", "hp_3", "hp_4", "hp_5", "master_hp"],
	"迅(spd)": ["spd_1", "spd_2", "spd_3", "spd_4", "master_spd"],
	"柔(def)": ["def_1", "def_2", "def_3", "def_4", "def_5", "master_def"],
}

func _check(cond: bool, msg: String) -> void:
	if not cond:
		ok = false
		print("FAIL: ", msg)

func _ready() -> void:
	await get_tree().process_frame
	_test_chain_same_angle_increasing_radius()
	_test_nodes_within_window()
	_test_board_center_alignment()
	_test_board_app_layout_matches_json()
	print("BOARD_MANDALA_TEST: ", "ALL PASS" if ok else "HAS FAILURES")
	get_tree().quit(0 if ok else 1)

## 每條脈的節點：同角度（共線）、半徑嚴格遞增。
func _test_chain_same_angle_increasing_radius() -> void:
	var ring_radius: Dictionary = {}
	for r in CultivationBoard.get_rings():
		ring_radius[int(r.ring)] = float(r.get("radius", 0.0))

	for chain_name in CHAINS:
		var chain: Array = CHAINS[chain_name]
		var angle_ref: float = -1.0
		var prev_radius: float = -1.0
		for node_id in chain:
			var n: Dictionary = CultivationBoard.get_node_def(node_id)
			_check(not n.is_empty(), "%s: 節點 %s 存在於 cultivation_board.json" % [chain_name, node_id])
			if n.is_empty():
				continue
			var angle: float = float(n.get("angle_deg", -999.0))
			if angle_ref < 0.0:
				angle_ref = angle
			_check(is_equal_approx(angle, angle_ref),
				"%s: %s 角度與鏈首同角度 (expected %.1f, got %.1f)" % [chain_name, node_id, angle_ref, angle])
			var ring_idx: int = int(n.get("ring", 0))
			var radius: float = float(n.get("radius", ring_radius.get(ring_idx, 0.0)))
			_check(radius > prev_radius,
				"%s: %s 半徑嚴格大於前一節點 (prev=%.1f, got=%.1f)" % [chain_name, node_id, prev_radius, radius])
			prev_radius = radius

## 全部節點（含旁枝技能/匯流被動/core）換算座標後須落在 1920x1080 視窗內
## （以 BoardApp 實際 _layout_nodes() 換算之座標為準，用 1920x1080 board_holder 尺寸模擬）。
func _test_nodes_within_window() -> void:
	var app_ps = load("res://src/ui/menu/pages/BoardApp.gd")
	_check(app_ps != null, "load BoardApp.gd")
	if app_ps == null:
		return
	var app = app_ps.new()
	get_tree().root.add_child(app)
	for i in 3:
		await get_tree().process_frame
	# board_holder 撐滿容器；用 DisplayServer 視窗尺寸(已在測試環境設 1920x1080)驅動 layout。
	app.get("_board_holder").size = Vector2(WINDOW_SIZE.x * 0.65, WINDOW_SIZE.y)
	app._layout_nodes()
	var positions: Dictionary = app.get("_node_positions")
	var holder_size: Vector2 = app.get("_board_holder").size
	var out_of_bounds: Array = []
	for node_id in positions:
		var pos: Vector2 = positions[node_id]
		if pos.x < 0.0 or pos.x > holder_size.x or pos.y < 0.0 or pos.y > holder_size.y:
			out_of_bounds.append("%s@%s" % [node_id, str(pos)])
	_check(out_of_bounds.is_empty(), "全部節點落在盤區視窗內 (out_of_bounds=%s, holder_size=%s)" % [str(out_of_bounds), str(holder_size)])
	app.queue_free()
	await get_tree().process_frame

## 盤心（_center）須位於盤區（_board_holder）中心 ±10px。
func _test_board_center_alignment() -> void:
	var app_ps = load("res://src/ui/menu/pages/BoardApp.gd")
	var app = app_ps.new()
	get_tree().root.add_child(app)
	for i in 3:
		await get_tree().process_frame
	app.get("_board_holder").size = Vector2(1200, 1080)
	app._layout_nodes()
	var center: Vector2 = app.get("_center")
	var holder_size: Vector2 = app.get("_board_holder").size
	var expected_center: Vector2 = holder_size * 0.5
	var delta: Vector2 = center - expected_center
	_check(absf(delta.x) <= 10.0 and absf(delta.y) <= 10.0,
		"盤心位於盤區中心 ±10px (center=%s, expected=%s, delta=%s)" % [str(center), str(expected_center), str(delta)])
	app.queue_free()
	await get_tree().process_frame

## 交叉核對：BoardApp._layout_nodes() 換算出的角度／半徑排序與 JSON 原始資料一致
## （防止佈局程式碼與資料脫節，例如誤讀 ring 半徑而非節點自帶 radius）。
func _test_board_app_layout_matches_json() -> void:
	var app_ps = load("res://src/ui/menu/pages/BoardApp.gd")
	var app = app_ps.new()
	get_tree().root.add_child(app)
	for i in 3:
		await get_tree().process_frame
	app.get("_board_holder").size = Vector2(1200, 1080)
	app._layout_nodes()
	var positions: Dictionary = app.get("_node_positions")
	var center: Vector2 = app.get("_center")
	var scale: float = app.get("_layout_scale")
	var ring_radius: Dictionary = {}
	for r in CultivationBoard.get_rings():
		ring_radius[int(r.ring)] = float(r.get("radius", 0.0))
	var mismatches: Array = []
	for n in CultivationBoard.get_nodes():
		var nid: String = String(n.id)
		if not positions.has(nid):
			mismatches.append("%s missing from _node_positions" % nid)
			continue
		var ring_idx: int = int(n.get("ring", 0))
		var radius: float = float(n.get("radius", ring_radius.get(ring_idx, 0.0)))
		var angle: float = deg_to_rad(float(n.get("angle_deg", 0.0)))
		var expected: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * scale
		var got: Vector2 = positions[nid]
		if got.distance_to(expected) > 0.5:
			mismatches.append("%s expected=%s got=%s" % [nid, str(expected), str(got)])
	_check(mismatches.is_empty(), "BoardApp 換算座標與 JSON angle_deg/radius 一致 (mismatches=%s)" % str(mismatches))
	app.queue_free()
	await get_tree().process_frame
