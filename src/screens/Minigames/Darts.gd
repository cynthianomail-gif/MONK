extends "res://src/screens/Minigames/MinigameBase.gd"
## 飛鏢 Darts —— 地下遊藝場小遊戲（2026-07-03 玩法重做＝人中之龍式）。
## 滑鼠自由瞄準（帶手臂晃動）→ 按左鍵啟動左側力度條 → 再按一次鎖定出手：
## 鎖在條中央＝正中瞄準點，偏離越多落點飄越遠。
## 計分＝真飛鏢盤：20 分區（依角度）× 單/雙/三倍環 ＋ 紅心 50/外紅心 25。
## 模式：301（從 301 倒扣、歸零獲勝、超扣爆輪）／COUNT-UP（15 鏢拿高分）。
## 美術＝darts_bg_v2 近景背景（靶已烤進背景）＋只疊會動的鏢；
## 瞄準圈/力度條/模式選單全程式畫。

const ART := "res://assets/art_direction/new_ink_shrine_style/minigames/parlor/"
const BOARD_CENTER := Vector2(957, 496)  # 對齊背景烤好的靶心
const FACE_R: float = 167.0              # 靶整面半徑（含外圈數字帶）
const PLAY_R: float = 140.0              # 有效計分半徑（雙倍環外緣）
# 環區比例（以 PLAY_R 為 1，照標準飛鏢盤）
const BULL_R: float = 0.055
const OUTER_BULL_R: float = 0.12
const TRIPLE_IN: float = 0.55
const TRIPLE_OUT: float = 0.63
const DOUBLE_IN: float = 0.92
# 標準分區順序（正上方=20、順時針）
const SECTORS: Array = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5]
# 鏢貼圖 1254×1254 斜放：針尖在 (1144,116)、中心 (627,627)。
# offset=中心−針尖 → 針尖對齊 position（留靶 pin 的 rotation 也會繞針尖轉）。
const DART_TIP_OFFSET := Vector2(-517.0, 511.0)
const DARTS_TOTAL: int = 15              # 5 輪 × 3 鏢
const GAUGE_PERIOD: float = 1.1          # 力度條一個來回的秒數
const SCATTER_MAX: float = 95.0          # 力度全偏時的最大散布(px)
const SWAY_AMP: float = 7.0              # 瞄準手臂晃動振幅(px)
const COUNTUP_WIN: int = 400

var auto_start: bool = true
var mode: String = ""                    # "301" / "countup"
var score301: int = 301
var score: int = 0                       # countup 累計得分
var darts_thrown: int = 0
var _darts_in_turn: int = 0
var _turn_start_score: int = 301
var _phase: String = "mode"              # mode / aim / power / fly / done
var _t: float = 0.0                      # 晃動相位
var _gauge_t: float = 0.0
var _aim_locked := Vector2.ZERO
var _dart: Sprite2D
var _stuck: Node2D
var _reticle: Reticle
var _gauge: Gauge
var _mode_btns: Array = []
var _hud: Label
var _judge_popup: Label
var _tip: Label
var _rng := RandomNumberGenerator.new()

func minigame_id() -> String:
	return "darts"

func _ready() -> void:
	_rng.randomize()
	_build_scene()
	if auto_start:
		_show_mode_select()
	else:
		_phase = "idle"

# --- 純邏輯（測試用）---

## 落點（相對靶心的向量）→ {points, label}。真飛鏢盤計分。
func dart_value(offset: Vector2) -> Dictionary:
	var r := offset.length() / PLAY_R
	if r <= BULL_R:
		return {"points": 50, "label": "紅心"}
	if r <= OUTER_BULL_R:
		return {"points": 25, "label": "外紅心"}
	if r > 1.0:
		return {"points": 0, "label": "脫靶"}
	# 分區：正上=20 的格心，每格 18°，順時針
	var deg := rad_to_deg(atan2(offset.y, offset.x))     # 0=右、90=下
	var a := fposmod(deg + 90.0 + 9.0, 360.0)            # 轉成「從正上順時針」＋半格offset
	var val: int = SECTORS[int(a / 18.0) % 20]
	if r >= TRIPLE_IN and r <= TRIPLE_OUT:
		return {"points": val * 3, "label": "T%d" % val}
	if r >= DOUBLE_IN:
		return {"points": val * 2, "label": "D%d" % val}
	return {"points": val, "label": "%d" % val}

