extends "res://src/screens/Minigames/MinigameBase.gd"
## 保齡球館 Bowling —— 神社街店家小遊戲（2026-07-03 玩法重做＝Wii 式）。
## 出球前〔←→〕移動起始位置、〔C〕切換 直球/曲球（帶虛線預測軌跡），
## 〔空白鍵〕出球 → 球沿軌跡滾遠（透視收縮+縮小），依最終落點算倒瓶。
## 曲球固定向左勾：想全倒要站右側讓球勾進 1-3 瓶口袋；直球打正中央容易
## 留分瓶（真保齡球邏輯，兩種球才有取捨）。5 局、每局最多 2 球（補瓶制）。
## 美術＝bowling_lane_shrine_v2 空瓶區背景＋程式瓶陣/球；預測線/球種 UI 程式畫。

const ART := "res://assets/art_direction/new_ink_shrine_style/minigames/parlor/"
const SHRINE_ART := "res://assets/art_direction/new_ink_shrine_style/minigames/shrine_games/"
const FRAMES: int = 5
const LANE_CENTER_X: float = 984.0       # 拱門開口中心（格線量測：圖 x857×1.14833）
const BALL_START_Y: float = 930.0
const DECK_Y: float = 585.0              # 球滾到瓶區的 y（拱門口地板 ≈577）
const PIN_ROW_Y: float = 553.0           # 頭瓶(1號瓶)中心 y＝最靠拱門口
const PIN_ROW_DEPTH: Array = [0.0, 22.0, 40.0, 55.0]  # 各排往深處的累積位移（透視壓縮）
const AIM_MAX: float = 180.0             # 起始位置左右可移範圍(底部座標)
const TOP_SCALE: float = 0.37            # 球道遠端的透視收縮比
const HOOK_AMT: float = 150.0            # 曲球總勾量(底部座標，向左)
const MOVE_SPEED: float = 420.0          # 瞄準移動速度(px/s)
const WIN_PINS: int = 38

var auto_start: bool = true
var frame_no: int = 0                    # 已完成局數
var roll_in_frame: int = 0               # 本局第幾球(0/1)
var pins_total: int = 0
var bonus: int = 0                       # 全倒/補中加分
var hooked: bool = false
var _standing: int = 10
var _first_knock: int = 0
var _phase: String = "idle"              # aim / roll / done
var _start_off: float = 0.0
var _ball: Sprite2D
var _pins: Array = []                    # 目前站立的瓶 Sprite2D
var _pin_root: Node2D
var _preview: Line2D
var _hud: Label
var _type_label: Label
var _judge_popup: Label
var _rng := RandomNumberGenerator.new()

func minigame_id() -> String:
	return "bowling"

func _ready() -> void:
	_rng.randomize()
	_build_scene()
	if auto_start:
		_new_frame()

# --- 純邏輯（測試用）---

## 球在進度 t(0..1) 的橫向偏移（底部座標系）：直球固定、曲球二次曲線向左勾。
func lane_offset(t: float, start_off: float, is_hook: bool) -> float:
	return start_off - (HOOK_AMT * t * t if is_hook else 0.0)

## 最終落點偏移（底部座標）。
func final_offset(start_off: float, is_hook: bool) -> float:
	return lane_offset(1.0, start_off, is_hook)

## 依最終偏移+球種算倒瓶（滿瓶時）：
## 曲球勾進口袋(|f|∈18..48)＝全倒；直球正中(|f|<=12)＝打成分瓶只倒 8。
func pins_knocked(final_off: float, is_hook: bool) -> int:
	var d := absf(final_off)
	if is_hook:
		if d >= 18.0 and d <= 48.0:
			return 10
		if d < 18.0:
			return 9
		if d <= 80.0:
			return 7
		if d <= 130.0:
			return 4
		return 0
	if d <= 12.0:
		return 8
	if d <= 40.0:
		return 9
	if d <= 80.0:
		return 6
	if d <= 130.0:
		return 3
	return 0

