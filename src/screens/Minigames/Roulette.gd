extends "res://src/screens/Minigames/MinigameBase.gd"
## 輪盤 Roulette —— 地下遊藝場小遊戲（2026-07-03 玩法重做＝實機賭場式點格下注）。
## 滑鼠點押注格放籌碼（同格可疊加、右鍵移除）→ 按「確認下注」→ 轉盤+滾珠開獎。
## 開獎是「真數字」：輪盤圖＝標準歐式排序，球會真的停在開出的數字格上。
## 3 局總淨額定勝負。賠率：直注 35:1、打/行 2:1、紅黑/單雙/大小 1:1（0 通殺外圍注）。
## 美術＝roulette_table_top_v2 近景桌（押注格已印在桌面，點擊區照格線座標鋪隱形層）
## ＋疊同一顆輪盤 sprite（靜止時與背景完全對齊、轉動時現形）＋glow/trail 加法特效；
## 籌碼用 chip_100_game_ready.png，缺檔時程式畫圓片頂著（Codex FX handoff 已開）。

const ART := "res://assets/art_direction/new_ink_shrine_style/minigames/parlor/"
const ROUNDS: int = 3
const CHIP: int = 100                    # 一枚籌碼的注金
const WHEEL_CENTER := Vector2(354, 413)  # 對齊背景烤好的輪盤中心
const WHEEL_RADIUS: float = 335.0
const BALL_REST_R: float = 0.76          # 球最後落定的半徑比例（號碼格圈）
const RED_NUMS: Array = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
## 歐式輪盤標準排序（Codex 輪盤圖照此排序、0 在正上方、順時針遞增）。
const EURO_ORDER: Array = [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30,
	8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
# 背景圖(1672×941)→螢幕(1920×1080)的縮放；押注格座標全用背景圖 px 定義
const SX := 1920.0 / 1672.0
const SY := 1080.0 / 941.0

var auto_start: bool = true
var rounds_done: int = 0
var net: int = 0
var bets: Dictionary = {}                # cell_id -> 籌碼數
var _phase: String = "bet"               # bet / spin / settle / done
var _cells: Array = []                   # [{id, rect(螢幕座標)}]
var _chip_roots: Dictionary = {}         # cell_id -> Node2D（籌碼堆容器）
var _hover_id: String = ""
var _wheel: Sprite2D
var _ball: Sprite2D
var _glow: Sprite2D
var _trail: Sprite2D
var _board: Control
var _hover_panel: Panel
var _confirm_btn: Button
var _hud: Label
var _sub: Label
var _banner: Label
var _banner_back: Panel
var _rng := RandomNumberGenerator.new()

func minigame_id() -> String:
	return "roulette"

func _ready() -> void:
	_rng.randomize()
	_build_cells()
	_build_scene()
	if auto_start:
		_new_round()

# --- 純邏輯（測試用）---

## 單一押注格對開獎數字的「每枚籌碼淨賠率」：贏回 +35/+2/+1、輸 -1。
func cell_net(cell_id: String, n: int) -> int:
	if cell_id.begins_with("n"):
		return 35 if n == int(cell_id.substr(1)) else -1
	var win := false
	match cell_id:
		"dz1": win = n >= 1 and n <= 12
		"dz2": win = n >= 13 and n <= 24
		"dz3": win = n >= 25 and n <= 36
		"col_top": win = n > 0 and n % 3 == 0
		"col_mid": win = n > 0 and n % 3 == 2
		"col_bot": win = n > 0 and n % 3 == 1
		"low": win = n >= 1 and n <= 18
		"high": win = n >= 19 and n <= 36
		"even": win = n > 0 and n % 2 == 0
		"odd": win = n % 2 == 1
		"red": win = n in RED_NUMS
		"black": win = n > 0 and n not in RED_NUMS
	if cell_id in ["dz1", "dz2", "dz3", "col_top", "col_mid", "col_bot"]:
		return 2 if win else -1
	return 1 if win else -1

## 這一局全部押注對開獎數字的總淨額（金）。
func round_net(bet_dict: Dictionary, n: int) -> int:
	var total := 0
	for cell_id in bet_dict:
		total += int(bet_dict[cell_id]) * cell_net(String(cell_id), n) * CHIP
	return total

## 數字在輪盤 sprite 上的格心角度（sprite 未旋轉時，0 在正上方、順時針遞增）。
func sector_angle(n: int) -> float:
	var idx := EURO_ORDER.find(n)
	return -PI * 0.5 + float(idx) * TAU / 37.0

func outcome_color(n: int) -> String:
	if n == 0:
		return "zero"
	return "red" if n in RED_NUMS else "black"

func build_result() -> Dictionary:
	var won: bool = net > 0
	return make_result({
		"score": net, "win": won,
		"gold": net,
		"karma": 1,   # 小賭怡情，業障一點
	})

# --- 押注格座標表（背景圖 px → 螢幕）---

func _build_cells() -> void:
	_cells.clear()
	# 0（綠色直條）
	_add_cell("n0", 610, 206, 66, 339)
	# 1-36 數字格：12 欄 × 3 列（上列=3的倍數、中列=%3==2、下列=%3==1）
	var row_y: Array = [206.0, 323.0, 441.0]
	var row_h: Array = [117.0, 118.0, 104.0]
	for i in range(12):
		var x := 678.0 + float(i) * 66.4
		_add_cell("n%d" % (3 * (i + 1)), x, row_y[0], 66.4, row_h[0])
		_add_cell("n%d" % (3 * i + 2), x, row_y[1], 66.4, row_h[1])
		_add_cell("n%d" % (3 * i + 1), x, row_y[2], 66.4, row_h[2])
	# 2:1 直行注（右端三格，對應三列）
	_add_cell("col_top", 1478, row_y[0], 75, row_h[0])
	_add_cell("col_mid", 1478, row_y[1], 75, row_h[1])
	_add_cell("col_bot", 1478, row_y[2], 75, row_h[2])
	# 三打
	_add_cell("dz1", 678, 548, 266, 74)
	_add_cell("dz2", 944, 548, 266, 74)
	_add_cell("dz3", 1210, 548, 265, 74)
	# 外圍六格
	_add_cell("low", 678, 625, 133, 75)
	_add_cell("even", 811, 625, 133, 75)
	_add_cell("red", 944, 625, 133, 75)
	_add_cell("black", 1077, 625, 133, 75)
	_add_cell("odd", 1210, 625, 132, 75)
	_add_cell("high", 1342, 625, 133, 75)

func _add_cell(id: String, x: float, y: float, w: float, h: float) -> void:
	_cells.append({"id": id, "rect": Rect2(x * SX, y * SY, w * SX, h * SY)})

func _cell_by_id(id: String) -> Dictionary:
	for c in _cells:
		if String(c.id) == id:
			return c
	return {}

# --- 流程 ---

func _input(event: InputEvent) -> void:
	if _phase == "bet" and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode in [KEY_ENTER, KEY_SPACE] and not bets.is_empty():
		_confirm_bets()

func _new_round() -> void:
	if rounds_done >= ROUNDS:
		_end()
		return
	_phase = "bet"
	bets.clear()
	for root in _chip_roots.values():
		(root as Node2D).queue_free()
	_chip_roots.clear()
	_banner.visible = false
	_banner_back.visible = false
	_confirm_btn.visible = true
	_confirm_btn.disabled = true
	_update_hud()

func _on_board_input(event: InputEvent) -> void:
	if _phase != "bet":
		return
	if event is InputEventMouseMotion:
		var id := _cell_at(event.position)
		if id != _hover_id:
			_hover_id = id
			_update_hover()
	elif event is InputEventMouseButton and event.pressed:
		var id := _cell_at(event.position)
		if id == "":
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_add_chip(id)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_remove_chip(id)

func _cell_at(pos: Vector2) -> String:
	for c in _cells:
		if (c.rect as Rect2).has_point(pos):
			return String(c.id)
	return ""

func _update_hover() -> void:
	if _hover_id == "":
		_hover_panel.visible = false
		return
	var r: Rect2 = _cell_by_id(_hover_id).rect
	_hover_panel.position = r.position
	_hover_panel.size = r.size
	_hover_panel.visible = true

func _add_chip(id: String) -> void:
	bets[id] = int(bets.get(id, 0)) + 1
	AudioManager.play_sfx("gold_collect")
	var root: Node2D = _chip_roots.get(id, null)
	if root == null:
		root = Node2D.new()
		root.position = (_cell_by_id(id).rect as Rect2).get_center()
		add_child(root)
		_chip_roots[id] = root
	var idx := int(bets[id]) - 1
	var chip := _make_chip()
	chip.position = Vector2(idx * 3.0, -idx * 3.0)
	chip.modulate.a = 0.0
	chip.scale = Vector2(1.4, 1.4)
	root.add_child(chip)
	var tw := create_tween()
	tw.tween_property(chip, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(chip, "scale", Vector2.ONE, 0.15)
	_confirm_btn.disabled = false
	_update_hud()

func _remove_chip(id: String) -> void:
	if int(bets.get(id, 0)) <= 0:
		return
	bets[id] = int(bets[id]) - 1
	AudioManager.play_sfx("ui_cancel")
	var root: Node2D = _chip_roots.get(id, null)
	if root != null and root.get_child_count() > 0:
		root.get_child(root.get_child_count() - 1).queue_free()
	if int(bets[id]) == 0:
		bets.erase(id)
	_confirm_btn.disabled = bets.is_empty()
	_update_hud()

## 單枚籌碼：有 Codex 圖用圖，沒有就程式畫圓片（圖到了自動生效，零改碼）。
func _make_chip() -> Node2D:
	var path := ART + "chip_100_game_ready.png"
	if ResourceLoader.exists(path):
		var s := Sprite2D.new()
		s.texture = load(path)
		s.scale = Vector2.ONE * (54.0 / 1254.0)
		return s
	var c := ChipDraw.new()
	return c

class ChipDraw extends Node2D:
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 24, Color(0.66, 0.13, 0.11))
		draw_arc(Vector2.ZERO, 21, 0, TAU, 48, Color(0.92, 0.78, 0.38), 3.5)
		draw_circle(Vector2.ZERO, 11, Color(0.88, 0.74, 0.32))
		for i in range(6):
			var a := TAU * float(i) / 6.0
			draw_arc(Vector2.ZERO, 24, a, a + 0.28, 6, Color(0.95, 0.88, 0.72), 5.0)

func _confirm_bets() -> void:
	if _phase != "bet" or bets.is_empty():
		return
	_phase = "spin"
	_confirm_btn.visible = false
	_hover_panel.visible = false
	AudioManager.play_sfx("ui_select")
	_spin()

func _spin() -> void:
	var outcome := _rng.randi_range(0, 36)
	# 轉盤減速旋轉到隨機終角
	var wheel_final: float = _wheel.rotation + TAU * _rng.randf_range(3.0, 5.0)
	var tw := create_tween()
	tw.tween_property(_wheel, "rotation", wheel_final, 2.6) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# 發光特效：快轉亮、將停淡出
	var gtw := create_tween()
	gtw.tween_property(_glow, "modulate:a", 0.85, 0.3)
	gtw.tween_interval(1.6)
	gtw.tween_property(_glow, "modulate:a", 0.0, 0.6)
	# 滾珠：反向公轉數圈後，收進「開出數字」在停定轉盤上的格心角（真落點）
	var target_ang: float = wheel_final + sector_angle(outcome)
	var a0: float = _rng.randf() * TAU
	var delta: float = wrapf(target_ang - a0, -TAU, 0.0) - TAU * 4.0   # 逆向多繞 4 圈
	_trail.modulate.a = 0.9
	var tw2 := create_tween()
	tw2.tween_method(func(t: float) -> void:
		var ang: float = a0 + delta * (1.0 - pow(1.0 - t, 3))
		var r: float = WHEEL_RADIUS * lerpf(0.94, BALL_REST_R, minf(t * 1.25, 1.0))
		var pos: Vector2 = WHEEL_CENTER + Vector2(cos(ang), sin(ang)) * r
		_ball.position = pos
		_trail.position = pos
		_trail.rotation = ang + PI * 0.5
		_trail.modulate.a = lerpf(0.9, 0.0, t),
		0.0, 1.0, 2.6)
	tw2.tween_callback(func() -> void: _on_settled(outcome))

func _on_settled(outcome: int) -> void:
	_phase = "settle"
	rounds_done += 1
	var delta := round_net(bets, outcome)
	net += delta
	var col_name: String
	var col: Color
	match outcome_color(outcome):
		"red":
			col_name = "紅"; col = Color(0.92, 0.32, 0.24)
		"black":
			col_name = "黑"; col = Color(0.82, 0.82, 0.88)
		_:
			col_name = ""; col = Color(0.45, 0.85, 0.45)
	var head := ("開出 0" if outcome == 0 else "開出 %d %s" % [outcome, col_name])
	if delta > 0:
		AudioManager.play_sfx("merit_chime")
		spawn_fx_sparkle(WHEEL_CENTER, 0.22)   # 贏錢金光
		_banner.text = "%s｜+%d 金" % [head, delta]
	elif delta < 0:
		AudioManager.play_sfx("wooden_fish_tap")
		_banner.text = "%s｜-%d 金" % [head, -delta]
	else:
		AudioManager.play_sfx("ui_cancel")
		_banner.text = "%s｜打平" % head
	_banner.modulate = col
	_banner.visible = true
	_banner_back.visible = true
	# 輸的籌碼淡出（被莊家收走）
	for id in _chip_roots:
		if cell_net(String(id), outcome) < 0:
			var root: Node2D = _chip_roots[id]
			var ctw := create_tween()
			ctw.tween_property(root, "modulate:a", 0.0, 0.5)
	_update_hud()
	await get_tree().create_timer(1.8).timeout
	_new_round()

func _end() -> void:
	_phase = "done"
	var result := build_result()
	AudioManager.switch_bgm("victory_jingle" if result.win else "defeat_sting")
	var rating := "滿載而歸" if result.win else "小賭怡情"
	show_result_panel("輪盤", rating, [
		{"label": "局數", "value": "%d" % ROUNDS},
		{"label": "淨額", "value": "%s%d 金" % ["+" if net >= 0 else "", net]},
	], result)

## 重開一局：歸零局數與淨額，清空押注重新開始。
func restart() -> void:
	rounds_done = 0
	net = 0
	bets.clear()
	for root in _chip_roots.values():
		(root as Node2D).queue_free()
	_chip_roots.clear()
	_finished = false
	_new_round()

# --- 視覺（Codex 資產＋最小 UI）---

func _build_scene() -> void:
	var bg := Sprite2D.new()
	bg.texture = load(ART + "roulette_table_top_v2.png")
	bg.centered = false
	bg.scale = Vector2(SX, SY)
	add_child(bg)
	# 發光特效在輪盤下、球尾焰在輪盤上（球本體最上）
	_glow = Sprite2D.new()
	_glow.texture = load(ART + "roulette_spin_glow_fx_game_ready.png")
	_glow.position = WHEEL_CENTER
	_glow.scale = Vector2.ONE * (WHEEL_RADIUS * 2.2 / 1254.0)
	_glow.modulate.a = 0.0
	_glow.material = _additive_material()
	add_child(_glow)
	_wheel = Sprite2D.new()
	_wheel.texture = load(ART + "roulette_wheel_top_game_ready.png")
	_wheel.position = WHEEL_CENTER
	_wheel.scale = Vector2.ONE * (WHEEL_RADIUS * 2.0 / 1254.0)
	add_child(_wheel)
	_trail = Sprite2D.new()
	_trail.texture = load(ART + "roulette_ball_trail_fx_game_ready.png")
	_trail.scale = Vector2.ONE * 0.10
	_trail.modulate.a = 0.0
	_trail.material = _additive_material()
	add_child(_trail)
	_ball = Sprite2D.new()
	_ball.texture = load(ART + "roulette_ball_game_ready.png")
	_ball.scale = Vector2(0.045, 0.045)
	_ball.position = WHEEL_CENTER + Vector2(WHEEL_RADIUS * 0.94, 0)
	add_child(_ball)
	_build_ui()

func _additive_material() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	# 押注點擊層（透明全屏 Control，事件轉給 _on_board_input 做格子命中）
	_board = Control.new()
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.mouse_filter = Control.MOUSE_FILTER_PASS
	_board.gui_input.connect(_on_board_input)
	layer.add_child(_board)
	# hover 亮框（透明底、金邊）
	_hover_panel = Panel.new()
	var hb := StyleBoxFlat.new()
	hb.bg_color = Color(1.0, 0.85, 0.4, 0.10)
	hb.border_color = Color(1.0, 0.85, 0.40, 0.95)
	hb.set_border_width_all(3)
	_hover_panel.add_theme_stylebox_override("panel", hb)
	_hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_panel.visible = false
	layer.add_child(_hover_panel)
	# 確認下注按鈕
	_confirm_btn = Button.new()
	_confirm_btn.text = "確認下注・開盤"
	_confirm_btn.position = Vector2(810, 968)
	_confirm_btn.size = Vector2(300, 64)
	_confirm_btn.add_theme_font_size_override("font_size", 32)
	var bn := StyleBoxFlat.new()
	bn.bg_color = Color(0.10, 0.06, 0.05, 0.92)
	bn.border_color = Color(0.80, 0.62, 0.28)
	bn.set_border_width_all(2)
	bn.set_corner_radius_all(12)
	var bh := bn.duplicate() as StyleBoxFlat
	bh.bg_color = Color(0.22, 0.12, 0.08, 0.95)
	bh.border_color = Color(1.0, 0.85, 0.40)
	_confirm_btn.add_theme_stylebox_override("normal", bn)
	_confirm_btn.add_theme_stylebox_override("hover", bh)
	_confirm_btn.add_theme_stylebox_override("pressed", bh)
	var bd := bn.duplicate() as StyleBoxFlat
	bd.bg_color = Color(0.08, 0.07, 0.07, 0.7)
	bd.border_color = Color(0.4, 0.36, 0.30)
	_confirm_btn.add_theme_stylebox_override("disabled", bd)
	_confirm_btn.pressed.connect(_confirm_bets)
	# 佈局工具 v2（P4）：確認下注按鈕整塊登記（父節點 layer 是 CanvasLayer，非
	# Container，is_free()==true）。
	LayoutStore.register(_confirm_btn, "minigame/roulette/confirm_button")
	layer.add_child(_confirm_btn)
	# HUD 左上兩行
	_hud = Label.new()
	_hud.position = Vector2(48, 30)
	var hud_ls := LabelSettings.new()
	hud_ls.font_size = 38
	hud_ls.font_color = Color(0.9, 0.75, 0.42)
	hud_ls.outline_size = 8
	hud_ls.outline_color = Color(0.05, 0.04, 0.05, 0.9)
	_hud.label_settings = hud_ls
	layer.add_child(_hud)
	# 佈局工具 v2（P4）：左上 HUD 文字整塊登記（父節點 layer 是 CanvasLayer，非
	# Container，is_free()==true）。
	LayoutStore.register(_hud, "minigame/roulette/hud_label")
	_sub = Label.new()
	_sub.position = Vector2(48, 84)
	var sub_ls := LabelSettings.new()
	sub_ls.font_size = 32
	sub_ls.font_color = Color(0.92, 0.88, 0.80)
	sub_ls.outline_size = 8
	sub_ls.outline_color = Color(0.05, 0.04, 0.05, 0.9)
	_sub.label_settings = sub_ls
	layer.add_child(_sub)
	# 佈局工具 v2（P4）：第二行文字整塊登記（父節點 layer 是 CanvasLayer，非
	# Container，is_free()==true）。
	LayoutStore.register(_sub, "minigame/roulette/sub_label")
	# 結算訊息（中央偏上、深色底板）
	_banner_back = Panel.new()
	_banner_back.position = Vector2(660, 30)
	_banner_back.size = Vector2(600, 74)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.05, 0.78)
	sb.border_color = Color(0.7, 0.55, 0.25, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	_banner_back.add_theme_stylebox_override("panel", sb)
	_banner_back.visible = false
	layer.add_child(_banner_back)
	# 佈局工具 v2（P4）：結算橫幅背板整塊登記（父節點 layer 是 CanvasLayer，非
	# Container，is_free()==true）。_banner 文字與此同位置同步移動，不重複登記。
	LayoutStore.register(_banner_back, "minigame/roulette/result_banner")
	_banner = Label.new()
	_banner.position = Vector2(660, 30)
	_banner.size = Vector2(600, 74)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 42)
	_banner.visible = false
	layer.add_child(_banner)
	# 底部提示
	var tip := Label.new()
	tip.text = "點押注格放籌碼（右鍵收回）｜每枚 %d 金" % CHIP
	tip.position = Vector2(0, 1040)
	tip.size = Vector2(1920, 40)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tip_ls := LabelSettings.new()
	tip_ls.font_size = 26
	tip_ls.font_color = Color(0.85, 0.80, 0.72)
	tip_ls.outline_size = 8
	tip_ls.outline_color = Color(0.05, 0.04, 0.05, 0.9)
	tip.label_settings = tip_ls
	layer.add_child(tip)
	_update_hud()

func _update_hud() -> void:
	if _hud:
		var cur := mini(rounds_done + 1, ROUNDS) if _phase != "done" else ROUNDS
		_hud.text = "輪盤 第 %d/%d 局   淨額 %s%d 金" % [cur, ROUNDS, "+" if net >= 0 else "", net]
	if _sub:
		var total := 0
		for id in bets:
			total += int(bets[id]) * CHIP
		_sub.text = "已押 %d 金" % total if _phase == "bet" else ""