## 力度條指針位置（三角波 0→1→0，週期 GAUGE_PERIOD）。
func gauge_value(t: float) -> float:
	var ph := fmod(t, GAUGE_PERIOD) / (GAUGE_PERIOD * 0.5)
	return ph if ph <= 1.0 else 2.0 - ph

## 力度偏差（0=按在正中央、1=按在兩端）→ 散布半徑(px)。
func scatter_for(gauge_v: float) -> float:
	return absf(gauge_v - 0.5) * 2.0 * SCATTER_MAX + 3.0

## 301 記分：超扣＝爆（分數不動、本輪作廢）、剛好歸零＝贏。
func apply_301(cur: int, pts: int) -> Dictionary:
	if pts > cur:
		return {"score": cur, "bust": true, "win": false}
	var s := cur - pts
	return {"score": s, "bust": false, "win": s == 0}

func build_result() -> Dictionary:
	if mode == "301":
		var won := score301 == 0
		return make_result({
			"score": 301 - score301, "win": won,
			"gold": 500 if won else int((301 - score301) / 2.0),
			"karma": 1,
		})
	var won2 := score >= COUNTUP_WIN
	return make_result({
		"score": score, "win": won2,
		"gold": int(score / 2.0) + (150 if won2 else 0),
		"karma": 1,
	})

# --- 流程 ---

func _process(delta: float) -> void:
	_t += delta
	match _phase:
		"aim":
			_reticle.position = _aim_point()
			_reticle.queue_redraw()
		"power":
			_gauge_t += delta
			_gauge.value = gauge_value(_gauge_t)
			_gauge.queue_redraw()

## 目前瞄準點＝滑鼠＋手臂晃動，夾在靶面附近。
func _aim_point() -> Vector2:
	var sway := Vector2(sin(_t * 1.7) * SWAY_AMP, sin(_t * 2.3 + 1.3) * SWAY_AMP)
	var p: Vector2 = get_global_mouse_position() + sway
	var off := p - BOARD_CENTER
	if off.length() > FACE_R * 1.25:
		off = off.normalized() * FACE_R * 1.25
	return BOARD_CENTER + off

func _input(event: InputEvent) -> void:
	var tap: bool = ((event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT)
		or (event is InputEventKey and event.pressed and not event.echo
			and event.keycode in [KEY_SPACE, KEY_F, KEY_J]))
	if not tap:
		return
	match _phase:
		"aim":
			_phase = "power"
			_gauge_t = 0.0
			_aim_locked = _reticle.position
			_gauge.active = true
			_gauge.queue_redraw()
		"power":
			_throw(gauge_value(_gauge_t))

func _show_mode_select() -> void:
	_phase = "mode"
	_tip.text = "選擇玩法"
	var layer := _hud.get_parent()
	# 按鈕擺畫面下方檯面帶，別蓋住鏢靶本體
	var specs: Array = [
		["301", "301\n從 301 倒扣、剛好歸零獲勝", Vector2(660, 800)],
		["countup", "COUNT-UP\n15 鏢拿高分（%d 分過關）" % COUNTUP_WIN, Vector2(1020, 800)],
	]
	for sp in specs:
		var b := Button.new()
		b.text = sp[1]
		b.position = sp[2]
		b.size = Vector2(240, 130)
		b.add_theme_font_size_override("font_size", 26)
		var bn := StyleBoxFlat.new()
		bn.bg_color = Color(0.08, 0.05, 0.05, 0.90)
		bn.border_color = Color(0.80, 0.62, 0.28)
		bn.set_border_width_all(2)
		bn.set_corner_radius_all(12)
		var bh := bn.duplicate() as StyleBoxFlat
		bh.bg_color = Color(0.24, 0.12, 0.08, 0.95)
		bh.border_color = Color(1.0, 0.85, 0.40)
		b.add_theme_stylebox_override("normal", bn)
		b.add_theme_stylebox_override("hover", bh)
		b.add_theme_stylebox_override("pressed", bh)
		b.pressed.connect(_start_mode.bind(String(sp[0])))
		# 佈局工具 v2（P4）：純標註，不影響遊戲行為。模式按鈕動態逐項生成，視為
		# 重複樣板元件，改樣板（specs 常數）調整，不個別拖曳。
		b.set_meta("layout_template", "minigame/darts/mode_button")
		layer.add_child(b)
		_mode_btns.append(b)