func build_result() -> Dictionary:
	var won: bool = pins_total + bonus >= WIN_PINS
	return make_result({
		"score": pins_total + bonus, "win": won,
		"gold": pins_total * 8 + bonus * 10 + (120 if won else 0),
		"merit": 1 if won else 0,   # 練身也算修行
	})

# --- 流程 ---

func _process(delta: float) -> void:
	if _phase != "aim":
		return
	var dir := 0.0
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		dir -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		dir += 1.0
	if dir != 0.0:
		_start_off = clampf(_start_off + dir * MOVE_SPEED * delta, -AIM_MAX, AIM_MAX)
		_ball.position.x = LANE_CENTER_X + _start_off
		_update_preview()

func _input(event: InputEvent) -> void:
	if _phase != "aim":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_C, KEY_TAB:
				hooked = not hooked
				AudioManager.play_sfx("ui_select")
				_update_type_label()
				_update_preview()
				return
			KEY_SPACE, KEY_F, KEY_J:
				_roll()
				return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_roll()

func _new_frame() -> void:
	if frame_no >= FRAMES:
		_end()
		return
	roll_in_frame = 0
	_standing = 10
	_first_knock = 0
	_setup_pins()
	_new_roll()

func _new_roll() -> void:
	_phase = "aim"
	_ball.visible = true
	_ball.position = Vector2(LANE_CENTER_X + _start_off, BALL_START_Y)
	_ball.scale = Vector2(0.16, 0.16)
	_preview.visible = true
	_update_preview()
	_update_type_label()
	_update_hud()

func _roll() -> void:
	_phase = "roll"
	_preview.visible = false
	_attach_trail()
	var start := _start_off
	var f := final_offset(start, hooked)
	var knocked := mini(pins_knocked(f, hooked), _standing)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var offx := lane_offset(t, start, hooked)
		_ball.position = Vector2(
			LANE_CENTER_X + offx * lerpf(1.0, TOP_SCALE, t),
			lerpf(BALL_START_Y, DECK_Y, t))
		_ball.scale = Vector2.ONE * lerpf(0.16, 0.05, t),
		0.0, 1.0, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _on_impact(f, knocked))

func _on_impact(f: float, knocked: int) -> void:
	pins_total += knocked
	_ball.visible = false
	for c in _ball.get_children():
		c.queue_free()   # 收掉速度尾焰
	if knocked > 0:
		spawn_fx_burst(Vector2(LANE_CENTER_X + f * TOP_SCALE, PIN_ROW_Y - 15.0), 0.12)
		shake(4.0 + float(knocked) * 1.3, 0.24)     # 撞擊震動隨倒瓶數放大
		if knocked >= 10:
			hit_stop(0.08)                           # 全倒頓幀
	_knock_pins(f, knocked)
	_standing -= knocked
	roll_in_frame += 1
	var frame_done := false
	if roll_in_frame == 1:
		_first_knock = knocked
		if knocked >= 10:
			bonus += 5
			AudioManager.play_sfx("weakness_hit")
			spawn_fx_sparkle(Vector2(960.0, 505.0), 0.22)   # 全倒金光（結算字附近）
			_show_judge("STRIKE！全倒！", Color(1, 0.85, 0.4))
			frame_done = true
		elif knocked > 0:
			AudioManager.play_sfx("impact_heavy")
			_show_judge("倒 %d 瓶（補第 2 球）" % knocked, Color(0.9, 0.78, 0.5))
		else:
			AudioManager.play_sfx("wooden_fish_tap")
			_show_judge("洗溝……（補第 2 球）", Color(0.8, 0.4, 0.35))
	else:
		frame_done = true
		if _standing <= 0:
			bonus += 3
			AudioManager.play_sfx("weakness_hit")
			spawn_fx_sparkle(Vector2(960.0, 505.0), 0.20)   # 補中金光
			_show_judge("SPARE！補中！", Color(0.95, 0.82, 0.45))
		elif knocked > 0:
			AudioManager.play_sfx("impact_heavy")
			_show_judge("倒 %d 瓶" % knocked, Color(0.9, 0.78, 0.5))
		else:
			AudioManager.play_sfx("wooden_fish_tap")
			_show_judge("洗溝……", Color(0.8, 0.4, 0.35))
	_update_hud()
	await get_tree().create_timer(0.9).timeout
	if frame_done:
		frame_no += 1
		_new_frame()
	else:
		_new_roll()