func _start_mode(m: String) -> void:
	mode = m
	for b in _mode_btns:
		(b as Button).queue_free()
	_mode_btns.clear()
	score301 = 301
	_turn_start_score = 301
	score = 0
	darts_thrown = 0
	_darts_in_turn = 0
	AudioManager.play_sfx("ui_select")
	_tip.text = "滑鼠瞄準｜左鍵啟動力度條、再按一次出手（按到正中央最準）"
	_new_dart()

func _new_dart() -> void:
	if darts_thrown >= DARTS_TOTAL:
		_end()
		return
	if _darts_in_turn >= 3:
		_darts_in_turn = 0
		_turn_start_score = score301
		for pin in _stuck.get_children():
			pin.queue_free()   # 收回上一輪的鏢
	_phase = "aim"
	_dart.visible = false
	_gauge.active = false
	_gauge.queue_redraw()
	_reticle.visible = true
	_update_hud()

func _throw(gauge_v: float) -> void:
	_phase = "fly"
	_reticle.visible = false
	_gauge.active = false
	_gauge.queue_redraw()
	var scatter := scatter_for(gauge_v)
	var dir := Vector2.from_angle(_rng.randf() * TAU)
	var land: Vector2 = _aim_locked + dir * _rng.randf_range(0.0, scatter)
	var res := dart_value(land - BOARD_CENTER)
	# 鏢飛行：從瞄準點外側飛入釘上
	_dart.visible = true
	_dart.position = land + Vector2(0, 120)
	_dart.scale = Vector2(0.176, 0.176)
	var tw := create_tween()
	tw.tween_property(_dart, "position", land, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_dart, "scale", Vector2(0.076, 0.076), 0.14)
	tw.tween_callback(func() -> void: _on_landed(land, res))

func _on_landed(land: Vector2, res: Dictionary) -> void:
	darts_thrown += 1
	_darts_in_turn += 1
	spawn_fx_burst(land, 0.09)
	shake(2.5 + minf(float(res.points) / 12.0, 5.0), 0.14)   # 釘靶小震，高分震大點
	if int(res.points) == 50:
		spawn_fx_sparkle(land, 0.13)   # 紅心金光
		hit_stop(0.06)
	# 留鏢在靶上
	var pin := Sprite2D.new()
	pin.texture = _dart.texture
	pin.offset = DART_TIP_OFFSET
	pin.position = land
	pin.rotation_degrees = _rng.randf_range(-14.0, 14.0)
	pin.scale = Vector2(0.076, 0.076)
	# 佈局工具 v3：動態生成的落靶鏢，標樣板不可拖（每擲都是新節點，位置即落點）。
	pin.set_meta("layout_template", "minigame/darts/pin")
	_stuck.add_child(pin)
	_dart.visible = false
	var pts := int(res.points)
	if mode == "301":
		var r := apply_301(score301, pts)
		if r.bust:
			AudioManager.play_sfx("wooden_fish_tap")
			_show_judge("爆了！本輪作廢", Color(0.9, 0.4, 0.32))
			score301 = _turn_start_score
			darts_thrown += (3 - _darts_in_turn)   # 本輪剩鏢作廢
			_darts_in_turn = 3
		else:
			score301 = int(r.score)
			if r.win:
				AudioManager.play_sfx("merit_chime")
				_show_judge("%s！歸零獲勝！" % String(res.label), Color(1, 0.85, 0.4))
			else:
				_judge_sfx(pts)
				_show_judge("%s　-%d" % [String(res.label), pts], _judge_color(pts))
		if score301 == 0:
			await get_tree().create_timer(0.8).timeout
			_end()
			return
	else:
		score += pts
		_judge_sfx(pts)
		_show_judge("%s　+%d" % [String(res.label), pts], _judge_color(pts))
	_update_hud()
	await get_tree().create_timer(0.55).timeout
	_new_dart()

func _judge_sfx(pts: int) -> void:
	if pts >= 40:
		AudioManager.play_sfx("weakness_hit")
	elif pts >= 20:
		AudioManager.play_sfx("gold_collect")
	else:
		AudioManager.play_sfx("wooden_fish_tap")

func _judge_color(pts: int) -> Color:
	if pts >= 40:
		return Color(1, 0.85, 0.4)
	if pts >= 20:
		return Color(0.9, 0.78, 0.5)
	if pts > 0:
		return Color(0.75, 0.72, 0.70)
	return Color(0.8, 0.4, 0.35)

func _end() -> void:
	_phase = "done"
	_reticle.visible = false
	var result := build_result()
	AudioManager.switch_bgm("victory_jingle" if result.win else "defeat_sting")
	var rating := "神射手" if result.win else "再練練"
	var rows: Array = []
	if mode == "301":
		rows = [
			{"label": "模式", "value": "301"},
			{"label": "剩餘分數", "value": "%d" % score301},
			{"label": "獲得金幣", "value": "%d" % result.gold},
		]
	else:
		rows = [
			{"label": "模式", "value": "COUNT-UP"},
			{"label": "總得分", "value": "%d" % score},
			{"label": "獲得金幣", "value": "%d" % result.gold},
		]
	show_result_panel("飛鏢", rating, rows, result)

## 重開一局：清空盤上留鏢，回到模式選擇重新開始。
func restart() -> void:
	for pin in _stuck.get_children():
		pin.queue_free()
	mode = ""
	score301 = 301
	score = 0
	darts_thrown = 0
	_darts_in_turn = 0
	_turn_start_score = 301
	_finished = false
	_dart.visible = false
	_show_mode_select()

# --- 視覺（Codex 資產＋程式 UI）---

func _build_scene() -> void:
	var bg := Sprite2D.new()
	bg.texture = load(ART + "darts_bg_v2.png")
	bg.centered = false
	bg.scale = Vector2(1920.0 / 1672.0, 1080.0 / 941.0)
	add_child(bg)
	# 佈局工具 v3：背景整塊登記（A 靜態，父節點是本場景根節點，非 Container，
	# is_free()==true）。
	LayoutStore.register(bg, "minigame/darts/bg")
	_stuck = Node2D.new()
	add_child(_stuck)
	_dart = Sprite2D.new()
	_dart.texture = load(ART + "darts_dart_game_ready.png")
	_dart.offset = DART_TIP_OFFSET
	_dart.visible = false
	# 佈局工具 v3：飛行中的鏢＝C 類（_throw()/_on_landed() 每擲都改 position），
	# 標樣板不可拖，避免拖曳被下一擲的 tween 立刻蓋掉。
	_dart.set_meta("layout_template", "minigame/darts/dart")
	add_child(_dart)
	_reticle = Reticle.new()
	_reticle.visible = false
	# 佈局工具 v3：瞄準圈＝C 類（_process() 每幀依滑鼠更新 position），標樣板不可拖。
	_reticle.set_meta("layout_template", "minigame/darts/reticle")
	add_child(_reticle)
	_build_hud()

## 瞄準圈：雙圈＋十字（程式畫）。
class Reticle extends Node2D:
	func _draw() -> void:
		var col := Color(1.0, 0.85, 0.40, 0.95)
		draw_arc(Vector2.ZERO, 26, 0, TAU, 48, col, 2.5)
		draw_arc(Vector2.ZERO, 9, 0, TAU, 32, col, 2.0)
		for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(d * 14, d * 34, col, 2.5)