## 從撞擊點近到遠擊倒 knocked 支瓶（彈飛+淡出），其餘留在原地補第二球。
func _knock_pins(f: float, knocked: int) -> void:
	var impact_x: float = LANE_CENTER_X + f * TOP_SCALE
	var order := _pins.duplicate()
	order.sort_custom(func(a, b) -> bool:
		return absf((a as Sprite2D).position.x - impact_x) < absf((b as Sprite2D).position.x - impact_x))
	for i in mini(knocked, order.size()):
		var pin: Sprite2D = order[i]
		_pins.erase(pin)
		var tw := create_tween()
		tw.tween_property(pin, "position",
			pin.position + Vector2(_rng.randf_range(-90, 90), _rng.randf_range(-70, -20)), 0.3)
		tw.parallel().tween_property(pin, "rotation_degrees", _rng.randf_range(-120, 120), 0.3)
		tw.parallel().tween_property(pin, "modulate:a", 0.0, 0.35)

func _end() -> void:
	_phase = "done"
	var result := build_result()
	AudioManager.switch_bgm("victory_jingle" if result.win else "defeat_sting")
	var rating := "全倒高手" if result.win else "再練練"
	show_result_panel("保齡球", rating, [
		{"label": "倒瓶數", "value": "%d" % pins_total},
		{"label": "bonus", "value": "+%d" % bonus},
		{"label": "獲得金幣", "value": "%d" % result.gold},
	], result)

## 重開一局：歸零局數與計分，重新開始第一局。
func restart() -> void:
	frame_no = 0
	roll_in_frame = 0
	pins_total = 0
	bonus = 0
	hooked = false
	_finished = false
	_new_frame()

# --- 視覺（Codex 資產＋程式 UI）---

func _build_scene() -> void:
	var bg := Sprite2D.new()
	bg.texture = load(SHRINE_ART + "bowling_lane_shrine_v2.png")
	bg.centered = false
	bg.scale = Vector2(1920.0 / 1672.0, 1080.0 / 941.0)
	add_child(bg)
	_pin_root = Node2D.new()
	add_child(_pin_root)
	_preview = Line2D.new()
	_preview.width = 6.0
	_preview.default_color = Color(1.0, 0.88, 0.45, 0.65)
	_preview.visible = false
	add_child(_preview)
	_ball = Sprite2D.new()
	_ball.texture = load(ART + "bowling_ball_game_ready.png")
	_ball.position = Vector2(LANE_CENTER_X, BALL_START_Y)
	_ball.scale = Vector2(0.16, 0.16)
	add_child(_ball)
	_build_hud()

## 重擺 10 支瓶（前到後 1-2-3-4 三角陣＝1 號瓶最前，遠端透視縮小）。
func _setup_pins() -> void:
	for p in _pin_root.get_children():
		p.queue_free()
	_pins.clear()
	var tex: Texture2D = load(ART + "bowling_pin_game_ready.png")
	var rows: Array = [1, 2, 3, 4]
	for r in rows.size():
		var count: int = rows[r]
		var y: float = PIN_ROW_Y - PIN_ROW_DEPTH[r]
		var gap: float = 46.0 - r * 5.0
		var x0: float = LANE_CENTER_X - gap * (count - 1) * 0.5
		for i in count:
			var pin := Sprite2D.new()
			pin.texture = tex
			pin.position = Vector2(x0 + gap * i, y)
			pin.scale = Vector2.ONE * (0.042 - r * 0.003)
			_pin_root.add_child(pin)
			_pins.append(pin)