## 力度條：左側直條＋中央甜蜜帶＋指針（程式畫）。active=false 只畫外框。
class Gauge extends Control:
	var value: float = 0.0
	var active: bool = false
	func _draw() -> void:
		var w := 30.0
		var h := 400.0
		draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.04, 0.05, 0.82))
		draw_rect(Rect2(0, 0, w, h), Color(0.7, 0.55, 0.25, 0.9), false, 2.0)
		if not active:
			return
		# 甜蜜帶（中央 ±6%）
		var sweet_h := h * 0.12
		draw_rect(Rect2(2, h * 0.5 - sweet_h * 0.5, w - 4, sweet_h), Color(0.95, 0.78, 0.30, 0.85))
		# 指針（value 0=底、1=頂）
		var y := h * (1.0 - value)
		draw_rect(Rect2(-4, y - 3, w + 8, 6), Color(1.0, 0.95, 0.85))

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_gauge = Gauge.new()
	_gauge.position = Vector2(230, 300)
	_gauge.size = Vector2(30, 400)
	layer.add_child(_gauge)
	# 佈局工具 v2（P4）：力度條整塊登記（父節點 layer 是 CanvasLayer，非
	# Container，is_free()==true）。
	LayoutStore.register(_gauge, "minigame/darts/gauge")
	_hud = Label.new()
	_hud.position = Vector2(48, 36)
	var hud_ls := LabelSettings.new()
	hud_ls.font_size = 40
	hud_ls.font_color = Color(0.9, 0.75, 0.42)
	hud_ls.outline_size = 8
	hud_ls.outline_color = Color(0.05, 0.04, 0.05, 0.9)
	_hud.label_settings = hud_ls
	layer.add_child(_hud)
	# 佈局工具 v2（P4）：左上 HUD 文字整塊登記（父節點 layer 是 CanvasLayer，非
	# Container，is_free()==true）。
	LayoutStore.register(_hud, "minigame/darts/hud_label")
	_judge_popup = Label.new()
	_judge_popup.position = Vector2(1240, 440)
	var jp_ls := LabelSettings.new()
	jp_ls.font_size = 54
	jp_ls.outline_size = 10
	jp_ls.outline_color = Color(0.05, 0.04, 0.05, 0.9)
	_judge_popup.label_settings = jp_ls
	_judge_popup.modulate.a = 0.0
	layer.add_child(_judge_popup)
	# 佈局工具 v2（P4）：判定彈出字整塊登記（父節點 layer 是 CanvasLayer，非
	# Container，is_free()==true）。
	LayoutStore.register(_judge_popup, "minigame/darts/judge_popup")
	_tip = Label.new()
	_tip.position = Vector2(0, 1020)
	_tip.size = Vector2(1920, 50)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tip_ls := LabelSettings.new()
	tip_ls.font_size = 28
	tip_ls.font_color = Color(0.85, 0.80, 0.72)
	tip_ls.outline_size = 8
	tip_ls.outline_color = Color(0.05, 0.04, 0.05, 0.9)
	_tip.label_settings = tip_ls
	layer.add_child(_tip)
	# 佈局工具 v2（P4）：底部提示文字整塊登記（父節點 layer 是 CanvasLayer，非
	# Container，is_free()==true）。
	LayoutStore.register(_tip, "minigame/darts/tip_label")
	_update_hud()

func _update_hud() -> void:
	if _hud == null:
		return
	if mode == "301":
		_hud.text = "301 剩 %d｜第 %d/%d 鏢" % [score301, mini(darts_thrown + 1, DARTS_TOTAL), DARTS_TOTAL]
	elif mode == "countup":
		_hud.text = "COUNT-UP 得分 %d｜第 %d/%d 鏢" % [score, mini(darts_thrown + 1, DARTS_TOTAL), DARTS_TOTAL]
	else:
		_hud.text = "飛鏢"

func _show_judge(text: String, color: Color) -> void:
	_judge_popup.text = text
	_judge_popup.label_settings.font_color = color
	_judge_popup.modulate.a = 1.0
	_judge_popup.pivot_offset = Vector2(0, 30)
	_judge_popup.scale = Vector2(1.35, 1.35)
	var tw := create_tween()
	tw.tween_property(_judge_popup, "scale", Vector2.ONE, 0.13) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.30)
	tw.tween_property(_judge_popup, "modulate:a", 0.0, 0.3)