## 速度尾焰：掛在球底下當子節點（跟著球移動/透視縮小），撞擊時收掉。
func _attach_trail() -> void:
	var path := FX_ART + "fx_speed_trail_game_ready.png"
	if not ResourceLoader.exists(path):
		return
	var s := Sprite2D.new()
	s.texture = load(path)
	s.position = Vector2(0, 760)   # 球貼圖局部座標：拖在球後方（畫面下方）
	s.scale = Vector2(0.85, 1.5)
	s.show_behind_parent = true
	s.modulate.a = 0.75
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	_ball.add_child(s)

## 虛線預測軌跡：取樣 14 點畫折線（曲球看得出向左勾）。
func _update_preview() -> void:
	var pts := PackedVector2Array()
	for i in range(15):
		var t := float(i) / 14.0
		pts.append(Vector2(
			LANE_CENTER_X + lane_offset(t, _start_off, hooked) * lerpf(1.0, TOP_SCALE, t),
			lerpf(BALL_START_Y - 20.0, DECK_Y, t)))
	_preview.points = pts

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(48, 36)
	var hud_ls := LabelSettings.new()
	hud_ls.font_size = 40
	hud_ls.font_color = Color(0.9, 0.75, 0.42)
	hud_ls.outline_size = 8
	hud_ls.outline_color = Color(0.05, 0.04, 0.05, 0.9)
	_hud.label_settings = hud_ls
	layer.add_child(_hud)
	_type_label = Label.new()
	_type_label.position = Vector2(48, 92)
	var tl_ls := LabelSettings.new()
	tl_ls.font_size = 34
	tl_ls.font_color = Color(0.92, 0.88, 0.80)
	tl_ls.outline_size = 8
	tl_ls.outline_color = Color(0.05, 0.04, 0.05, 0.9)
	_type_label.label_settings = tl_ls
	layer.add_child(_type_label)
	_judge_popup = Label.new()
	_judge_popup.position = Vector2(0, 460)
	_judge_popup.size = Vector2(1920, 90)
	_judge_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var jp_ls := LabelSettings.new()
	jp_ls.font_size = 64
	jp_ls.outline_size = 10
	jp_ls.outline_color = Color(0.05, 0.04, 0.05, 0.9)
	_judge_popup.label_settings = jp_ls
	_judge_popup.modulate.a = 0.0
	layer.add_child(_judge_popup)
	var tip := Label.new()
	tip.text = "〔←→〕移動位置　〔C〕切換球種　〔空白鍵〕出球（%d 分過關）" % WIN_PINS
	tip.position = Vector2(0, 1020)
	tip.size = Vector2(1920, 50)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tip_ls := LabelSettings.new()
	tip_ls.font_size = 28
	tip_ls.font_color = Color(0.85, 0.80, 0.72)
	tip_ls.outline_size = 8
	tip_ls.outline_color = Color(0.05, 0.04, 0.05, 0.9)
	tip.label_settings = tip_ls
	layer.add_child(tip)
	_update_hud()
	_update_type_label()

func _update_type_label() -> void:
	if _type_label:
		_type_label.text = "球種：%s" % ("曲球（向左勾）" if hooked else "直球")

func _update_hud() -> void:
	if _hud:
		var cur := mini(frame_no + 1, FRAMES) if _phase != "done" else FRAMES
		_hud.text = "保齡球 第 %d/%d 局 第 %d 球   得分 %d" % [cur, FRAMES, roll_in_frame + 1, pins_total + bonus]

func _show_judge(text: String, color: Color) -> void:
	_judge_popup.text = text
	_judge_popup.label_settings.font_color = color
	_judge_popup.modulate.a = 1.0
	_judge_popup.pivot_offset = _judge_popup.size * 0.5
	_judge_popup.scale = Vector2(1.5, 1.5)
	var tw := create_tween()
	tw.tween_property(_judge_popup, "scale", Vector2.ONE, 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_property(_judge_popup, "modulate:a", 0.0, 0.3)
